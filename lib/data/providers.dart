import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_config.dart';
import '../core/utils/text_utils.dart';
import 'gamification/achievements_catalog.dart';
import 'gamification/card_pool.dart';
import 'gamification/missions.dart';
import 'models/achievement.dart';
import 'models/anime_card_data.dart';
import 'models/collectible_card.dart';
import 'models/entry.dart';
import 'models/franchise.dart';
import 'models/home_items.dart';
import 'models/library_stats.dart';
import 'models/watch_status.dart';
import 'remote/anilist_client.dart';
import 'remote/api_gateway.dart';
import 'remote/jikan_client.dart';
import 'remote/mal_client.dart';
import 'repository/franchise_repository.dart';
import 'repository/library_import.dart';
import 'storage/economy.dart';
import 'storage/migrations.dart' show Boxes;
import 'storage/user_extras.dart';
import 'storage/watch_storage.dart';
import 'storage/watch_order_storage.dart';
import 'services/suggestion_engine.dart';
import 'services/watch_plan_service.dart';

final apiGatewayProvider = Provider<ApiGateway>((ref) {
  return ApiGateway(
    cacheBox: Hive.isBoxOpen(Boxes.apiCache)
        ? Hive.box<String>(Boxes.apiCache)
        : null,
  );
});

final anilistClientProvider = Provider<AniListClient>(
  (ref) => AniListClient(ref.watch(apiGatewayProvider)),
);
final jikanClientProvider = Provider<JikanClient>(
  (ref) => JikanClient(ref.watch(apiGatewayProvider)),
);
final malClientProvider = Provider<MalClient>(
  (ref) => MalClient(ref.watch(apiGatewayProvider)),
);

final franchiseRepositoryProvider = Provider<FranchiseRepository>((ref) {
  return FranchiseRepository(
    ref.watch(anilistClientProvider),
    ref.watch(jikanClientProvider),
    ref.watch(malClientProvider),
    Hive.box<String>('franchise_cache'),
  );
});

final watchStorageProvider = Provider<WatchStorage>((ref) {
  return WatchStorage(Hive.box<String>('watch_status'));
});

final userExtrasProvider = Provider<UserExtras>((ref) {
  return UserExtras(Hive.box<String>(Boxes.meta));
});

class WatchStatusNotifier extends Notifier<Map<String, WatchStatus>> {
  @override
  Map<String, WatchStatus> build() => ref.read(watchStorageProvider).loadAll();

  Future<void> setStatus(String entryId, WatchStatus? status) async {
    final storage = ref.read(watchStorageProvider);
    final next = Map<String, WatchStatus>.from(state);
    if (status == null) {
      next.remove(entryId);
    } else {
      next[entryId] = status;
    }
    state = next;
    if (status == null) {
      await storage.remove(entryId);
    } else {
      await storage.set(entryId, status);
    }
    // ثبت آخرین فعالیت برای «ادامه تماشا»
    await ref.read(userExtrasProvider).touchSeen(entryId);
  }
}

final watchStatusProvider =
    NotifierProvider<WatchStatusNotifier, Map<String, WatchStatus>>(
      WatchStatusNotifier.new,
    );

final franchiseProvider = FutureProvider.family<Franchise, int>((ref, id) {
  return ref.watch(franchiseRepositoryProvider).getFranchise(id);
});

/// فرنچایز از روی شناسه MAL (برای نتایج جست‌وجوی MAL/Jikan).
final franchiseByMalProvider = FutureProvider.family<Franchise, int>((
  ref,
  malId,
) {
  return ref.watch(franchiseRepositoryProvider).getFranchiseByMal(malId);
});

class FranchiseProgress {
  final int done;
  final int total;
  const FranchiseProgress(this.done, this.total);

  double get ratio => total == 0 ? 0 : done / total;
  int get percent => (ratio * 100).round();
}

FranchiseProgress progressOf(
  Franchise f,
  Map<String, WatchStatus> statuses,
  Map<String, Set<int>> episodes,
) {
  var list = progressMainStoryOnly ? f.mainEntries : f.entries;
  // آثار اعلام‌شده (هنوز پخش/منتشر نشده) در نوار پیشرفت شمرده نمی‌شوند.
  list = list
      .where((e) => !e.releaseState.excludedFromProgress)
      .toList(growable: false);
  if (list.isEmpty) {
    list = f.entries
        .where((e) => !e.releaseState.excludedFromProgress)
        .toList(growable: false);
  }

  var done = 0;
  var total = 0;
  for (final e in list) {
    final units = e.episodes > 0 ? e.episodes : 1;
    total += units;
    if (statuses[e.id] == WatchStatus.completed) {
      done += units;
    } else if (e.episodes > 0) {
      final watched = episodes[e.id];
      if (watched != null) {
        done += watched.where((n) => n >= 1 && n <= e.episodes).length;
      }
    }
  }
  return FranchiseProgress(done, total);
}

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<AnimeCardData>, String>((ref, query) async {
      final repo = ref.watch(franchiseRepositoryProvider);

      final localFranchises = repo.localSearch(query);
      final results = localFranchises.map(AnimeCardData.fromFranchise).toList();

      if (hasPersian(query)) return results;

      final seenRoots = <String>{for (final f in localFranchises) f.id};
      try {
        final remote = await repo.searchRemote(query);
        for (final hit in remote) {
          final root = hit.anilistId > 0
              ? (repo.aliasOf(hit.anilistId) ?? 'al-${hit.anilistId}')
              : 'mal-${hit.malId}';
          if (seenRoots.add(root)) results.add(hit);
        }
      } catch (e) {
        if (results.isEmpty) rethrow;
      }
      return results;
    });

class MyListFranchise {
  final Franchise franchise;
  final WatchStatus status;
  final FranchiseProgress progress;
  const MyListFranchise(this.franchise, this.status, this.progress);
}

WatchStatus _franchiseStatus(
  FranchiseProgress progress,
  List<WatchStatus> tracked,
) {
  if (progress.total > 0 && progress.done >= progress.total) {
    return WatchStatus.completed;
  }
  if (tracked.contains(WatchStatus.watching)) return WatchStatus.watching;
  if (tracked.contains(WatchStatus.completed)) return WatchStatus.watching;
  if (tracked.contains(WatchStatus.onHold)) return WatchStatus.onHold;
  if (tracked.contains(WatchStatus.planToWatch)) {
    return WatchStatus.planToWatch;
  }
  return WatchStatus.dropped;
}

final myListFranchisesProvider = Provider<List<MyListFranchise>>((ref) {
  final statuses = ref.watch(watchStatusProvider);
  final episodes = ref.watch(episodeProgressProvider);
  if (statuses.isEmpty) return const [];

  final repo = ref.read(franchiseRepositoryProvider);
  final seenEntries = <String>{};
  final result = <MyListFranchise>[];

  for (final f in repo.allCachedFranchises()) {
    final tracked = <WatchStatus>[];
    for (final e in f.entries) {
      final s = statuses[e.id];
      if (s != null && seenEntries.add(e.id)) tracked.add(s);
    }
    if (tracked.isEmpty) continue;

    final progress = progressOf(f, statuses, episodes);
    result.add(
      MyListFranchise(f, _franchiseStatus(progress, tracked), progress),
    );
  }
  return result;
});

class EpisodeProgressNotifier extends Notifier<Map<String, Set<int>>> {
  Box<String> get _box => Hive.box<String>('episode_progress');

  @override
  Map<String, Set<int>> build() {
    final out = <String, Set<int>>{};
    for (final key in _box.keys) {
      final k = key.toString();
      final raw = _box.get(k);
      if (raw == null || raw.isEmpty) continue;
      final eps = raw.split(',').map(int.tryParse).whereType<int>().toSet();
      if (eps.isNotEmpty) out[k] = eps;
    }
    return out;
  }

  Future<void> _save(String entryId, Set<int> eps, int total) async {
    final prevSet = state[entryId] ?? <int>{};
    final prev = prevSet.length;
    final next = Map<String, Set<int>>.from(state);
    if (eps.isEmpty) {
      next.remove(entryId);
      await _box.delete(entryId);
    } else {
      next[entryId] = eps;
      final sorted = eps.toList()..sort();
      await _box.put(entryId, sorted.join(','));
    }
    state = next;
    await _syncStatus(entryId, prev, eps.length, total);
    // ثبت آخرین فعالیت برای «ادامه تماشا»
    if (eps.isNotEmpty) {
      await ref.read(userExtrasProvider).touchSeen(entryId);
    }
    // اقتصاد: XP و سکه فقط برای قسمت‌هایی که «اولین بار» دیده می‌شوند
    // (تاگِل on/off/on یا clear و علامت‌گذاری دوباره جایزه دوباره نمی‌دهد)
    // + بررسی تکمیل فرنچایز (idempotent).
    final added = eps.length - prev;
    if (added > 0) {
      final eco = Economy(Hive.box<String>(Boxes.meta));
      final fresh = await eco.markEpisodesAwarded(
        entryId,
        eps.difference(prevSet),
      );
      if (fresh > 0) {
        await ref.read(economyProvider.notifier).onEpisodesWatched(fresh);
      }
      await _awardFranchiseCompletion(ref, entryId);
    }
  }

  Future<void> _syncStatus(String entryId, int prev, int now, int total) async {
    final statuses = ref.read(watchStatusProvider);
    final status = statuses[entryId];
    final notifier = ref.read(watchStatusProvider.notifier);

    if (total > 0 && now >= total) {
      if (status != WatchStatus.completed) {
        await notifier.setStatus(entryId, WatchStatus.completed);
      }
    } else if (now > 0) {
      final wasFull = total > 0 && prev >= total;
      if (status == null ||
          status == WatchStatus.planToWatch ||
          (status == WatchStatus.completed && wasFull)) {
        await notifier.setStatus(entryId, WatchStatus.watching);
      }
    }
  }

  Future<void> toggle(String entryId, int ep, int total) {
    final eps = {...(state[entryId] ?? <int>{})};
    if (!eps.remove(ep)) eps.add(ep);
    return _save(entryId, eps, total);
  }

  Future<void> markUpTo(String entryId, int ep, int total) {
    final eps = {...(state[entryId] ?? <int>{})};
    for (var i = 1; i <= ep; i++) {
      eps.add(i);
    }
    return _save(entryId, eps, total);
  }

  Future<void> markAll(String entryId, int total) =>
      _save(entryId, {for (var i = 1; i <= total; i++) i}, total);

  Future<void> clear(String entryId, int total) =>
      _save(entryId, <int>{}, total);
}

final episodeProgressProvider =
    NotifierProvider<EpisodeProgressNotifier, Map<String, Set<int>>>(
      EpisodeProgressNotifier.new,
    );

enum HomeSection {
  airing('در حال پخش'),
  nextSeason('فصل آینده'),
  top('برترین‌ها'),
  movies('سینمایی‌ها'),
  series('سریال‌ها');

  const HomeSection(this.titleFa);
  final String titleFa;
}

({String season, int year}) _nextSeason(DateTime now) {
  final m = now.month;
  if (m <= 3) return (season: 'SPRING', year: now.year);
  if (m <= 6) return (season: 'SUMMER', year: now.year);
  if (m <= 9) return (season: 'FALL', year: now.year);
  return (season: 'WINTER', year: now.year + 1);
}

String _sectionArgs(HomeSection section) {
  switch (section) {
    case HomeSection.airing:
      return 'status: RELEASING, sort: [TRENDING_DESC], format_in: [TV, TV_SHORT, ONA]';
    case HomeSection.nextSeason:
      final n = _nextSeason(DateTime.now());
      return 'season: ${n.season}, seasonYear: ${n.year}, sort: [POPULARITY_DESC], format_in: [TV, ONA]';
    case HomeSection.top:
      return 'sort: [SCORE_DESC], format_in: [TV, MOVIE], popularity_greater: 30000';
    case HomeSection.movies:
      return 'format: MOVIE, sort: [POPULARITY_DESC]';
    case HomeSection.series:
      return 'format: TV, sort: [POPULARITY_DESC]';
  }
}

List<AnimeCardData> cardsFromRaw(List<Map<String, dynamic>> raw) {
  final out = <AnimeCardData>[];
  for (final m in raw) {
    final id = m['id'] as int;
    final cover = (m['coverImage'] as Map?)?['large'] as String?;
    if (cover == null) continue;
    final t = (m['title'] ?? {}) as Map;
    final en = (t['english'] ?? t['romaji'] ?? '—') as String;
    final avg = m['averageScore'] as int?;
    out.add(
      AnimeCardData(
        anilistId: id,
        titleFa: persianTitles[id] ?? en,
        titleEn: en,
        cover: cover,
        year: m['seasonYear'] as int?,
        score: avg == null ? 0 : avg / 10.0,
      ),
    );
  }
  return out;
}

Future<({List<AnimeCardData> items, bool hasNext})> fetchSectionPage(
  AniListClient client,
  HomeSection section,
  int page, {
  int perPage = 24,
}) async {
  final r = await client.browsePage(
    section.name,
    _sectionArgs(section),
    page: page,
    perPage: perPage,
  );
  return (items: cardsFromRaw(r.items), hasNext: r.hasNext);
}

class HomeSectionNotifier
    extends FamilyAsyncNotifier<List<AnimeCardData>, HomeSection> {
  static const _boxName = 'home_cache';
  static const _ttl = Duration(hours: 6);

  Future<Box<String>> _box() async => Hive.isBoxOpen(_boxName)
      ? Hive.box<String>(_boxName)
      : await Hive.openBox<String>(_boxName);

  String get _args => _sectionArgs(arg);

  @override
  Future<List<AnimeCardData>> build(HomeSection arg) async {
    final cached = await _readCache();
    if (cached != null) {
      if (DateTime.now().difference(cached.time) > _ttl) {
        unawaited(
          Future(() async {
            try {
              await refresh();
            } catch (_) {}
          }),
        );
      }
      return cached.items;
    }
    return _fetchAndSave();
  }

  Future<void> refresh() async {
    final fresh = await _fetchAndSave();
    state = AsyncData(fresh);
  }

  Future<List<AnimeCardData>> _fetchAndSave() async {
    final client = ref.read(anilistClientProvider);
    final raw = await client.browseSection(arg.name, _args);
    final seen = <int>{};
    final items = cardsFromRaw(
      raw,
    ).where((c) => seen.add(c.anilistId)).toList();
    if (items.isNotEmpty) await _writeCache(items);
    return items;
  }

  Future<({List<AnimeCardData> items, DateTime time})?> _readCache() async {
    try {
      final raw = (await _box()).get(arg.name);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['args'] != _args) return null;
      final items = (m['items'] as List).map((e) {
        final x = (e as Map).cast<String, dynamic>();
        return AnimeCardData(
          anilistId: x['id'] as int,
          titleFa: x['fa'] as String,
          titleEn: x['en'] as String,
          cover: x['cover'] as String?,
          year: x['year'] as int?,
          score: (x['score'] as num).toDouble(),
        );
      }).toList();
      if (items.isEmpty) return null;
      return (
        items: items,
        time: DateTime.fromMillisecondsSinceEpoch(m['t'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(List<AnimeCardData> items) async {
    try {
      await (await _box()).put(
        arg.name,
        jsonEncode({
          't': DateTime.now().millisecondsSinceEpoch,
          'args': _args,
          'items': [
            for (final c in items)
              {
                'id': c.anilistId,
                'fa': c.titleFa,
                'en': c.titleEn,
                'cover': c.cover,
                'year': c.year,
                'score': c.score,
              },
          ],
        }),
      );
    } catch (_) {}
  }
}

final homeSectionProvider =
    AsyncNotifierProvider.family<
      HomeSectionNotifier,
      List<AnimeCardData>,
      HomeSection
    >(HomeSectionNotifier.new);

// ─── Step 9: Watch order / Suggestions / Plan ───────────────────────────────

final watchOrderStorageProvider = Provider<WatchOrderStorage>((ref) {
  return WatchOrderStorage(Hive.box<String>(Boxes.meta));
});

class SuggestionService {
  SuggestionService(this._ref);
  final Ref _ref;

  Future<Suggestion?> pick() async {
    final repo = _ref.read(franchiseRepositoryProvider);
    final franchises = repo.allCachedFranchises();
    final statuses = _ref.read(watchStatusProvider);
    final storage = _ref.read(watchOrderStorageProvider);
    final recent = storage.recentSuggestions().toSet();
    final genreCounts = storage.recentGenreCounts();

    final engine = SuggestionEngine();
    final result = engine.pick(
      franchises: franchises,
      statuses: statuses,
      recentFranchiseIds: recent,
      recentGenreCounts: genreCounts,
    );
    if (result != null) {
      await storage.pushSuggestion(
        franchiseId: result.franchise.id,
        genres: result.franchise.genres,
      );
    }
    return result;
  }
}

final suggestionServiceProvider = Provider<SuggestionService>((ref) {
  return SuggestionService(ref);
});

final watchPlanServiceProvider = Provider<WatchPlanService>((ref) {
  final repo = ref.watch(franchiseRepositoryProvider);
  final statuses = ref.watch(watchStatusProvider);
  final episodes = ref.watch(episodeProgressProvider);
  return WatchPlanService(
    franchises: repo.allCachedFranchises(),
    statuses: statuses,
    episodes: episodes,
  );
});

// ─── Step 10: تم (روشن/تیره/سیستمی) و رنگ اصلی ─────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(userExtrasProvider).themeMode();

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(userExtrasProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class SeedColorNotifier extends Notifier<Color> {
  @override
  Color build() => ref.read(userExtrasProvider).seedColor();

  Future<void> set(Color color) async {
    state = color;
    await ref.read(userExtrasProvider).setSeedColor(color);
  }
}

final seedColorProvider = NotifierProvider<SeedColorNotifier, Color>(
  SeedColorNotifier.new,
);

// ─── Step 11: ادامه تماشا ─────────────────────────────────────────────────

/// آیتم‌های «ادامه تماشا»: آثاری که حداقل یک قسمت دیده‌شده دارند و
/// هنوز کامل نشده‌اند؛ مرتب بر اساس آخرین فعالیت.
final continueWatchingProvider = Provider<List<ContinueWatchItem>>((ref) {
  final episodes = ref.watch(episodeProgressProvider);
  final statuses = ref.watch(watchStatusProvider);
  final extras = ref.watch(userExtrasProvider);
  final repo = ref.read(franchiseRepositoryProvider);

  final entryToFranchise = <String, Franchise>{};
  final entryById = <String, Entry>{};
  for (final f in repo.allCachedFranchises()) {
    for (final e in f.entries) {
      entryToFranchise.putIfAbsent(e.id, () => f);
      entryById.putIfAbsent(e.id, () => e);
    }
  }

  final items = <ContinueWatchItem>[];
  for (final kv in episodes.entries) {
    final watched = kv.value;
    if (watched.isEmpty) continue;
    final f = entryToFranchise[kv.key];
    final e = entryById[kv.key];
    if (f == null || e == null) continue;
    if (statuses[kv.key] == WatchStatus.completed) continue;
    final total = e.episodes > 0 ? e.episodes : watched.length;
    final valid = watched.where((n) => n >= 1 && (e.episodes <= 0 || n <= e.episodes));
    if (valid.isEmpty) continue;
    if (e.episodes > 0 && valid.length >= e.episodes) continue;
    final last = valid.reduce((a, b) => a > b ? a : b);
    items.add(
      ContinueWatchItem(
        entryId: e.id,
        franchiseAnilistId: f.anilistId,
        franchiseTitleFa: f.titleFa,
        entryTitle: e.title,
        cover: e.cover,
        lastEpisode: last,
        totalEpisodes: total,
        updatedAtMs: extras.lastSeenOf(e.id),
      ),
    );
  }
  items.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
  return items;
});

// ─── Step 12: قسمت‌های جدید (یادآوری درون‌برنامه‌ای) ───────────────────────

/// آثاری که قسمت پخش‌شده‌ی دیده‌نشده دارند.
final newEpisodesProvider = Provider<List<NewEpisodeItem>>((ref) {
  final episodes = ref.watch(episodeProgressProvider);
  final repo = ref.read(franchiseRepositoryProvider);

  final out = <NewEpisodeItem>[];
  for (final f in repo.allCachedFranchises()) {
    for (final e in f.entries) {
      final aired = e.airedEpisodes();
      if (aired == null || aired <= 0) continue;
      final watched = episodes[e.id] ?? const <int>{};
      final watchedAired = watched.where((n) => n >= 1 && n <= aired).length;
      final unwatched = aired - watchedAired;
      if (unwatched <= 0) continue;
      out.add(
        NewEpisodeItem(
          entryId: e.id,
          franchiseAnilistId: f.anilistId,
          franchiseTitleFa: f.titleFa,
          entryTitle: e.title,
          cover: e.cover,
          newCount: unwatched,
          latestEpisode: aired,
          airingAt: e.nextAiringAt ?? 0,
        ),
      );
    }
  }
  out.sort((a, b) => b.airingAt.compareTo(a.airingAt));
  return out;
});

// ─── Step 13: تقویم پخش هفتگی ─────────────────────────────────────────────

/// گروه‌بندی آثار در حال پخش بر اساس روز هفته (شروع هفته: شنبه).
final weeklyAiringProvider = Provider<List<AiringDay>>((ref) {
  final repo = ref.read(franchiseRepositoryProvider);
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final buckets = <int, List<AiringEntry>>{};
  for (final f in repo.allCachedFranchises()) {
    for (final e in f.entries) {
      final at = e.nextAiringAt;
      final ep = e.nextEpisode;
      if (at == null || ep == null) continue;
      if (at < nowSec - 86400) continue; // قسمت‌های خیلی قدیمی
      final dt = DateTime.fromMillisecondsSinceEpoch(at * 1000);
      buckets.putIfAbsent(dt.weekday, () => []).add(
        AiringEntry(
          entryId: e.id,
          franchiseAnilistId: f.anilistId,
          franchiseTitleFa: f.titleFa,
          entryTitle: e.title,
          cover: e.cover,
          episode: ep,
          airingAt: at,
        ),
      );
    }
  }
  final days = buckets.entries.map((en) {
    final items = en.value
      ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
    return AiringDay(weekday: en.key, items: items);
  }).toList();
  // شروع هفته فارسی: شنبه
  int weekOrder(int w) => (w + 1) % 7;
  days.sort((a, b) => weekOrder(a.weekday).compareTo(weekOrder(b.weekday)));
  return days;
});

// ─── Step 14: داشبورد آمار تماشا ───────────────────────────────────────────

final libraryStatsProvider = Provider<LibraryStats>((ref) {
  final franchises = ref.watch(myListFranchisesProvider);
  final episodes = ref.watch(episodeProgressProvider);
  final statuses = ref.watch(watchStatusProvider);

  var started = 0, completed = 0, dropped = 0, onHold = 0, plan = 0;
  var totalMin = 0, remainMin = 0, totalEp = 0;
  final perFranchise = <FranchiseStat>[];

  for (final mf in franchises) {
    switch (mf.status) {
      case WatchStatus.watching:
        started++;
        break;
      case WatchStatus.completed:
        completed++;
        break;
      case WatchStatus.dropped:
        dropped++;
        break;
      case WatchStatus.onHold:
        onHold++;
        break;
      case WatchStatus.planToWatch:
        plan++;
        break;
    }
    var fMin = 0, fEp = 0;
    for (final e in mf.franchise.entries) {
      final watched = episodes[e.id] ?? const <int>{};
      final wCount = e.episodes > 0
          ? watched.where((n) => n >= 1 && n <= e.episodes).length
          : (statuses[e.id] == WatchStatus.completed ? 1 : 0);
      fEp += wCount;
      totalEp += wCount;
      final m = wCount * e.durationMin;
      fMin += m;
      totalMin += m;

      if (!e.releaseState.excludedFromProgress) {
        final tot = e.episodes > 0
            ? e.episodes
            : (statuses[e.id] == WatchStatus.completed ? 0 : 1);
        final rem = (tot - wCount).clamp(0, 1 << 30);
        remainMin += rem * e.durationMin;
      }
    }
    perFranchise.add(
      FranchiseStat(
        franchiseId: mf.franchise.id,
        anilistId: mf.franchise.anilistId,
        titleFa: mf.franchise.titleFa,
        cover: mf.franchise.cover.isEmpty ? null : mf.franchise.cover,
        watchedEpisodes: fEp,
        watchedMinutes: fMin,
      ),
    );
  }
  perFranchise.sort((a, b) => b.watchedMinutes.compareTo(a.watchedMinutes));

  return LibraryStats(
    started: started,
    completed: completed,
    dropped: dropped,
    onHold: onHold,
    planToWatch: plan,
    totalWatchedEpisodes: totalEp,
    totalWatchedMinutes: totalMin,
    totalRemainingMinutes: remainMin,
    totalFranchises: franchises.length,
    topFranchises: perFranchise.take(10).toList(),
  );
});

// ─── Step 15: اقتصاد بازی‌وار (XP، لول، سکه شفق) ───────────────────────────

class EconomyState {
  final int xp;
  final int level;
  final int coins;
  final int streak;

  const EconomyState({
    required this.xp,
    required this.level,
    required this.coins,
    required this.streak,
  });
}

/// وقتی لول بالا می‌رود، ایندکس لول جدید این‌جا گذاشته می‌شود تا UI جشن بگیرد.
final levelUpEventProvider = StateProvider<int?>((ref) => null);

/// صف اچیومنت‌های تازه بازشده برای نمایش در UI.
final achievementEventProvider =
    StateProvider<List<AchievementDef>>((ref) => const []);

class EconomyNotifier extends Notifier<EconomyState> {
  Economy get _eco => Economy(Hive.box<String>(Boxes.meta));

  /// فرنچایزهایی که جایزه تکمیلشان هم‌اکنون در حال ثبت است.
  final Set<String> _completing = {};

  EconomyState _read() {
    final e = _eco;
    return EconomyState(
      xp: e.xpTotal(),
      level: e.level(),
      coins: e.coins(),
      streak: e.streak(),
    );
  }

  @override
  EconomyState build() => _read();

  void refresh() => state = _read();

  void _leveled(int? lv) {
    if (lv != null) ref.read(levelUpEventProvider.notifier).state = lv;
  }

  Future<void> onEpisodesWatched(int n) async {
    if (n <= 0) return;
    final e = _eco;
    _leveled(await e.addXp(10 * n));
    await e.addCoins(5 * n);
    await e.bumpStat('ep_total', n);
    await e.bumpMissionCounter('ep_d', Economy.todayStr(), n);
    await e.bumpMissionCounter('ep_w', Economy.weekId(), n);
    await e.recordWatchDay();
    for (var i = 0; i < n; i++) {
      await e.bumpHeatDay();
    }
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onRatingGiven() async {
    final e = _eco;
    _leveled(await e.addXp(5));
    await e.bumpStat('rate_total');
    await e.bumpMissionCounter('rate_d', Economy.todayStr());
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onNoteWritten() async {
    final e = _eco;
    _leveled(await e.addXp(5));
    await e.bumpStat('note_total');
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onFranchiseRating(bool first) async {
    if (!first) return;
    final e = _eco;
    _leveled(await e.addXp(5));
    await e.bumpStat('frating_total');
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onFranchiseCompleted(String franchiseId) async {
    // محافظت در برابر فراخوانی هم‌زمان (جایزه فقط یک بار).
    if (_completing.contains(franchiseId)) return;
    final box = Hive.box<String>(Boxes.meta);
    if (box.get('frdone:$franchiseId') == '1') return;
    _completing.add(franchiseId);
    try {
      await box.put('frdone:$franchiseId', '1');
      _leveled(await _eco.addXp(50));
      refresh();
      unawaited(ref.read(achievementsProvider.notifier).evaluate());
    } finally {
      _completing.remove(franchiseId);
    }
  }

  Future<void> markImported() async {
    await Hive.box<String>(Boxes.meta).put('import_done', '1');
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }
}

final economyProvider =
    NotifierProvider<EconomyNotifier, EconomyState>(EconomyNotifier.new);

/// جایزه تکمیل فرنچایز: وقتی همه آثار منتشرشده‌اش کامل شدند.
Future<void> _awardFranchiseCompletion(Ref ref, String entryId) async {
  final repo = ref.read(franchiseRepositoryProvider);
  for (final f in repo.allCachedFranchises()) {
    if (!f.entries.any((e) => e.id == entryId)) continue;
    final progress = progressOf(
      f,
      ref.read(watchStatusProvider),
      ref.read(episodeProgressProvider),
    );
    if (progress.total > 0 && progress.done >= progress.total) {
      await ref.read(economyProvider.notifier).onFranchiseCompleted(f.id);
    }
    break;
  }
}

/// استریک فعلی (از economyProvider خوانده می‌شود تا به‌روز بماند).
final streakProvider = Provider<int>((ref) => ref.watch(economyProvider).streak);

/// هیت‌مپ ۲۶ هفته اخیر.
final heatmapProvider = Provider<List<({String day, int count})>>((ref) {
  ref.watch(economyProvider);
  return Economy(Hive.box<String>(Boxes.meta)).heatDays(182);
});

// ─── Step 16: مأموریت‌ها ──────────────────────────────────────────────────

final missionsProvider =
    NotifierProvider<MissionsNotifier, List<MissionState>>(
      MissionsNotifier.new,
    );

class MissionsNotifier extends Notifier<List<MissionState>> {
  MissionEngine get _engine =>
      MissionEngine(Economy(Hive.box<String>(Boxes.meta)));

  @override
  List<MissionState> build() => _engine.states();

  Future<bool> claim(MissionDef def) async {
    final r = await _engine.claim(def);
    if (!r.ok) return false;
    state = _engine.states();
    ref.read(economyProvider.notifier).refresh();
    if (r.leveledTo != null) {
      ref.read(levelUpEventProvider.notifier).state = r.leveledTo;
    }
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
    return true;
  }
}

// ─── Step 17: اچیومنت‌ها ──────────────────────────────────────────────────

final achievementsProvider =
    NotifierProvider<AchievementsNotifier, Set<String>>(
      AchievementsNotifier.new,
    );

class AchievementsNotifier extends Notifier<Set<String>> {
  late final List<AchievementDef> _defs = buildAchievements();

  /// اچیومنت‌هایی که هم‌اکنون در حال باز شدن‌اند؛ برای جلوگیری از
  /// جایزه‌ی دوباره وقتی دو evaluate هم‌زمان اجرا می‌شوند.
  final Set<String> _inflight = {};

  List<AchievementDef> get all => _defs;

  @override
  Set<String> build() =>
      Economy(Hive.box<String>(Boxes.meta)).unlockedAchievements().toSet();

  AchCtx _buildCtx() {
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final franchises = ref.read(myListFranchisesProvider);
    final stats = ref.read(libraryStatsProvider);
    final genres = <String>{};
    for (final mf in franchises) {
      genres.addAll(mf.franchise.genres);
    }
    final pool = ref.read(cardPoolProvider);
    return AchCtx(
      episodesWatched: eco.statOf('ep_total'),
      franchisesStarted: franchises.length,
      franchisesCompleted:
          franchises.where((m) => m.status == WatchStatus.completed).length,
      distinctGenres: genres.length,
      streak: eco.streak(),
      ratingsGiven: eco.statOf('rate_total'),
      notesWritten: eco.statOf('note_total'),
      franchiseRatings: eco.fratingCount(),
      cardsOwned: pool.totalOwned(),
      cardsPerRarity: pool.ownedPerRarity(),
      packsOpened: eco.statOf('packs_opened'),
      coinsEarned: eco.statOf('coins_earned'),
      missionsDone: eco.statOf('mission_done'),
      level: eco.level(),
      watchMinutes: stats.totalWatchedMinutes,
      importDone: Hive.box<String>(Boxes.meta).get('import_done') == '1',
      checkins: eco.statOf('checkin_total'),
      xpTotal: eco.xpTotal(),
    );
  }

  /// همه اچیومنت‌های محقق‌شده ولی بازنشده را باز می‌کند و جایزه می‌دهد.
  Future<void> evaluate() async {
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final ctx = _buildCtx();
    final newly = <AchievementDef>[];
    for (final d in _defs) {
      if (state.contains(d.id) || _inflight.contains(d.id)) continue;
      bool pass = false;
      try {
        pass = d.test(ctx);
      } catch (_) {}
      if (!pass) continue;
      // بازبینی دوباره روی باکس: اگر evaluate دیگری همین حالا بازش کرده، رد شو.
      if (eco.achievementUnlocked(d.id)) continue;
      _inflight.add(d.id);
      try {
        await eco.unlockAchievement(d.id);
        final leveled = await eco.addXp(d.xp);
        if (d.coins > 0) await eco.addCoins(d.coins);
        if (leveled != null) {
          ref.read(levelUpEventProvider.notifier).state = leveled;
        }
        newly.add(d);
      } finally {
        _inflight.remove(d.id);
      }
    }
    if (newly.isNotEmpty) {
      state = {...state, for (final d in newly) d.id};
      ref.read(achievementEventProvider.notifier).state = [
        ...ref.read(achievementEventProvider),
        ...newly,
      ];
      ref.read(economyProvider.notifier).refresh();
    }
  }
}

// ─── Step 18: کارت‌های کلکسیونی ────────────────────────────────────────────

final cardPoolProvider = Provider<CardPool>((ref) {
  return CardPool(
    Hive.box<String>(Boxes.meta),
    Hive.box<String>('card_cache'),
    ref.watch(anilistClientProvider),
    ref.watch(franchiseRepositoryProvider),
  );
});

class CardsState {
  final Map<CardRarity, List<CollectibleCard>> collection;
  final int poolSize;
  final bool poolLoading;

  const CardsState({
    required this.collection,
    required this.poolSize,
    this.poolLoading = false,
  });
}

final cardsProvider =
    NotifierProvider<CardsNotifier, CardsState>(CardsNotifier.new);

class CardsNotifier extends Notifier<CardsState> {
  CardPool get _pool => ref.read(cardPoolProvider);
  Economy get _eco => Economy(Hive.box<String>(Boxes.meta));

  CardsState _read({bool loading = false}) => CardsState(
        collection: _pool.collection(),
        poolSize: _pool.poolSize(),
        poolLoading: loading,
      );

  @override
  CardsState build() => _read();

  Future<int> rebuildPool({bool force = false}) async {
    state = _read(loading: true);
    final n = await _pool.rebuildPool(force: force);
    state = _read();
    return n;
  }

  Future<PackResult?> openPack() async {
    final r = await _pool.openPack(_eco);
    if (r == null) return null;
    state = _read();
    ref.read(economyProvider.notifier).refresh();
    ref.invalidate(missionsProvider);
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
    return r;
  }
}

// ─── Step 19: نمره فرنچایز (۱ تا ۱۰) ───────────────────────────────────────

final franchiseRatingProvider =
    NotifierProvider.family<FranchiseRatingNotifier, int?, String>(
      FranchiseRatingNotifier.new,
    );

class FranchiseRatingNotifier extends FamilyNotifier<int?, String> {
  Economy get _eco => Economy(Hive.box<String>(Boxes.meta));

  @override
  int? build(String arg) => _eco.fratingOf(arg);

  Future<void> setRating(int v) async {
    final first = await _eco.saveFranchiseRating(arg, v);
    state = v;
    await ref.read(economyProvider.notifier).onFranchiseRating(first);
  }

  Future<void> clear() async {
    await _eco.deleteFranchiseRating(arg);
    state = null;
  }
}

// ─── Step 20: کشف (بخش‌های رتبه‌بندی) ─────────────────────────────────────

enum DiscoverSection {
  trending('انیمه‌های ترند'),
  topSeries('۱۰۰ انیمه برتر سریالی'),
  topMovies('۱۰۰ انیمه برتر سینمایی'),
  weeklyTop('۱۰ انیمه برتر هفته'),
  underrated('انیمه‌های آندرریتد'),
  seasonal('چارت فصلی');

  const DiscoverSection(this.titleFa);
  final String titleFa;
}

class DiscoverSectionData {
  final List<AnimeCardData> items;

  /// تغییر رتبه نسبت به هفته قبل (فقط برای weeklyTop).
  final Map<int, int> rankDelta;

  const DiscoverSectionData({required this.items, this.rankDelta = const {}});
}

({String season, int year}) _currentSeason(DateTime now) {
  final m = now.month;
  if (m <= 3) return (season: 'WINTER', year: now.year);
  if (m <= 6) return (season: 'SPRING', year: now.year);
  if (m <= 9) return (season: 'SUMMER', year: now.year);
  return (season: 'FALL', year: now.year);
}

String discoverArgs(DiscoverSection section) {
  switch (section) {
    case DiscoverSection.trending:
      return 'sort: [TRENDING_DESC]';
    case DiscoverSection.topSeries:
      return 'sort: [SCORE_DESC], format_in: [TV, TV_SHORT]';
    case DiscoverSection.topMovies:
      return 'sort: [SCORE_DESC], format: MOVIE';
    case DiscoverSection.weeklyTop:
      return 'sort: [TRENDING_DESC]';
    case DiscoverSection.underrated:
      return 'sort: [POPULARITY], averageScore_greater: 75';
    case DiscoverSection.seasonal:
      final c = _currentSeason(DateTime.now());
      return 'season: ${c.season}, seasonYear: ${c.year}, sort: [POPULARITY_DESC]';
  }
}

int discoverPerPage(DiscoverSection section) {
  switch (section) {
    case DiscoverSection.topSeries:
    case DiscoverSection.topMovies:
      return 50;
    case DiscoverSection.weeklyTop:
      return 10;
    default:
      return 24;
  }
}

int _discoverPages(DiscoverSection section) {
  switch (section) {
    case DiscoverSection.topSeries:
    case DiscoverSection.topMovies:
      return 2;
    default:
      return 1;
  }
}

class DiscoverSectionNotifier
    extends FamilyAsyncNotifier<DiscoverSectionData, DiscoverSection> {
  static const _boxName = 'discover_cache';
  static const _ttl = Duration(hours: 6);

  Future<Box<String>> _box() async => Hive.isBoxOpen(_boxName)
      ? Hive.box<String>(_boxName)
      : await Hive.openBox<String>(_boxName);

  @override
  Future<DiscoverSectionData> build(DiscoverSection arg) async {
    final cached = await _readCache();
    if (cached != null) {
      if (DateTime.now().difference(cached.time) > _ttl) {
        unawaited(
          Future(() async {
            try {
              await refresh();
            } catch (_) {}
          }),
        );
      }
      return cached.data;
    }
    return _fetchAndSave();
  }

  Future<void> refresh() async {
    final fresh = await _fetchAndSave();
    state = AsyncData(fresh);
  }

  Future<DiscoverSectionData> _fetchAndSave() async {
    final client = ref.read(anilistClientProvider);
    final args = discoverArgs(arg);
    final perPage = discoverPerPage(arg);
    final seen = <int>{};
    final items = <AnimeCardData>[];
    for (var p = 1; p <= _discoverPages(arg); p++) {
      final r = await client.browsePage(
        'discover_${arg.name}',
        args,
        page: p,
        perPage: perPage,
      );
      for (final c in cardsFromRaw(r.items)) {
        if (seen.add(c.anilistId)) items.add(c);
      }
      if (!r.hasNext) break;
    }
    var delta = const <int, int>{};
    if (arg == DiscoverSection.weeklyTop) {
      delta = await _rankDelta(items);
    }
    final data = DiscoverSectionData(items: items, rankDelta: delta);
    if (items.isNotEmpty) await _writeCache(data);
    return data;
  }

  /// تغییر رتبه نسبت به اسنپ‌شات هفته قبل (شنبه تا شنبه).
  Future<Map<int, int>> _rankDelta(List<AnimeCardData> current) async {
    final box = Hive.box<String>(Boxes.meta);
    final week = Economy.weekId();
    Map<String, dynamic>? snap;
    try {
      final raw = box.get('weekly_top');
      if (raw != null) {
        snap = (jsonDecode(raw) as Map).cast<String, dynamic>();
      }
    } catch (_) {}
    if (snap == null || snap['week'] != week) {
      try {
        await box.put(
          'weekly_top',
          jsonEncode({
            'week': week,
            'ids': [for (final c in current) c.anilistId],
          }),
        );
      } catch (_) {}
      return const {};
    }
    final oldIds = (snap['ids'] as List).cast<int>();
    final delta = <int, int>{};
    for (var i = 0; i < current.length; i++) {
      final oldIdx = oldIds.indexOf(current[i].anilistId);
      if (oldIdx >= 0 && oldIdx != i) {
        delta[current[i].anilistId] = oldIdx - i;
      }
    }
    return delta;
  }

  Future<({DiscoverSectionData data, DateTime time})?> _readCache() async {
    try {
      final raw = (await _box()).get(arg.name);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final items = (m['items'] as List).map((e) {
        final x = (e as Map).cast<String, dynamic>();
        return AnimeCardData(
          anilistId: x['id'] as int,
          titleFa: x['fa'] as String,
          titleEn: x['en'] as String,
          cover: x['cover'] as String?,
          year: x['year'] as int?,
          score: (x['score'] as num).toDouble(),
        );
      }).toList();
      if (items.isEmpty) return null;
      final delta = <int, int>{};
      final dm = m['delta'] as Map?;
      if (dm != null) {
        for (final kv in dm.entries) {
          delta[int.tryParse(kv.key.toString()) ?? 0] =
              (kv.value as num).toInt();
        }
      }
      return (
        data: DiscoverSectionData(items: items, rankDelta: delta),
        time: DateTime.fromMillisecondsSinceEpoch(m['t'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(DiscoverSectionData data) async {
    try {
      await (await _box()).put(
        arg.name,
        jsonEncode({
          't': DateTime.now().millisecondsSinceEpoch,
          'items': [
            for (final c in data.items)
              {
                'id': c.anilistId,
                'fa': c.titleFa,
                'en': c.titleEn,
                'cover': c.cover,
                'year': c.year,
                'score': c.score,
              },
          ],
          'delta': {for (final kv in data.rankDelta.entries) '${kv.key}': kv.value},
        }),
      );
    } catch (_) {}
  }
}

final discoverSectionProvider = AsyncNotifierProvider.family<
    DiscoverSectionNotifier,
    DiscoverSectionData,
    DiscoverSection>(DiscoverSectionNotifier.new);

/// چارت فصل بعد (برای تب دوم صفحه چارت فصلی).
final seasonalNextProvider = FutureProvider<List<AnimeCardData>>((ref) async {
  final n = _nextSeason(DateTime.now());
  final client = ref.read(anilistClientProvider);
  final r = await client.browsePage(
    'season_next',
    'season: ${n.season}, seasonYear: ${n.year}, sort: [POPULARITY_DESC]',
    perPage: 24,
  );
  return cardsFromRaw(r.items);
});

// ─── Step 21: پیشنهادها («اگه اینو دوست داشتی...») ──────────────────────────

/// بر اساس فرنچایزهایی با نمره ≥ ۸ یا تکمیل‌شده؛ حداکثر ۲۰ پیشنهاد.
final recommendationsProvider =
    FutureProvider<List<AnimeCardData>>((ref) async {
  final eco = Economy(Hive.box<String>(Boxes.meta));
  final repo = ref.read(franchiseRepositoryProvider);
  final client = ref.read(anilistClientProvider);

  final candidates = <Franchise>[];
  for (final f in repo.allCachedFranchises()) {
    if (f.anilistId <= 0) continue;
    final r = eco.fratingOf(f.id);
    if (r != null && r >= 8) candidates.add(f);
  }
  if (candidates.length < 3) {
    final statuses = ref.read(watchStatusProvider);
    final episodes = ref.read(episodeProgressProvider);
    for (final f in repo.allCachedFranchises()) {
      if (candidates.length >= 5) break;
      if (candidates.contains(f)) continue;
      final p = progressOf(f, statuses, episodes);
      if (p.total > 0 && p.done >= p.total) candidates.add(f);
    }
  }

  final seen = <int>{for (final f in repo.allCachedFranchises()) f.anilistId};
  final out = <AnimeCardData>[];
  for (final f in candidates.take(5)) {
    final recs = await client.fetchRecommendations(f.anilistId);
    for (final n in recs) {
      final m = (n['mediaRecommendation'] as Map?)?.cast<String, dynamic>();
      if (m == null) continue;
      final id = m['id'] as int?;
      if (id == null || !seen.add(id)) continue;
      final t = (m['title'] as Map?)?.cast<String, dynamic>() ?? const {};
      final avg = m['averageScore'] as int?;
      out.add(
        AnimeCardData(
          anilistId: id,
          malId: (m['idMal'] as int?) ?? 0,
          titleFa: (t['english'] ?? t['romaji'] ?? '—') as String,
          titleEn: (t['english'] ?? t['romaji'] ?? '—') as String,
          cover: ((m['coverImage'] as Map?)?['large']) as String?,
          score: avg == null ? 0 : avg / 10.0,
        ),
      );
      if (out.length >= 20) break;
    }
    if (out.length >= 20) break;
  }
  return out;
});

// ─── Step 22: ایمپورت لیست ────────────────────────────────────────────────

class ImportState {
  final bool running;
  final String status;
  final LibraryImportResult? result;

  const ImportState({this.running = false, this.status = '', this.result});

  ImportState copyWith({bool? running, String? status, LibraryImportResult? result}) =>
      ImportState(
        running: running ?? this.running,
        status: status ?? this.status,
        result: result ?? this.result,
      );
}

final importProvider =
    NotifierProvider<ImportNotifier, ImportState>(ImportNotifier.new);

class ImportNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  Future<void> run({required bool useAnilist, required String username}) async {
    if (state.running) return;
    state = const ImportState(running: true, status: 'شروع...');
    LibraryImportResult r;
    try {
      r = useAnilist
          ? await importFromAniList(
              ref, username, (s) => state = state.copyWith(status: s))
          : await importFromMal(
              ref, username, (s) => state = state.copyWith(status: s));
    } catch (e) {
      r = LibraryImportResult(ok: false, message: 'خطا: $e');
    }
    state = ImportState(result: r);
    if (r.ok) {
      ref.invalidate(watchStatusProvider);
      ref.invalidate(episodeProgressProvider);
      ref.invalidate(myListFranchisesProvider);
      unawaited(ref.read(achievementsProvider.notifier).evaluate());
    }
  }

  void reset() => state = const ImportState();
}

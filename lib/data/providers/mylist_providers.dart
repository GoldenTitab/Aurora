import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../models/entry.dart';
import '../models/franchise.dart';
import '../models/home_items.dart';
import '../models/library_stats.dart';
import '../models/watch_status.dart';
import 'core_providers.dart';
import 'watch_providers.dart';

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

/// گاید پخش هفتگی (مثل گاید تلویزیونی): همه انیمه‌هایی که در ۷ روز آینده
/// قسمت جدید دارند، مستقیم از AiringSchedule ـی AniList.
/// برخلاف نسخه قبلی به کتابخانه کاربر وابسته نیست، پس هیچ‌وقت به‌خاطر
/// خالی بودن کش خالی نمی‌ماند (فقط با قطعی اینترنت خالی است).
final weeklyAiringProvider = FutureProvider<List<AiringDay>>((ref) async {
  final ani = ref.read(anilistClientProvider);
  final schedules = await ani.fetchWeeklyAiringGuide();

  final buckets = <int, List<AiringEntry>>{};
  for (final s in schedules) {
    final at = s['airingAt'] as int;
    final ep = s['episode'] as int;
    if (at <= 0 || ep <= 0) continue;
    final media = s['media'] as Map<String, dynamic>;
    final id = (media['id'] as num).toInt();
    final t = (media['title'] as Map?) ?? const {};
    final title =
        (t['english'] ?? t['romaji'] ?? t['native'] ?? '—') as String;
    final dt = DateTime.fromMillisecondsSinceEpoch(at * 1000);
    buckets.putIfAbsent(dt.weekday, () => []).add(
      AiringEntry(
        entryId: 'al-$id',
        franchiseAnilistId: id,
        franchiseTitleFa: persianTitles[id] ?? title,
        entryTitle: title,
        cover: (media['coverImage'] as Map?)?['large'] as String?,
        episode: ep,
        airingAt: at,
      ),
    );
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

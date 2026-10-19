import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/i18n/lang.dart';
import '../models/anime_card_data.dart';
import '../models/franchise.dart';
import '../remote/anilist_client.dart';
import '../storage/economy.dart';
import '../storage/migrations.dart' show Boxes;
import 'core_providers.dart';
import 'home_providers.dart';
import 'watch_providers.dart';

enum DiscoverSection {
  airing('currently_airing'),
  seasonal('seasonal_chart'),
  soon('coming_soon'),
  underrated('underrated_anime');

  const DiscoverSection(this.key);
  final String key;

  String get titleFa => tr(key);
}

class DiscoverSectionData {
  final List<AnimeCardData> items;

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
    case DiscoverSection.airing:
      return 'status: RELEASING, sort: [POPULARITY_DESC]';
    case DiscoverSection.underrated:
      return 'sort: [POPULARITY], averageScore_greater: 75';
    case DiscoverSection.seasonal:
      final c = _currentSeason(DateTime.now());
      return 'season: ${c.season}, seasonYear: ${c.year}, sort: [POPULARITY_DESC]';
    case DiscoverSection.soon:
      return 'status: NOT_YET_RELEASED, sort: [POPULARITY_DESC]';
  }
}

int discoverPerPage(DiscoverSection section) => 24;

int _discoverPages(DiscoverSection section) => 1;

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
    DiscoverSectionData data;
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
      data = cached.data;
    } else {
      data = await _fetchAndSave();
    }
    if (arg == DiscoverSection.underrated) {
      final filtered = data.items
          .where((c) => c.countryOfOrigin != 'CN')
          .toList();
      if (filtered.length != data.items.length) {
        return DiscoverSectionData(items: filtered, rankDelta: data.rankDelta);
      }
    }
    return data;
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
    final delta = const <int, int>{};
    final data = DiscoverSectionData(items: items, rankDelta: delta);
    if (items.isNotEmpty) await _writeCache(data);
    return data;
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
          countryOfOrigin: x['co'] as String?,
          status: x['st'] as String?,
        );
      }).toList();
      if (items.isEmpty) return null;
      final delta = <int, int>{};
      final dm = m['delta'] as Map?;
      if (dm != null) {
        for (final kv in dm.entries) {
          delta[int.tryParse(kv.key.toString()) ?? 0] = (kv.value as num)
              .toInt();
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
                'co': c.countryOfOrigin,
                'st': c.status,
              },
          ],
          'delta': {
            for (final kv in data.rankDelta.entries) '${kv.key}': kv.value,
          },
        }),
      );
    } catch (_) {}
  }
}

final discoverSectionProvider =
    AsyncNotifierProvider.family<
      DiscoverSectionNotifier,
      DiscoverSectionData,
      DiscoverSection
    >(DiscoverSectionNotifier.new);

/// همه‌ی انیمه‌های یک فصل — صفحه‌بندی کامل تا جایی که API ادامه دارد.
/// نتایج با شناسه‌ی پایدار AniList یکتاسازی می‌شوند؛ سقف ۲۰ صفحه جلوی
/// حلقه‌ی بی‌نهایت را می‌گیرد.
Future<List<AnimeCardData>> _fetchSeasonAll(
  AniListClient client,
  String season,
  int year,
) async {
  final seen = <int>{};
  final out = <AnimeCardData>[];
  var page = 1;
  while (true) {
    final r = await client.browsePage(
      'season_all_${season}_$year',
      'season: $season, seasonYear: $year, sort: [POPULARITY_DESC]',
      page: page,
      perPage: 50,
    );
    for (final c in cardsFromRaw(r.items)) {
      if (seen.add(c.anilistId)) out.add(c);
    }
    if (!r.hasNext || page >= 20) break;
    page++;
  }
  return out;
}

Future<Box<String>> _seasonCacheBox() async =>
    Hive.isBoxOpen('discover_cache')
    ? Hive.box<String>('discover_cache')
    : await Hive.openBox<String>('discover_cache');

/// خواندن/نوشتن کش ۱۲ ساعته‌ی لیست کامل فصل.
Future<List<AnimeCardData>?> _readSeasonCache(String key) async {
  try {
    final raw = (await _seasonCacheBox()).get(key);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final t = m['t'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - t >
        const Duration(hours: 12).inMilliseconds) {
      return null;
    }
    final items = (m['items'] as List?) ?? const [];
    if (items.isEmpty) return null;
    return items.map((e) {
      final x = (e as Map).cast<String, dynamic>();
      return AnimeCardData(
        anilistId: x['id'] as int,
        titleFa: x['fa'] as String,
        titleEn: x['en'] as String,
        cover: x['cover'] as String?,
        year: x['year'] as int?,
        score: (x['score'] as num).toDouble(),
        countryOfOrigin: x['co'] as String?,
        status: x['st'] as String?,
        format: x['fmt'] as String?,
      );
    }).toList();
  } catch (_) {
    return null;
  }
}

Future<void> _writeSeasonCache(String key, List<AnimeCardData> items) async {
  try {
    await (await _seasonCacheBox()).put(
      key,
      jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'items': [
          for (final c in items)
            {
              'id': c.anilistId,
              'fa': c.titleFa,
              'en': c.titleEn,
              'cover': c.cover,
              'year': c.year,
              'score': c.score,
              'co': c.countryOfOrigin,
              'st': c.status,
              'fmt': c.format,
            },
        ],
      }),
    );
  } catch (_) {}
}

Future<List<AnimeCardData>> _seasonAll(
  AniListClient client,
  String cacheKey,
  String season,
  int year,
) async {
  final cached = await _readSeasonCache(cacheKey);
  if (cached != null) return cached;
  final items = await _fetchSeasonAll(client, season, year);
  if (items.isNotEmpty) await _writeSeasonCache(cacheKey, items);
  return items;
}

/// لیست کامل فصل جاری (نه فقط ۲۴ تای اول).
final seasonalAllProvider = FutureProvider<List<AnimeCardData>>((ref) async {
  final c = _currentSeason(DateTime.now());
  return _seasonAll(
    ref.read(anilistClientProvider),
    'season_all_current',
    c.season,
    c.year,
  );
});

/// لیست کامل فصل بعد (نه فقط ۲۴ تای اول).
final seasonalNextProvider = FutureProvider<List<AnimeCardData>>((ref) async {
  final n = _nextSeason(DateTime.now());
  return _seasonAll(
    ref.read(anilistClientProvider),
    'season_all_next',
    n.season,
    n.year,
  );
});

/// لیست کامل فصل قبل (نه فقط ۲۴ تای اول).
final seasonalPrevProvider = FutureProvider<List<AnimeCardData>>((ref) async {
  final p = _prevSeason(DateTime.now());
  return _seasonAll(
    ref.read(anilistClientProvider),
    'season_all_prev',
    p.season,
    p.year,
  );
});

final recommendationsProvider = FutureProvider<List<AnimeCardData>>((
  ref,
) async {
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

({String season, int year}) _nextSeason(DateTime now) {
  final m = now.month;
  if (m <= 3) return (season: 'SPRING', year: now.year);
  if (m <= 6) return (season: 'SUMMER', year: now.year);
  if (m <= 9) return (season: 'FALL', year: now.year);
  return (season: 'WINTER', year: now.year + 1);
}

({String season, int year}) _prevSeason(DateTime now) {
  final m = now.month;
  if (m <= 3) return (season: 'FALL', year: now.year - 1);
  if (m <= 6) return (season: 'WINTER', year: now.year);
  if (m <= 9) return (season: 'SPRING', year: now.year);
  return (season: 'SUMMER', year: now.year);
}

/// شروع فصل بعد (میلادی) برای شمارش معکوس.
DateTime nextSeasonStart(DateTime now) {
  final n = _nextSeason(now);
  final month = switch (n.season) {
    'WINTER' => 1,
    'SPRING' => 4,
    'SUMMER' => 7,
    _ => 10,
  };
  return DateTime(n.year, month, 1);
}

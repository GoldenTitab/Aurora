import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/i18n/lang.dart';
import '../models/anime_card_data.dart';
import '../models/franchise.dart';
import '../storage/economy.dart';
import '../storage/migrations.dart' show Boxes;
import 'core_providers.dart';
import 'home_providers.dart';
import 'watch_providers.dart';

enum DiscoverSection {
  trending('trending_anime'),
  topSeries('top_100_tv_anime'),
  topMovies('top_100_anime_movies'),
  underrated('underrated_anime'),
  seasonal('seasonal_chart');

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
    case DiscoverSection.trending:
      return 'sort: [TRENDING_DESC]';
    case DiscoverSection.topSeries:
      return 'sort: [SCORE_DESC], format_in: [TV, TV_SHORT]';
    case DiscoverSection.topMovies:
      return 'sort: [SCORE_DESC], format: MOVIE';
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/i18n/lang.dart';
import '../models/anime_card_data.dart';
import '../remote/anilist_client.dart';
import '../storage/migrations.dart' show Boxes;
import '../storage/watch_order_storage.dart';
import 'core_providers.dart';

enum HomeSection {
  airing('airing'),
  nextSeason('next_season'),
  top('top'),
  movies('movies'),
  series('tv_series_2');

  const HomeSection(this.key);
  final String key;

  String get titleFa => tr(key);
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
        countryOfOrigin: m['countryOfOrigin'] as String?,
        status: m['status'] as String?,
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
          countryOfOrigin: x['co'] as String?,
          status: x['st'] as String?,
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
                'co': c.countryOfOrigin,
                'st': c.status,
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

final watchOrderStorageProvider = Provider<WatchOrderStorage>((ref) {
  return WatchOrderStorage(Hive.box<String>(Boxes.meta));
});

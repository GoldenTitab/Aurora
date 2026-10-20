import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/anime_card_data.dart';
import '../services/suggestion_engine.dart';
import '../services/watch_plan_service.dart';
import '../storage/migrations.dart' show Boxes;
import 'core_providers.dart';
import 'discover_providers.dart';
import 'home_providers.dart';
import 'watch_providers.dart';

class SuggestionService {
  SuggestionService(this._ref);
  final Ref _ref;

  Future<Suggestion?> pick() async {
    final candidates = await _baseCandidates();
    if (candidates.isEmpty) {
      return null;
    }

    final engine = SuggestionEngine();
    final result = engine.pickExternal(
      candidates: candidates,
      excludedEntryIds: _excludedIds(),
      recentIds: _recentIds(),
    );
    if (result != null) {
      await _remember(result);
    }
    return result;
  }

  Set<String> _excludedIds() {
    final repo = _ref.read(franchiseRepositoryProvider);
    final statuses = _ref.read(watchStatusProvider);
    final excluded = <String>{...statuses.keys};
    for (final f in repo.allCachedFranchises()) {
      for (final e in f.entries) {
        excluded.add(e.id);
      }
    }
    return excluded;
  }

  Set<String> _recentIds() =>
      _ref.read(watchOrderStorageProvider).recentSuggestions().toSet();

  Future<List<({AnimeCardData data, String sourceFa})>>
  _baseCandidates() async {
    final sectionWeight = {
      DiscoverSection.airing: 'airing',
      DiscoverSection.seasonal: 'seasonal',
      DiscoverSection.underrated: 'underrated',
    };
    final candidates = <({AnimeCardData data, String sourceFa})>[];
    for (final entry in sectionWeight.entries) {
      try {
        final data = await _ref.read(discoverSectionProvider(entry.key).future);
        for (final d in data.items) {
          if (d.status != 'FINISHED') continue;
          candidates.add((data: d, sourceFa: entry.value));
        }
      } catch (_) {}
    }
    try {
      final client = _ref.read(anilistClientProvider);
      final seenTop = <int>{};
      for (var p = 1; p <= 2; p++) {
        final r = await client.browsePage(
          'suggest_top',
          'sort: [SCORE_DESC]',
          page: p,
          perPage: 50,
        );
        for (final d in cardsFromRaw(r.items)) {
          if (d.status != 'FINISHED') continue;
          if (seenTop.add(d.anilistId)) {
            candidates.add((data: d, sourceFa: 'top'));
          }
        }
        if (!r.hasNext) break;
      }
    } catch (_) {}
    return candidates;
  }

  List<AnimeCardData> _eligible(
    List<({AnimeCardData data, String sourceFa})> candidates,
  ) {
    final excluded = _excludedIds();
    final recent = _recentIds();
    final seen = <String>{};
    final out = <AnimeCardData>[];
    for (final c in candidates) {
      final d = c.data;
      final key = d.anilistId > 0 ? 'al-${d.anilistId}' : 'mal-${d.malId}';
      if (!seen.add(key)) continue;
      if (recent.contains(key)) continue;
      if (excluded.any((e) => e == key || key.startsWith('$e-'))) continue;
      out.add(d);
    }
    return out;
  }

  Future<void> _remember(Suggestion s) async {
    await _ref
        .read(watchOrderStorageProvider)
        .pushSuggestion(franchiseId: s.historyId, genres: const []);
    try {
      final box = Hive.box<String>(Boxes.meta);
      final raw = box.get('suggestion_cards');
      final map = <String, dynamic>{
        if (raw != null && raw.isNotEmpty)
          ...(jsonDecode(raw) as Map).cast<String, dynamic>(),
      };
      map[s.historyId] = {
        'fa': s.data.titleFa,
        'en': s.data.titleEn,
        'cover': s.data.cover,
        'al': s.data.anilistId,
        'mal': s.data.malId,
      };
      while (map.length > 20) {
        map.remove(map.keys.first);
      }
      await box.put('suggestion_cards', jsonEncode(map));
      await box.put('last_suggestion', s.historyId);
    } catch (_) {}
  }

  static Map<String, Map<String, dynamic>> cachedCards() {
    try {
      final raw = Hive.box<String>(Boxes.meta).get('suggestion_cards');
      if (raw == null || raw.isEmpty) return const {};
      return (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k.toString(), (v as Map).cast<String, dynamic>()),
      );
    } catch (_) {
      return const {};
    }
  }

  static Suggestion? lastCached() {
    try {
      final box = Hive.box<String>(Boxes.meta);
      final id = box.get('last_suggestion');
      if (id == null || id.isEmpty) return null;
      final card = cachedCards()[id];
      if (card == null) return null;
      return Suggestion(
        data: AnimeCardData(
          anilistId: (card['al'] as num?)?.toInt() ?? 0,
          malId: (card['mal'] as num?)?.toInt() ?? 0,
          titleFa: (card['fa'] as String?) ?? '',
          titleEn: (card['en'] as String?) ?? '',
          cover: card['cover'] as String?,
          score: 0,
        ),
        score: 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Suggestion?> pickRandom() async {
    final pool = _eligible(await _baseCandidates());
    if (pool.isEmpty) return null;
    final d = pool[Random().nextInt(pool.length)];
    final s = Suggestion(data: d, score: 0, reasonKey: 'picked_purely_by_luck');
    await _remember(s);
    return s;
  }

  Future<Suggestion?> pickTonight(int minutes) async {
    final format = minutes <= 90 ? 'MOVIE' : 'TV';
    final client = _ref.read(anilistClientProvider);
    final r = await client.advancedBrowse(
      perPage: 50,
      format: format,
      status: 'FINISHED',
      sort: 'POPULARITY_DESC',
    );
    final pool = _eligible([
      for (final d in cardsFromRaw(r.items))
        if (d.status == 'FINISHED') (data: d, sourceFa: 'tonight'),
    ]);
    if (pool.isEmpty) return null;
    final d = pool[Random().nextInt(pool.length)];
    final s = Suggestion(
      data: d,
      score: 0,
      reasonKey: 'fits_your_time',
      reasonArgKeys: [minutes <= 90 ? 'a_movie' : 'a_series'],
    );
    await _remember(s);
    return s;
  }

  Future<Suggestion?> pickMood(String genreEn) async {
    final client = _ref.read(anilistClientProvider);
    final r = await client.advancedBrowse(
      perPage: 50,
      genres: [genreEn],
      status: 'FINISHED',
      sort: 'POPULARITY_DESC',
    );
    final pool = _eligible([
      for (final d in cardsFromRaw(r.items))
        if (d.status == 'FINISHED') (data: d, sourceFa: 'mood'),
    ]);
    if (pool.isEmpty) return null;
    final d = pool[Random().nextInt(pool.length)];
    final s = Suggestion(
      data: d,
      score: 0,
      reasonKey: 'matches_your_mood',
      reasonArgKeys: ['mood_${genreEn.toLowerCase()}'],
    );
    await _remember(s);
    return s;
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

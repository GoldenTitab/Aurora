import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/anime_card_data.dart';
import '../services/suggestion_engine.dart';
import '../services/watch_plan_service.dart';
import 'core_providers.dart';
import 'discover_providers.dart';
import 'home_providers.dart';
import 'watch_providers.dart';

class SuggestionService {
  SuggestionService(this._ref);
  final Ref _ref;

  Future<Suggestion?> pick() async {
    final repo = _ref.read(franchiseRepositoryProvider);
    final statuses = _ref.read(watchStatusProvider);
    final storage = _ref.read(watchOrderStorageProvider);
    final recent = storage.recentSuggestions().toSet();

    final excluded = <String>{...statuses.keys};
    for (final f in repo.allCachedFranchises()) {
      for (final e in f.entries) {
        excluded.add(e.id);
      }
    }

    final sectionWeight = {
      DiscoverSection.trending: 'trending',
      DiscoverSection.seasonal: 'seasonal',
      DiscoverSection.topSeries: 'top',
      DiscoverSection.topMovies: 'top',
      DiscoverSection.underrated: 'underrated',
    };
    final candidates = <({AnimeCardData data, String sourceFa})>[];
    for (final entry in sectionWeight.entries) {
      try {
        final data = await _ref.read(discoverSectionProvider(entry.key).future);
        for (final d in data.items) {
          if (d.status != null && d.status != 'FINISHED') continue;
          candidates.add((data: d, sourceFa: entry.value));
        }
      } catch (_) {}
    }
    if (candidates.isEmpty) return null;

    final engine = SuggestionEngine();
    final result = engine.pickExternal(
      candidates: candidates,
      excludedEntryIds: excluded,
      recentIds: recent,
    );
    if (result != null) {
      await storage.pushSuggestion(
        franchiseId: result.historyId,
        genres: const [],
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

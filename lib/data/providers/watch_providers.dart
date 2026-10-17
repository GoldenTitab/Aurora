import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/i18n/lang.dart';
import '../../core/utils/text_utils.dart';
import '../models/anime_card_data.dart';
import '../models/entry.dart';
import '../models/franchise.dart';
import '../models/watch_status.dart';
import '../storage/economy.dart';
import '../storage/migrations.dart' show Boxes;
import 'core_providers.dart';
import 'gamification_providers.dart';

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

/// جست‌وجوی دو مرحله‌ای: اول نتایج لوکال + AniList (سریع) نمایش داده
/// می‌شود، بعد نتایج تکمیلی Jikan/MAL به همان لیست اضافه می‌شود.
/// برای همین سرچ خیلی سریع‌تر به نظر می‌رسد.
final searchResultsProvider = StreamProvider.autoDispose
    .family<List<AnimeCardData>, String>((ref, query) async* {
      final repo = ref.watch(franchiseRepositoryProvider);

      final localFranchises = repo.localSearch(query);
      final results = localFranchises.map(AnimeCardData.fromFranchise).toList();

      if (hasPersian(query)) {
        yield results;
        return;
      }

      final seenRoots = <String>{for (final f in localFranchises) f.id};
      void addHits(List<AnimeCardData> hits) {
        for (final hit in hits) {
          final root = hit.anilistId > 0
              ? (repo.aliasOf(hit.anilistId) ?? 'al-${hit.anilistId}')
              : 'mal-${hit.malId}';
          if (seenRoots.add(root)) results.add(hit);
        }
      }

      // مرحله ۱: AniList
      var ok = false;
      final p = await repo.searchPrimary(query);
      if (p.ok) ok = true;
      addHits(p.items);
      yield List.of(results);

      // مرحله ۲: Jikan + MAL (تکمیلی)
      final s = await repo.searchSecondary(query, p.seenAni, p.seenMal);
      if (s.ok) ok = true;
      if (s.items.isNotEmpty) {
        addHits(s.items);
        yield List.of(results);
      }

      if (!ok && results.isEmpty) {
        throw StateError(tr('search_failed_check_your_internet_connection'));
      }
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

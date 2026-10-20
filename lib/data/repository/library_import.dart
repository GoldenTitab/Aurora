import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watch_status.dart';
import '../providers.dart';
import '../remote/api_exception.dart';
import '../../core/i18n/lang.dart';

class LibraryImportResult {
  final bool ok;
  final String message;
  final int imported;
  final int skipped;
  final int alreadyHad;
  final int failed;
  final bool cancelled;

  const LibraryImportResult({
    required this.ok,
    required this.message,
    this.imported = 0,
    this.skipped = 0,
    this.alreadyHad = 0,
    this.failed = 0,
    this.cancelled = false,
  });
}

WatchStatus? _anilistStatus(String? s) {
  switch (s) {
    case 'CURRENT':
      return WatchStatus.watching;
    case 'REPEATING':
      return WatchStatus.watching;
    case 'COMPLETED':
      return WatchStatus.completed;
    case 'PAUSED':
      return WatchStatus.onHold;
    case 'DROPPED':
      return WatchStatus.dropped;
    case 'PLANNING':
      return WatchStatus.planToWatch;
    default:
      return null;
  }
}

int _malWatchedEpisodes(Map<String, dynamic> e) {
  final direct =
      e['episodes_watched'] ??
      e['watched_episodes'] ??
      e['num_episodes_watched'] ??
      e['progress'];
  if (direct is num) {
    return direct.toInt();
  }
  final listStatus = e['list_status'];
  if (listStatus is Map) {
    final nested =
        listStatus['num_episodes_watched'] ??
        listStatus['episodes_watched'] ??
        listStatus['watched_episodes'];
    if (nested is num) {
      return nested.toInt();
    }
  }
  return 0;
}

WatchStatus? _jikanStatus(String? s) {
  switch (s) {
    case 'watching':
      return WatchStatus.watching;
    case 'completed':
      return WatchStatus.completed;
    case 'on_hold':
      return WatchStatus.onHold;
    case 'dropped':
      return WatchStatus.dropped;
    case 'plan_to_watch':
      return WatchStatus.planToWatch;
    default:
      return null;
  }
}

Future<LibraryImportResult> importFromAniList(
  Ref ref,
  String username,
  void Function(String) onProgress, {
  bool Function()? isCancelled,
}) async {
  final client = ref.read(anilistClientProvider);
  final repo = ref.read(franchiseRepositoryProvider);

  onProgress(tr('fetching_list'));
  List<Map<String, dynamic>>? entries;
  try {
    entries = await client.fetchUserAnimeList(username.trim());
  } catch (e) {
    return LibraryImportResult(ok: false, message: friendlyError(e));
  }
  if (entries == null) {
    return LibraryImportResult(
      ok: false,
      message: tr('user_not_found_or_their_list_is_private'),
    );
  }
  if (entries.isEmpty) {
    return LibraryImportResult(
      ok: false,
      message: tr('this_user_s_list_is_empty'),
    );
  }

  const cap = 60;
  var imported = 0;
  var skipped = 0;
  var alreadyHad = 0;
  var failed = 0;
  final total = entries.length > cap ? cap : entries.length;
  var cancelled = false;

  for (var i = 0; i < total; i++) {
    if (isCancelled?.call() ?? false) {
      cancelled = true;
      break;
    }
    final e = entries[i];
    onProgress(tr('importing_of', [i + 1, total]));
    final media = (e['media'] as Map?)?.cast<String, dynamic>();
    final anilistId = media?['id'] as int?;
    final status = _anilistStatus(e['listStatus'] as String?);
    if (anilistId == null || status == null) {
      skipped++;
      continue;
    }
    try {
      final f = await repo.getFranchise(anilistId);
      final entry = f.entries.firstWhere(
        (x) => x.anilistId == anilistId,
        orElse: () => f.entries.first,
      );
      final had = ref.read(watchStatusProvider)[entry.id] != null;
      await ref.read(watchStatusProvider.notifier).setStatus(entry.id, status);
      final progress = (e['progress'] as num?)?.toInt() ?? 0;
      if (progress > 0 && entry.episodes > 0) {
        await ref
            .read(episodeProgressProvider.notifier)
            .markUpTo(
              entry.id,
              progress.clamp(1, entry.episodes).toInt(),
              entry.episodes,
              reward: false,
            );
      }
      if (had) {
        alreadyHad++;
      } else {
        imported++;
      }
    } catch (_) {
      failed++;
    }
  }

  if (!cancelled) {
    await ref.read(economyProvider.notifier).markImported();
  }
  return LibraryImportResult(
    ok: !cancelled,
    message: cancelled
        ? tr('import_cancelled')
        : tr('titles_imported', [
            imported,
            skipped > 0 ? tr('skipped', [skipped]) : '',
          ]),
    imported: imported,
    skipped: skipped,
    alreadyHad: alreadyHad,
    failed: failed,
    cancelled: cancelled,
  );
}

Future<LibraryImportResult> importFromMal(
  Ref ref,
  String username,
  void Function(String) onProgress, {
  bool Function()? isCancelled,
}) async {
  final jikan = ref.read(jikanClientProvider);
  final ani = ref.read(anilistClientProvider);
  final repo = ref.read(franchiseRepositoryProvider);

  onProgress(tr('fetching_mal_list'));
  final all = <Map<String, dynamic>>[];
  try {
    for (final s in [
      'watching',
      'completed',
      'on_hold',
      'dropped',
      'plan_to_watch',
    ]) {
      var page = 1;
      while (true) {
        final batch = await jikan.fetchUserList(username.trim(), s, page);
        if (batch == null) {
          return LibraryImportResult(
            ok: false,
            message: tr('user_not_found_or_their_list_is_private'),
          );
        }
        if (batch.isEmpty) break;
        all.addAll(batch.map((e) => {...e, 'jikanStatus': s}));
        if (batch.length < 100) break;
        page++;
        if (page > 10) break;
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
  } catch (e) {
    return LibraryImportResult(ok: false, message: friendlyError(e));
  }
  if (all.isEmpty) {
    return LibraryImportResult(
      ok: false,
      message: tr('this_user_s_list_is_empty'),
    );
  }

  const cap = 40;
  var imported = 0;
  var skipped = 0;
  var alreadyHad = 0;
  var failed = 0;
  final total = all.length > cap ? cap : all.length;
  var cancelled = false;

  for (var i = 0; i < total; i++) {
    if (isCancelled?.call() ?? false) {
      cancelled = true;
      break;
    }
    final e = all[i];
    onProgress(tr('importing_of', [i + 1, total]));
    final malId = (e['mal_id'] as num?)?.toInt();
    final status = _jikanStatus(e['jikanStatus'] as String?);
    if (malId == null || status == null) {
      skipped++;
      continue;
    }
    try {
      final media = await ani.fetchMediaByMal(malId);
      final anilistId = media?['id'] as int?;
      if (anilistId == null) {
        skipped++;
        continue;
      }
      final f = await repo.getFranchise(anilistId);
      final entry = f.entries.firstWhere(
        (x) => x.anilistId == anilistId,
        orElse: () => f.entries.first,
      );
      final had = ref.read(watchStatusProvider)[entry.id] != null;
      await ref.read(watchStatusProvider.notifier).setStatus(entry.id, status);
      final watched = _malWatchedEpisodes(e);
      if (watched > 0 && entry.episodes > 0) {
        await ref
            .read(episodeProgressProvider.notifier)
            .markUpTo(
              entry.id,
              watched.clamp(1, entry.episodes).toInt(),
              entry.episodes,
              reward: false,
            );
      }
      if (had) {
        alreadyHad++;
      } else {
        imported++;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {
      failed++;
    }
  }

  if (!cancelled) {
    await ref.read(economyProvider.notifier).markImported();
  }
  return LibraryImportResult(
    ok: !cancelled,
    message: cancelled
        ? tr('import_cancelled')
        : tr('titles_imported', [
            imported,
            skipped > 0 ? tr('skipped', [skipped]) : '',
          ]),
    imported: imported,
    skipped: skipped,
    alreadyHad: alreadyHad,
    failed: failed,
    cancelled: cancelled,
  );
}

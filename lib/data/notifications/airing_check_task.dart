import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/i18n/lang.dart';
import '../models/watch_status.dart';
import '../remote/anilist_client.dart';
import '../remote/api_gateway.dart';
import 'notification_content.dart';

const String airingCheckUniqueName = 'aurora-daily-check';

const String airingCheckTaskName = 'dailyAiringCheck';

const String _marksBoxName = 'airing_marks';

const int _maxFreshFetches = 15;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == airingCheckTaskName) {
        await _runAiringCheck();
      }
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> scheduleDailyAiringCheck(int hour) async {
  try {
    await Workmanager().cancelByUniqueName(airingCheckUniqueName);
    await Workmanager().registerPeriodicTask(
      airingCheckUniqueName,
      airingCheckTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: delayUntilNextHour(hour),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (_) {}
}

Future<void> cancelDailyAiringCheck() async {
  try {
    await Workmanager().cancelByUniqueName(airingCheckUniqueName);
  } catch (_) {}
}

Duration delayUntilNextHour(int hour) {
  final h = hour.clamp(0, 23);
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, h);
  if (!next.isAfter(now)) {
    next = DateTime(now.year, now.month, now.day + 1, h);
  }
  return next.difference(now);
}

class _Candidate {
  _Candidate({
    required this.id,
    required this.title,
    required this.anilistId,
    required this.status,
    required this.episodes,
    required this.nextEpisode,
    required this.nextAiringAt,
  });

  final String id;
  final String title;
  final int anilistId;
  String? status;
  int episodes;
  int? nextEpisode;
  int? nextAiringAt;
}

Future<void> _runAiringCheck() async {
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  try {
    await _check();
  } finally {
    try {
      await Hive.close();
    } catch (_) {}
  }
}

Future<void> _check() async {
  final meta = await Hive.openBox<String>('app_meta');
  Lang.current = meta.get('app_lang') == 'en' ? 'en' : 'fa';
  if (!NotificationPrefs.isEnabled(meta)) return;

  final statusBox = await Hive.openBox<String>('watch_status');
  final franchiseBox = await Hive.openBox<String>('franchise_cache');
  final progressBox = await Hive.openBox<String>('episode_progress');
  final marks = await Hive.openBox<String>(_marksBoxName);

  final watchingKey = WatchStatus.watching.storageKey;

  final candidates = <String, _Candidate>{};
  for (final key in franchiseBox.keys) {
    final k = key.toString();
    if (!k.startsWith('f:')) continue;

    Map<String, dynamic> data;
    try {
      final raw = franchiseBox.get(k);
      if (raw == null) continue;
      final root = (jsonDecode(raw) as Map).cast<String, dynamic>();
      data = (root['data'] as Map).cast<String, dynamic>();
    } catch (_) {
      continue;
    }
    final franchiseTitle = (data['titleFa'] as String?) ?? '';
    final entries = data['entries'] as List? ?? const [];

    for (final e in entries) {
      try {
        final m = (e as Map).cast<String, dynamic>();
        final id = m['id'] as String?;
        if (id == null || id.isEmpty) continue;
        if (candidates.containsKey(id)) continue;
        if (statusBox.get(id) != watchingKey) continue;
        final title = m['title'] as String?;
        candidates[id] = _Candidate(
          id: id,
          title: (title == null || title.isEmpty) ? franchiseTitle : title,
          anilistId: (m['anilistId'] as num?)?.toInt() ?? 0,
          status: m['status'] as String?,
          episodes: (m['episodes'] as num?)?.toInt() ?? 0,
          nextEpisode: (m['nextEpisode'] as num?)?.toInt(),
          nextAiringAt: (m['nextAiringAt'] as num?)?.toInt(),
        );
      } catch (_) {
        continue;
      }
    }
  }
  if (candidates.isEmpty) return;

  await _refreshFromNetwork(candidates.values.toList());

  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final fresh = <NewEpisodeNotifItem>[];
  final pendingMarks = <String, String>{};

  for (final c in candidates.values) {
    final aired = _airedOf(
      status: c.status,
      episodes: c.episodes,
      nextEpisode: c.nextEpisode,
      nextAiringAt: c.nextAiringAt,
      nowSec: nowSec,
    );
    if (aired == null || aired <= 0) continue;

    final watched = _watchedSet(progressBox.get(c.id));
    final watchedAired = watched.where((n) => n >= 1 && n <= aired).length;
    final unwatched = aired - watchedAired;
    if (unwatched <= 0) continue;

    final lastAired = int.tryParse(marks.get(c.id) ?? '') ?? 0;
    if (aired <= lastAired) continue;

    fresh.add(
      NewEpisodeNotifItem(
        entryId: c.id,
        titleFa: c.title,
        newCount: unwatched,
        latestEpisode: aired,
      ),
    );
    pendingMarks[c.id] = '$aired';
  }

  if (fresh.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(notificationInitSettings());
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android != null) {
    final enabled = await android.areNotificationsEnabled();
    if (enabled == false) return;
  }
  await android?.createNotificationChannel(airingChannel);

  final total = fresh.fold<int>(0, (sum, e) => sum + e.newCount);
  await plugin.show(
    airingNotificationId,
    airingChannelName,
    buildAiringBody(totalNew: total, animeCount: fresh.length),
    buildAiringDetails(fresh),
    payload: notifPayloadCalendar,
  );

  try {
    await marks.putAll(pendingMarks);
  } catch (_) {}
}

Future<void> _refreshFromNetwork(List<_Candidate> candidates) async {
  final targets = candidates
      .where(
        (c) =>
            c.anilistId > 0 &&
            (c.status == null ||
                c.status == 'RELEASING' ||
                c.status == 'HIATUS' ||
                c.status == 'NOT_YET_RELEASED'),
      )
      .take(_maxFreshFetches)
      .toList();
  if (targets.isEmpty) return;

  final client = AniListClient(ApiGateway());
  var failures = 0;
  for (final c in targets) {
    try {
      final media = await client.fetchMedia(c.anilistId);
      c.status = media['status'] as String? ?? c.status;
      final eps = media['episodes'] as int?;
      if (eps != null && eps > 0) c.episodes = eps;
      final next = media['nextAiringEpisode'] as Map?;
      c.nextEpisode = next?['episode'] as int?;
      c.nextAiringAt = next?['airingAt'] as int?;
      failures = 0;
    } catch (_) {
      failures++;
      if (failures >= 2) break;
    }
  }
}

int? _airedOf({
  required String? status,
  required int episodes,
  required int? nextEpisode,
  required int? nextAiringAt,
  required int nowSec,
}) {
  int? result;
  switch (status) {
    case 'NOT_YET_RELEASED':
      result = 0;
    case 'FINISHED':
    case 'CANCELLED':
      result = episodes > 0 ? episodes : null;
    case 'RELEASING':
    case 'HIATUS':
      if (nextEpisode == null) return null;
      result = nextEpisode - 1;
      if (nextAiringAt != null) {
        final nowMs = nowSec * 1000;
        final airMs = nextAiringAt * 1000;
        if (nowMs >= airMs) {
          if (nowMs - airMs > const Duration(days: 7).inMilliseconds) {
            return null;
          }
          result = nextEpisode;
        }
      }
    default:
      return null;
  }
  if (result != null && episodes > 0 && result > episodes) result = episodes;
  return result;
}

Set<int> _watchedSet(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  return raw.split(',').map(int.tryParse).whereType<int>().toSet();
}

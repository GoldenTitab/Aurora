import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_content.dart';

/// نام یکتای تسک دوره‌ای بررسی قسمت‌های جدید (برای register/cancel).
const String airingCheckUniqueName = 'aurora-daily-check';

/// نام تسکی که workmanager به [callbackDispatcher] تحویل می‌دهد.
const String airingCheckTaskName = 'dailyAiringCheck';

/// نقطه ورود ایزولیت پس‌زمینه workmanager.
///
/// حتماً top-level بماند و pragma حفظ شود تا در tree-shaking حذف نشود.
/// این تابع از ایزولیت جدا اجرا می‌شود: به هیچ provider/stateای از اپ
/// دسترسی ندارد و همه‌چیز را مستقیم از Hive می‌خواند.
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

/// ثبت (یا بازثبت) بررسی روزانه در ساعت ترجیحی کاربر.
///
/// چون WorkManager زمان دقیق را تضمین نمی‌کند، [initialDelay] طوری حساب
/// می‌شود که اولین اجرا نزدیک ساعت انتخابی باشد؛ اجراهای بعدی هر ۲۴ ساعت.
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

/// لغو بررسی روزانه (وقتی کاربر اعلان را خاموش می‌کند).
Future<void> cancelDailyAiringCheck() async {
  try {
    await Workmanager().cancelByUniqueName(airingCheckUniqueName);
  } catch (_) {}
}

/// فاصله تا نزدیک‌ترین وقوع بعدی ساعت [hour] (۰ تا ۲۳) در امروز/فردا.
Duration delayUntilNextHour(int hour) {
  final h = hour.clamp(0, 23);
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, h);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next.difference(now);
}

/// منطق بررسی در ایزولیت پس‌زمینه:
/// ۱. Hive را با مسیر documents همین اپ باز می‌کند (بدون Hive.initFlutter).
/// ۲. اگر اعلان خاموش است، بی‌صدا تمام می‌شود.
/// ۳. کش فرنچایزها (`f:*` داخل franchise_cache) را می‌خواند و برای هر entry
///    تعداد قسمت‌های پخش‌شده را با همان منطق [Entry.airedEpisodes] حساب می‌کند.
/// ۴. قسمت‌های دیده‌شده را از episode_progress (رشته CSV) کم می‌کند.
/// ۵. فقط برای entryهایی اعلان می‌دهد که از آخرین اعلان، قسمت تازه‌تری
///    پخش کرده باشند (کلید `notif_aired:<entryId>` داخل app_meta).
/// ۶. پلاگین اعلان را داخل همین ایزولیت init می‌کند و اعلان خلاصه را می‌فرستد.
Future<void> _runAiringCheck() async {
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);

  final meta = await Hive.openBox<String>('app_meta');
  if (!NotificationPrefs.isEnabled(meta)) return;

  final franchiseBox = await Hive.openBox<String>('franchise_cache');
  final progressBox = await Hive.openBox<String>('episode_progress');

  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final fresh = <NewEpisodeNotifItem>[];

  for (final key in franchiseBox.keys) {
    final k = key.toString();
    if (!k.startsWith('f:')) continue;

    Map<String, dynamic>? data;
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
      Map<String, dynamic> m;
      try {
        m = (e as Map).cast<String, dynamic>();
      } catch (_) {
        continue;
      }
      final id = m['id'] as String?;
      if (id == null || id.isEmpty) continue;

      final aired = _airedOf(
        status: m['status'] as String?,
        episodes: (m['episodes'] as num?)?.toInt() ?? 0,
        nextEpisode: (m['nextEpisode'] as num?)?.toInt(),
        nextAiringAt: (m['nextAiringAt'] as num?)?.toInt(),
        nowSec: nowSec,
      );
      if (aired == null || aired <= 0) continue;

      final watched = _watchedSet(progressBox.get(id));
      final watchedAired = watched.where((n) => n >= 1 && n <= aired).length;
      final unwatched = aired - watchedAired;
      if (unwatched <= 0) continue;

      final lastKey = '${NotificationPrefs.lastAiredPrefix}$id';
      final lastAired = int.tryParse(meta.get(lastKey) ?? '') ?? 0;
      if (aired <= lastAired) continue; // قبلاً برای همین قسمت‌ها اعلان رفته

      final title = m['title'] as String?;
      fresh.add(
        NewEpisodeNotifItem(
          entryId: id,
          titleFa: (title == null || title.isEmpty) ? franchiseTitle : title,
          newCount: unwatched,
          latestEpisode: aired,
        ),
      );
      try {
        await meta.put(lastKey, '$aired');
      } catch (_) {}
    }
  }

  if (fresh.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(notificationInitSettings());
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(airingChannel);

  final total = fresh.fold<int>(0, (sum, e) => sum + e.newCount);
  await plugin.show(
    airingNotificationId,
    airingChannelName,
    buildAiringBody(totalNew: total, animeCount: fresh.length),
    buildAiringDetails(fresh),
    payload: notifPayloadCalendar,
  );

  // عمداً Hive.close صدا زده نمی‌شود تا تسک‌های بعدی همین ایزولیت
  // (در صورت reuse توسط workmanager) به مشکل نخورند.
}

/// معادل [Entry.airedEpisodes] برای خواندن مستقیم از JSON کش.
///
/// تفاوت آگاهانه: اگر nextAiringAt بیش از ۷ روز گذشته باشد (کش قدیمی)،
/// null برمی‌گرداند تا اعلان اشتباه برای دیتای کهنه فرستاده نشود.
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
            return null; // کش قدیمی؛ قابل اعتماد نیست
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

/// پارس رشته CSV قسمت‌های دیده‌شده داخل باکس episode_progress.
Set<int> _watchedSet(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  return raw.split(',').map(int.tryParse).whereType<int>().toSet();
}

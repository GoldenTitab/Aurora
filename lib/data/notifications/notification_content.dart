import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';

import '../../core/utils/persian_numbers.dart';

/// شناسه کانال اعلان «قسمت‌های جدید».
const String airingChannelId = 'aurora_airing';

/// نام نمایشی کانال (فارسی).
const String airingChannelName = 'قسمت‌های جدید';

const String airingChannelDescription =
    'اعلان قسمت‌های تازه پخش‌شده انیمه‌های دنبال‌شده';

/// payload اعلان: با تپ روی اعلان، کاربر به تقویم پخش هفتگی می‌رود.
const String notifPayloadCalendar = '/calendar';

/// شناسه ثابت اعلان روزانه تا اعلان جدید جایگزین قبلی شود (انباشته نشود).
const int airingNotificationId = 1001;

/// کانال اندروید «قسمت‌های جدید» (importance بالا).
final AndroidNotificationChannel airingChannel = AndroidNotificationChannel(
  airingChannelId,
  airingChannelName,
  description: airingChannelDescription,
  importance: Importance.high,
);

/// آیتم سبک برای ساخت اعلان؛ هم در ایزولیت اصلی و هم در ایزولیت
/// پس‌زمینه استفاده می‌شود (بدون وابستگی به providerها).
class NewEpisodeNotifItem {
  final String entryId;
  final String titleFa;
  final int newCount;
  final int latestEpisode;

  const NewEpisodeNotifItem({
    required this.entryId,
    required this.titleFa,
    required this.newCount,
    required this.latestEpisode,
  });
}

/// تنظیمات initialize مشترک (بدون درخواست دسترسی؛ دسترسی جدا گرفته می‌شود).
InitializationSettings notificationInitSettings() =>
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

/// متن خلاصه فارسی اعلان، مثلاً: «۳ قسمت جدید از ۲ انیمه».
String buildAiringBody({required int totalNew, required int animeCount}) =>
    '${toFa(totalNew)} قسمت جدید از ${toFa(animeCount)} انیمه';

/// جزئیات اعلان برای اندروید/iOS؛ روی اندروید با BigText لیست
/// حداکثر ۵ عنوان اول نمایش داده می‌شود.
NotificationDetails buildAiringDetails(List<NewEpisodeNotifItem> items) {
  final lines = items
      .take(5)
      .map((e) => '• ${e.titleFa}: ${toFa(e.newCount)} قسمت جدید')
      .join('\n');
  final android = AndroidNotificationDetails(
    airingChannelId,
    airingChannelName,
    channelDescription: airingChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
    ticker: airingChannelName,
    styleInformation: BigTextStyleInformation(
      lines.isEmpty ? airingChannelName : lines,
      contentTitle: airingChannelName,
    ),
  );
  return NotificationDetails(
    android: android,
    iOS: const DarwinNotificationDetails(),
  );
}

/// خواندن/نوشتن تنظیمات اعلان داخل [Boxes.meta] (کلیدها رشته‌ای).
class NotificationPrefs {
  static const String enabledKey = 'notif_enabled';
  static const String hourKey = 'notif_hour';

  /// آخرین تعداد قسمت پخش‌شده‌ای که برایش اعلان رفته، به‌ازای هر entry.
  static const String lastAiredPrefix = 'notif_aired:';

  static const int defaultHour = 20;

  static bool isEnabled(Box<String> meta) => meta.get(enabledKey) == '1';

  static int hour(Box<String> meta) {
    final h = int.tryParse(meta.get(hourKey) ?? '');
    if (h == null || h < 0 || h > 23) return defaultHour;
    return h;
  }

  static Future<void> setEnabled(Box<String> meta, bool value) =>
      meta.put(enabledKey, value ? '1' : '0');

  static Future<void> setHour(Box<String> meta, int hour) =>
      meta.put(hourKey, '$hour');
}

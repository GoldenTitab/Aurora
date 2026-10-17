import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';

import '../../core/i18n/lang.dart';
import '../../core/utils/persian_numbers.dart';

const String airingChannelId = 'aurora_airing';

String get airingChannelName => tr('new_episodes');

String get airingChannelDescription =>
    tr('newly_aired_episodes_from_anime_you_follow');

const String notifPayloadCalendar = '/calendar';

const int airingNotificationId = 1001;

final AndroidNotificationChannel airingChannel = AndroidNotificationChannel(
  airingChannelId,
  airingChannelName,
  description: airingChannelDescription,
  importance: Importance.high,
);

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

InitializationSettings notificationInitSettings() =>
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

String buildAiringBody({required int totalNew, required int animeCount}) =>
    '${toFa(totalNew)} قسمت جدید از ${toFa(animeCount)} انیمه';

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

class NotificationPrefs {
  static const String enabledKey = 'notif_enabled';
  static const String hourKey = 'notif_hour';

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

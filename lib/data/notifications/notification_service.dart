import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/router/app_router.dart';
import 'notification_content.dart';

/// سرویس اعلان‌های محلی اپ (ایزولیت اصلی).
///
/// - [init] را یک بار در [main] صدا بزن.
/// - [requestPermissions] را هنگام روشن کردن سوییچ در تنظیمات صدا بزن.
/// - [showNewEpisodes] اعلان خلاصه فارسی قسمت‌های جدید را نمایش می‌دهد.
/// - با تپ روی اعلان، کاربر به مسیر داخل payload (مثلاً `/calendar`) می‌رود.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      notificationInitSettings(),
      onDidReceiveNotificationResponse: _onTap,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(airingChannel);

    // اگر اپ با تپ روی اعلان (در حالت کاملاً بسته) باز شده، بعد از
    // اولین فریم به مسیر payload برو.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          payload != null &&
          payload.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _goPayload(payload),
        );
      }
    } catch (_) {}
    _initialized = true;
  }

  /// درخواست دسترسی اعلان: اندروید ۱۳+ (POST_NOTIFICATIONS) و iOS.
  /// true یعنی دسترسی داده شد.
  Future<bool> requestPermissions() async {
    var granted = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final a = await android?.requestNotificationsPermission();
      if (a == false) granted = false;
    } catch (_) {}
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final i = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (i == false) granted = false;
    } catch (_) {}
    return granted;
  }

  /// نمایش اعلان خلاصه قسمت‌های جدید.
  Future<void> showNewEpisodes(List<NewEpisodeNotifItem> items) async {
    if (items.isEmpty) return;
    if (!_initialized) {
      try {
        await init();
      } catch (_) {}
    }
    final total = items.fold<int>(0, (sum, e) => sum + e.newCount);
    try {
      await _plugin.show(
        airingNotificationId,
        airingChannelName,
        buildAiringBody(totalNew: total, animeCount: items.length),
        buildAiringDetails(items),
        payload: notifPayloadCalendar,
      );
    } catch (_) {}
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) _goPayload(payload);
  }

  void _goPayload(String payload) {
    try {
      appRouter.go(payload);
    } catch (_) {}
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/i18n/lang.dart';
import 'data/notifications/airing_check_task.dart';
import 'data/notifications/notification_content.dart';
import 'data/notifications/notification_service.dart';
import 'data/storage/economy.dart';
import 'data/storage/migrations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  await Future.wait([
    Hive.openBox<String>(Boxes.watchStatus),
    Hive.openBox<String>(Boxes.episodeProgress),
    Hive.openBox<String>(Boxes.franchiseCache),
    Hive.openBox<String>(Boxes.meta),
    Hive.openBox<String>(Boxes.backup),
    Hive.openBox<String>(Boxes.apiCache),
    Hive.openBox<String>('card_cache'),
    Hive.openBox<String>('discover_cache'),
    Hive.openBox<String>('home_cache'),
  ]);

  await Migrations.run();

  // زبان ذخیره‌شده را قبل از بالا آمدن UI اعمال کن تا tr() از اول درست کار کند.
  try {
    final metaBox = Hive.box<String>(Boxes.meta);
    final lang = metaBox.get('app_lang');
    Lang.current = lang == 'en' ? 'en' : 'fa';
  } catch (_) {}

  // اعلان قسمت‌های جدید + بررسی روزانه پس‌زمینه (workmanager).
  try {
    await NotificationService().init();
    await Workmanager().initialize(callbackDispatcher);
    final metaBox = Hive.box<String>(Boxes.meta);
    if (NotificationPrefs.isEnabled(metaBox)) {
      await scheduleDailyAiringCheck(NotificationPrefs.hour(metaBox));
    }
  } catch (_) {}

  // سر زدن روزانه: +۵ XP و +۲۰ شفق (فقط یک بار در روز)
  try {
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final fresh = await eco.dailyCheckIn();
    if (fresh) {
      await eco.bumpMissionCounter('open_d', Economy.todayStr());
    }
  } catch (_) {}

  runApp(const ProviderScope(child: AuroraApp()));
}

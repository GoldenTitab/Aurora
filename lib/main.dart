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

Future<void> _openBox(String name, {bool disposable = false}) async {
  try {
    await Hive.openBox<String>(name);
  } catch (_) {
    if (disposable) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      await Hive.openBox<String>(name);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await Hive.openBox<String>(name);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    _openBox(Boxes.watchStatus),
    _openBox(Boxes.episodeProgress),
    _openBox(Boxes.franchiseCache, disposable: true),
    _openBox(Boxes.meta),
    _openBox(Boxes.backup),
    _openBox(Boxes.apiCache, disposable: true),
    _openBox('card_cache', disposable: true),
    _openBox('discover_cache', disposable: true),
    _openBox('home_cache', disposable: true),
  ]);

  final migration = await Migrations.run();
  if (!migration.ok) {
    try {
      await Hive.box<String>(Boxes.meta).put(
        'migration_error',
        '${migration.fromVersion}->${migration.toVersion}: ${migration.error}',
      );
    } catch (_) {}
  }

  try {
    final metaBox = Hive.box<String>(Boxes.meta);
    final lang = metaBox.get('app_lang');
    Lang.current = lang == 'en' ? 'en' : 'fa';
  } catch (_) {}

  try {
    await NotificationService().init();
  } catch (_) {}

  try {
    await Workmanager().initialize(callbackDispatcher);
    final metaBox = Hive.box<String>(Boxes.meta);
    if (NotificationPrefs.isEnabled(metaBox)) {
      await scheduleDailyAiringCheck(NotificationPrefs.hour(metaBox));
    }
  } catch (_) {}

  try {
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final fresh = await eco.dailyCheckIn();
    if (fresh) {
      await eco.bumpMissionCounter('open_d', Economy.todayStr());
    }
  } catch (_) {}

  runApp(const ProviderScope(child: AuroraApp()));
}

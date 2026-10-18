import 'dart:io';

import 'package:aurora/data/storage/data_reset.dart';
import 'package:aurora/data/storage/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  const boxNames = [
    Boxes.watchStatus,
    Boxes.episodeProgress,
    Boxes.franchiseCache,
    Boxes.meta,
    Boxes.backup,
    Boxes.apiCache,
    'card_cache',
    'discover_cache',
    'home_cache',
  ];

  Box<String> box(String name) => Hive.box<String>(name);

  Future<void> seedUserData() async {
    await box(Boxes.watchStatus).putAll({'f1': 'watching', 'f2': 'completed'});
    await box(Boxes.episodeProgress).putAll({'e1': '1,2,3'});
    await box(Boxes.backup).put('auto1', '{"x":1}');
    await box(Boxes.franchiseCache).put('f:10', '{"id":10}');
    await box('card_cache').put('cardpool', '{"v":2}');
    final meta = box(Boxes.meta);
    await meta.putAll({
      'coins': '500',
      'xp_total': '1200',
      'streak_count': '7',
      'streak_last': '2026-10-18',
      'last_checkin': '2026-10-18',
      'import_done': '1',
      'note:f1': 'یادداشت',
      'enote:e1:3': 'یادداشت قسمت',
      'uscore:e1': '8',
      'frating:f1': '9',
      'seen:e1': '1,2',
      'ach:first_watch': '1',
      'mission_claimed:d:m1': '1',
      'mx:ep:d': '5',
      'stat:watch_days': '30',
      'manual_entries:f9': '{}',
      'card:123': '2',
      'cardinfo:123': '{"name":"X"}',
      'wo:f1': '["a","b"]',
      'app_lang': 'fa',
      'theme_mode': 'dark',
      'seed_color': '3',
      'spoiler_free': '1',
      'schema_version': '1',
    });
  }

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('aurora_reset_test_');
    Hive.init(dir.path);
    for (final name in boxNames) {
      await Hive.openBox<String>(name);
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('DataReset.resetAll', () {
    test('همه‌ی داده‌ی کاربر پاک می‌شود', () async {
      await seedUserData();
      await DataReset.resetAll();

      expect(box(Boxes.watchStatus).isEmpty, isTrue);
      expect(box(Boxes.episodeProgress).isEmpty, isTrue);
      expect(box(Boxes.backup).isEmpty, isTrue);
      expect(box(Boxes.franchiseCache).isEmpty, isTrue);
      expect(box('card_cache').isEmpty, isTrue);

      final meta = box(Boxes.meta);
      for (final k in [
        'coins',
        'xp_total',
        'streak_count',
        'streak_last',
        'last_checkin',
        'import_done',
        'note:f1',
        'enote:e1:3',
        'uscore:e1',
        'frating:f1',
        'seen:e1',
        'ach:first_watch',
        'mission_claimed:d:m1',
        'mx:ep:d',
        'stat:watch_days',
        'manual_entries:f9',
        'card:123',
        'cardinfo:123',
        'wo:f1',
      ]) {
        expect(meta.containsKey(k), isFalse, reason: k);
      }
    });

    test('تنظیمات اپ حفظ می‌شود', () async {
      await seedUserData();
      await DataReset.resetAll();

      final meta = box(Boxes.meta);
      expect(meta.get('app_lang'), 'fa');
      expect(meta.get('theme_mode'), 'dark');
      expect(meta.get('seed_color'), '3');
      expect(meta.get('spoiler_free'), '1');
      expect(meta.get('schema_version'), '1');
    });

    test('روی دیتای خالی خطا نمی‌دهد', () async {
      await DataReset.resetAll();
      await DataReset.resetAll();
    });
  });
}

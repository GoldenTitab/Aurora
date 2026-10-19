import 'dart:convert';
import 'dart:io';

import 'package:aurora/data/storage/data_export.dart';
import 'package:aurora/data/storage/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// تست‌های بکاپ/بازیابی — بخش دوم انتقاد ۱ (تست نداشتن).
///
/// بخش اول (منطق انتخاب ریشه‌ی فرنچایز) در [franchise_root_test.dart]
/// پوشش داده شد؛ اینجا چرخه‌ی export/import و بکاپ‌های خودکار تست
/// می‌شوند — دقیقاً همان کدی که باگ‌بودنش یعنی از دست رفتن دیتای کاربر.
///
/// روش: باکس‌های Hive روی یک پوشه‌ی موقت دیسک باز می‌شوند تا رفتار
/// واقعی [Migrations.snapshotFull] و [Migrations.restoreFull] (نه فقط
/// serialize) تست شود. [DataExport.importFull] قبل از بازیابی خودش
/// بکاپ خودکار می‌گیرد؛ این رفتار هم پین شده.
///
/// توجه: این تست‌ها بدون SDK اجرا نشده‌اند؛ با `flutter test` اجرا کن.
void main() {
  const boxNames = [
    Boxes.watchStatus,
    Boxes.episodeProgress,
    Boxes.franchiseCache,
    Boxes.meta,
    Boxes.backup,
    Boxes.apiCache,
  ];

  Box<String> box(String name) => Hive.box<String>(name);

  Future<void> clearAll() async {
    for (final name in boxNames) {
      await box(name).clear();
    }
  }

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('aurora_backup_test_');
    Hive.init(dir.path);
    for (final name in boxNames) {
      await Hive.openBox<String>(name);
    }
  });

  setUp(clearAll);

  tearDownAll(() async {
    await Hive.close();
  });

  group('snapshot', () {
    test('وضعیت‌ها و پیشرفت قسمت‌ها را برمی‌دارد', () async {
      await box(Boxes.watchStatus).putAll({'e1': 'watching', 'e2': 'completed'});
      await box(Boxes.episodeProgress).putAll({'e1': '1,5,12'});

      final snap = Migrations.snapshot();

      expect((snap['watch_status'] as Map)['e1'], 'watching');
      expect((snap['watch_status'] as Map)['e2'], 'completed');
      expect((snap['episode_progress'] as Map)['e1'], '1,5,12');
    });

    test('snapshotFull ورودی‌های فرنچایز (f:) را از aliasها (a:) جدا می‌کند',
        () async {
      await box(Boxes.franchiseCache).putAll({
        'f:10': jsonEncode({'data': {'id': 10}}),
        'a:al-21': 'f:10',
        'stray': 'x',
      });
      await box(Boxes.meta).putAll({'app_lang': 'fa'});

      final snap = Migrations.snapshotFull();

      final franchises = snap['franchises'] as Map;
      final aliases = snap['aliases'] as Map;
      final extras = snap['meta_extras'] as Map;

      expect(franchises.keys, contains('f:10'));
      expect(franchises.keys, isNot(contains('a:al-21')));
      expect(aliases['a:al-21'], 'f:10');
      expect(franchises.keys, isNot(contains('stray')));
      expect(aliases.keys, isNot(contains('stray')));
      expect(extras['app_lang'], 'fa');
    });
  });

  group('export/import round-trip', () {
    test('buildFull خروجی JSON معتبر با هدر aurora می‌سازد', () async {
      await box(Boxes.watchStatus).putAll({'e1': 'watching'});

      final raw = DataExport.buildFull();
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();

      expect(m['app'], 'aurora');
      expect(m['format'], DataExport.format);
      expect(m['schemaVersion'], isA<int>());
      expect((m['watch_status'] as Map)['e1'], 'watching');
    });

    test('export → clear → import همه‌چیز را برمی‌گرداند', () async {
      await box(Boxes.watchStatus).putAll({'e1': 'watching'});
      await box(Boxes.episodeProgress).putAll({'e1': '3'});
      await box(Boxes.meta).putAll({'note:f1': 'یادداشت'});
      await box(Boxes.franchiseCache).putAll({
        'f:10': jsonEncode({'data': {'id': 10}, 'ts': 0}),
        'a:al-21': 'f:10',
      });

      final raw = DataExport.buildFull();
      await clearAll();

      final result = await DataExport.importFull(raw);

      expect(result.ok, isTrue);
      expect(box(Boxes.watchStatus).get('e1'), 'watching');
      expect(box(Boxes.episodeProgress).get('e1'), '3');
      expect(box(Boxes.meta).get('note:f1'), 'یادداشت');
      expect(box(Boxes.franchiseCache).get('f:10'), isNotNull);
      expect(box(Boxes.franchiseCache).get('a:al-21'), 'f:10');
    });

    test('قبل از بازیابی، از وضعیت فعلی بکاپ خودکار گرفته می‌شود', () async {
      await box(Boxes.watchStatus).putAll({'old': 'watching'});
      await box(Boxes.episodeProgress).putAll({'e9': '1'});
      final exported = DataExport.buildFull(); // وضعیت S1
      final before = Migrations.backupCount();

      // وضعیت فعلی را به S2 عوض کن، بعد S1 را import کن
      await box(Boxes.watchStatus).put('new', 'dropped');
      final result = await DataExport.importFull(exported);

      expect(result.ok, isTrue);
      expect(Migrations.backupCount(), before + 1);
      final latest = Migrations.latestBackup()!;
      // بکاپ، وضعیتِ قبل از بازیابی (S2) را دارد — همان که داشت رونویسی می‌شد
      expect((latest['watch_status'] as Map)['new'], 'dropped');
      // و وضعیت فعلی، S1 بازیابی‌شده است
      expect(box(Boxes.watchStatus).get('old'), 'watching');
      expect(box(Boxes.watchStatus).get('new'), isNull);
    });
  });

  group('importFull validation', () {
    test('رشته‌ی خراب رد می‌شود', () async {
      final r = await DataExport.importFull('this is not json');
      expect(r.ok, isFalse);
    });

    test('فایل غیر-aurora رد می‌شود', () async {
      final r = await DataExport.importFull(jsonEncode({'app': 'other'}));
      expect(r.ok, isFalse);
    });

    test('ورودی فرنچایز خراب نادیده گرفته می‌شود ولی معتبرها می‌مانند',
        () async {
      await box(Boxes.watchStatus).putAll({'e1': 'watching'});
      final export =
          (jsonDecode(DataExport.buildFull()) as Map).cast<String, dynamic>();
      export['franchises'] = {
        'f:bad': 'garbage{{{',
        'f:nodata': jsonEncode({'nope': 1}),
        'f:ok': jsonEncode({'data': {'id': 7}}),
      };
      export['aliases'] = {'a:al-7': 'f:ok'};

      final r = await DataExport.importFull(jsonEncode(export));

      expect(r.ok, isTrue);
      expect(box(Boxes.watchStatus).get('e1'), 'watching');
      expect(box(Boxes.franchiseCache).get('f:bad'), isNull);
      expect(box(Boxes.franchiseCache).get('f:nodata'), isNull);
      expect(box(Boxes.franchiseCache).get('f:ok'), isNotNull);
      expect(box(Boxes.franchiseCache).get('a:al-7'), 'f:ok');
    });
  });

  group('auto-backups', () {
    test('restoreLatestBackup وضعیتِ قبل از آخرین import را برمی‌گرداند',
        () async {
      // D1
      await box(Boxes.watchStatus).put('e1', 'watching');
      final rawD1 = DataExport.buildFull();

      // D2
      await box(Boxes.watchStatus).clear();
      await box(Boxes.watchStatus).put('e1', 'dropped');

      // importِ D1 → بکاپ خودکار از D2 می‌گیرد، وضعیت فعلی D1 می‌شود
      await DataExport.importFull(rawD1);
      expect(box(Boxes.watchStatus).get('e1'), 'watching');

      // بازیابی از بکاپ → D2 برمی‌گردد
      final ok = await Migrations.restoreLatestBackup();

      expect(ok, isTrue);
      expect(box(Boxes.watchStatus).get('e1'), 'dropped');
    });

    test('بیش از ۳ بکاپ خودکار نگه داشته نمی‌شود', () async {
      for (var i = 0; i < 5; i++) {
        await box(Boxes.watchStatus).put('k', 'v$i');
        final raw = DataExport.buildFull();
        await DataExport.importFull(raw);
        // کلید بکاپ از میلی‌ثانیه ساخته می‌شود؛ فاصله تا کلیدها یکتا بمانند
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(Migrations.backupCount(), 3);
    });
  });
}

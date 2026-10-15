import 'dart:convert';

import 'migrations.dart';

/// نتیجه تلاش برای بازیابی از JSON.
class ImportResult {
  final bool ok;
  final String message;
  const ImportResult(this.ok, this.message);
}

class DataExport {
  static const int format = 2;

  /// خروجی قدیمی (فقط وضعیت‌ها) — برای سازگاری نگه داشته شده.
  static String build() {
    final snap = Migrations.snapshot();
    final map = {
      'app': 'aurora',
      'format': 1,
      'schemaVersion': Migrations.readVersion(),
      'exportedAt': DateTime.now().toIso8601String(),
      'watch_status': snap['watch_status'],
      'episode_progress': snap['episode_progress'],
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// خروجی کامل: وضعیت تماشا، قسمت‌ها، یادداشت‌ها، امتیازها، ترتیب شخصی،
  /// تنظیمات تم، و کل کش فرنچایزها (با شناسه‌های MAL/AniList و روابط).
  /// برای پشتیبان‌گیری و انتقال بین دستگاه‌ها.
  static String buildFull() {
    final snap = Migrations.snapshotFull();
    final map = <String, dynamic>{
      'app': 'aurora',
      'format': format,
      'schemaVersion': Migrations.readVersion(),
      'exportedAt': DateTime.now().toIso8601String(),
      ...snap,
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// بازیابی از خروجی کامل (یا خروجی قدیمی format=1).
  static Future<ImportResult> importFull(String raw) async {
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (m['app'] != 'aurora') {
        return const ImportResult(false, 'این فایل، خروجی Aurora نیست.');
      }
      final ok = await Migrations.restoreFull(m);
      return ok
          ? const ImportResult(true, 'بازیابی با موفقیت انجام شد.')
          : const ImportResult(false, 'بازیابی ناموفق بود؛ دیتای فعلی دست‌نخورده ماند.');
    } on FormatException catch (e) {
      return ImportResult(false, 'فایل خراب است: ${e.message}');
    } catch (e) {
      return ImportResult(false, 'خطا در بازیابی: $e');
    }
  }
}

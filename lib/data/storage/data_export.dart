import 'dart:convert';

import 'migrations.dart';
import '../../core/i18n/lang.dart';

/// نتیجه تلاش برای بازیابی از JSON.
class ImportResult {
  final bool ok;
  final String message;
  const ImportResult(this.ok, this.message);
}

class DataExport {
  static const int format = 2;

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
        return  ImportResult(false, tr('this_file_is_not_an_aurora_export'));
      }
      final ok = await Migrations.restoreFull(m);
      return ok
          ?  ImportResult(true, tr('restore_completed_successfully'))
          :  ImportResult(false, tr('restore_failed_your_current_data_was_left_untouc'));
    } on FormatException catch (e) {
      return ImportResult(false, tr('file_is_corrupted', [e.message]));
    } catch (e) {
      return ImportResult(false, tr('restore_error', [e]));
    }
  }
}

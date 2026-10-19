import 'package:hive/hive.dart';

import 'migrations.dart';

/// حذف کامل داده‌های کاربر (Feature A) — فقط با تأیید صریح کاربر.
///
/// چه چیزی پاک می‌شود:
/// * کل باکس‌های [Boxes.watchStatus] و [Boxes.episodeProgress] (لیست تماشا و پیشرفت قسمت‌ها)
/// * کل باکس [Boxes.backup] (بکاپ‌های خودکار — تا داده‌ی پاک‌شده برنگردد)
/// * کش‌های مشتق‌شده: franchise_cache، api_cache، card_cache، discover_cache، home_cache
/// * کلیدهای کاربری داخل [Boxes.meta]: نمره‌ها، یادداشت‌ها، کارت‌ها (card:/cardinfo:)،
///   سکه، XP، استریک، اچیومنت‌ها، مأموریت‌ها، آمار، ورودی‌های دستی، ترتیب دستی
///
/// چه چیزی حفظ می‌شود (تنظیمات اپ، نه داده‌ی کاربر):
/// * زبان، تم، رنگ، حالت ضداسپویل، نسخه‌ی اسکیما و هر کلید ناشناخته‌ی دیگر
///
/// نکته‌ی مهم: این عملیات هرگز خودکار اجرا نمی‌شود — نه در استارت‌اپ،
/// نه در مهاجرت اسکیما، نه در آپدیت. فقط از دکمه‌ی تنظیمات با دیالوگ تأیید.
class DataReset {
  /// پیشوندهای کلید کاربری داخل باکس meta که باید حذف شوند.
  static const List<String> _metaUserPrefixes = [
    'note:', // یادداشت فرنچایز
    'enote:', // یادداشت قسمت
    'uscore:', // نمره‌ی ورودی
    'frating:', // نمره‌ی فرنچایز
    'seen:', // قسمت‌های دیده‌شده
    'ach:', // اچیومنت‌های بازشده
    'mission_claimed:', // مأموریت‌های claimشده
    'mx:', // شمارنده‌های مأموریت
    'stat:', // آمار
    'manual_entries:', // انیمه‌های دستی اضافه‌شده
    'card:', // کارت‌های کالکشن
    'cardinfo:', // اطلاعات کارت‌ها
    'wo:', // ترتیب دستی تماشا
    'dismissed_new_ep', // قسمت‌های نادیده‌گرفته‌شده در بنر
  ];

  /// کلیدهای تکی کاربری داخل باکس meta که باید حذف شوند.
  static const List<String> _metaUserKeys = [
    'coins', // سکه‌ی شفق
    'xp_total', // XP کل
    'streak_count', // استریک
    'streak_last',
    'last_checkin', // آخرین سر زدن روزانه
    'import_done', // پرچم ایمپورت انجام‌شده
  ];

  /// باکس‌هایی که کامل خالی می‌شوند.
  static const List<String> _wipeBoxes = [
    Boxes.watchStatus,
    Boxes.episodeProgress,
    Boxes.backup,
    Boxes.franchiseCache,
    Boxes.apiCache,
    'card_cache',
    'discover_cache',
    'home_cache',
  ];

  /// اجرای ریست. در صورت شکست در یک بخش، ادامه می‌دهد تا حداکثر
  /// پاک‌سازی انجام شود؛ خطاها جمع و در انتها پرتاب می‌شوند.
  static Future<void> resetAll() async {
    final errors = <String>[];

    for (final name in _wipeBoxes) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box<String>(name).clear();
        }
      } catch (e) {
        errors.add('$name: $e');
      }
    }

    try {
      final meta = Hive.box<String>(Boxes.meta);
      final toDelete = <String>[];
      for (final k in meta.keys.map((e) => e.toString())) {
        if (_metaUserKeys.contains(k) ||
            _metaUserPrefixes.any((p) => k.startsWith(p))) {
          toDelete.add(k);
        }
      }
      for (final k in toDelete) {
        try {
          await meta.delete(k);
        } catch (e) {
          errors.add('$k: $e');
        }
      }
    } catch (e) {
      errors.add('${Boxes.meta}: $e');
    }

    if (errors.isNotEmpty) {
      throw StateError('reset_incomplete: ${errors.join('; ')}');
    }
  }
}

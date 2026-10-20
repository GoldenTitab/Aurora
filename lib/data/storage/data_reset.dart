import 'package:hive/hive.dart';

import 'migrations.dart';

class DataReset {
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
    'heat:', // نقشه‌ی روزهای تماشا (Economy.bumpHeatDay)
    'xpep:', // قسمت‌هایی که XPشان داده شده؛ اگه بماند بعد از ریست دیگر XP قسمت تعلق نمی‌گیرد
    'frdone:', // پرچم تکمیل فرنچایز؛ اگه بماند بونوس ۱۰۰ XP تکمیل دیگر داده نمی‌شود
    'manual_pos:', // جایگاه دلخواه ورودی‌های دستی
    'manual_note:', // یادداشت ورودی‌های دستی
    'sh:', // تاریخچه‌ی پیشنهادها و شمارنده‌ی ژانرها (WatchOrderStorage)
    'notif_aired:', // آخرین قسمت اطلاع‌رسانی‌شده‌ی هر انیمه
  ];

  static const List<String> _metaUserKeys = [
    'coins', // سکه‌ی شفق
    'xp_total', // XP کل
    'xp_log', // تاریخچه‌ی رویدادهای XP
    'streak_count', // استریک
    'streak_max', // بیشترین استریک
    'streak_last',
    'last_checkin', // آخرین سر زدن روزانه
    'import_done', // پرچم ایمپورت انجام‌شده
    'import_last', // زمان آخرین ایمپورت
    'search_history', // تاریخچه‌ی جست‌وجوهای کاربر
    'suggestion_cards', // کش کارت‌های پیشنهادشده
    'last_suggestion', // آخرین پیشنهاد
    'card_recent', // کارت‌های اخیراً گرفته‌شده
    'first_launch', // تاریخ اولین اجرا (نمایش «عضویت از» در پروفایل)
  ];

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

import 'package:aurora/data/repository/franchise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// تست‌های منطق انتخاب ریشه‌ی فرنچایز.
///
/// این منطق قبلاً inline داخل `_build` بود و حالا در
/// [FranchiseRepository.pickRootId] متمرکز و تست‌پذیر است (بدون هیچ تغییری
/// در رفتار).
///
/// یادآوری درباره‌ی باگ One Piece/DBZ: ریشه‌دزدی DBZ به‌خاطر رابطه‌ی
/// CHARACTER بود که آیتم نامرتبط را وارد گراف می‌کرد؛ آن باگ با حذف
/// CHARACTER از رابطه‌های مجاز حل شده و اینجا فقط semantics موجود
/// (قدیمی‌ترین main-format) پین می‌شود.
///
/// توجه: این تست‌ها بدون SDK اجرا نشده‌اند؛ با `flutter test` اجرا کن.
void main() {
  Map<String, dynamic> media(
    int id,
    String format, {
    int? year,
    int? month,
    int? day,
  }) {
    return {
      'id': id,
      'format': format,
      'startDate': {'year': year, 'month': month, 'day': day},
    };
  }

  const mainFormats = {'TV', 'TV_SHORT', 'MOVIE', 'ONA'};

  group('pickRootId', () {
    test('One Piece: قدیمی‌ترین main-format (خود سریال) ریشه می‌شود', () {
      // سناریوی واقعی بعد از حذف CHARACTER: DBZ اصلاً وارد آیتم‌ها
      // نمی‌شود؛ بین One Piece (۱۹۹۹) و MONSTERS (۲۰۲۴) قدیمی‌ترین
      // main-format یعنی خود One Piece ریشه است.
      final mediaById = {
        21: media(21, 'TV', year: 1999, month: 10, day: 20),
        208: media(208, 'ONA', year: 2024, month: 1, day: 1),
      };
      expect(FranchiseRepository.pickRootId(mediaById, mainFormats, 21), 21);
    });

    test('تپ روی فیلم فرنچایز: ریشه همان سریال (قدیمی‌ترین main-format) می‌ماند', () {
      // کاربر روی فیلم تپ می‌زند ولی صفحه‌ی فرنچایز باید با ریشه‌ی
      // سریال باز شود، نه فیلم.
      final mediaById = {
        500: media(500, 'MOVIE', year: 2022, month: 8, day: 6),
        21: media(21, 'TV', year: 1999, month: 10, day: 20),
      };
      expect(FranchiseRepository.pickRootId(mediaById, mainFormats, 500), 21);
    });

    test('قدیمی‌ترین main-format برنده می‌شود', () {
      final mediaById = {
        10: media(10, 'MOVIE', year: 2010),
        20: media(20, 'TV', year: 2005),
        30: media(30, 'MUSIC', year: 2000),
      };
      expect(FranchiseRepository.pickRootId(mediaById, mainFormats, 999), 20);
    });

    test('آیتم درخواستی نامعتبر (خارج از مپ) مشکلی ایجاد نمی‌کند', () {
      final mediaById = {
        10: media(10, 'MOVIE', year: 2010),
        20: media(20, 'TV', year: 2005),
      };
      expect(FranchiseRepository.pickRootId(mediaById, mainFormats, 999), 20);
    });

    test('وقتی هیچ main-format نیست، به آیتم درخواستی برمی‌گردد', () {
      final mediaById = {
        30: media(30, 'MUSIC', year: 2020),
        40: media(40, 'OVA', year: 2019),
      };
      expect(FranchiseRepository.pickRootId(mediaById, mainFormats, 40), 40);
    });

    test('وقتی هیچ main-format نیست و آیتم درخواستی هم نیست، اولین آیتم', () {
      final mediaById = {
        30: media(30, 'MUSIC', year: 2020),
        40: media(40, 'OVA', year: 2019),
      };
      expect(FranchiseRepository.pickRootId(mediaById, mainFormats, 999), 30);
    });
  });

  group('mapExternalRelation', () {
    test('CHARACTER باید null بدهد (قاطی نکردن فرنچایزها)', () {
      expect(FranchiseRepository.mapExternalRelation('CHARACTER'), isNull);
      expect(FranchiseRepository.mapExternalRelation('character'), isNull);
      expect(FranchiseRepository.mapExternalRelation(' Character '), isNull);
    });

    test('رابطه‌های شناخته‌شده درست نگاشت می‌شوند', () {
      expect(FranchiseRepository.mapExternalRelation('Sequel'), 'SEQUEL');
      expect(FranchiseRepository.mapExternalRelation('prequel'), 'PREQUEL');
      expect(
        FranchiseRepository.mapExternalRelation('parent_story'),
        'PARENT',
      );
      expect(
        FranchiseRepository.mapExternalRelation('side_story'),
        'SIDE_STORY',
      );
      expect(FranchiseRepository.mapExternalRelation('spin-off'), 'SPIN_OFF');
      expect(FranchiseRepository.mapExternalRelation('other'), 'OTHER');
      expect(
        FranchiseRepository.mapExternalRelation('alternative_version'),
        'ALTERNATIVE',
      );
    });

    test('manga/novel/adaptation باید null بدهند', () {
      expect(FranchiseRepository.mapExternalRelation('manga'), isNull);
      expect(FranchiseRepository.mapExternalRelation('novel'), isNull);
      expect(FranchiseRepository.mapExternalRelation('adaptation'), isNull);
    });

    test('رابطه‌ی ناشناخته باید null بدهد (حدس نزن)', () {
      expect(FranchiseRepository.mapExternalRelation('whatever'), isNull);
      expect(FranchiseRepository.mapExternalRelation(''), isNull);
    });
  });

  group('dateKey', () {
    test('تاریخ کامل', () {
      expect(
        FranchiseRepository.dateKey({
          'startDate': {'year': 1999, 'month': 10, 'day': 20},
        }),
        19991020,
      );
    });

    test('فقط سال: ماه و روز پیش‌فرض ۱', () {
      expect(
        FranchiseRepository.dateKey({
          'startDate': {'year': 2005},
        }),
        20050101,
      );
    });

    test('بدون تاریخ: آخر مرتب‌سازی', () {
      expect(FranchiseRepository.dateKey({}), 99999999);
      expect(FranchiseRepository.dateKey({'startDate': {}}), 99999999);
      expect(
        FranchiseRepository.dateKey({
          'startDate': {'year': null},
        }),
        99999999,
      );
    });
  });
}

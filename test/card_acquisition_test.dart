import 'dart:math';

import 'package:aurora/data/gamification/card_pool.dart';
import 'package:aurora/data/models/collectible_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// تست‌های قطعی سیستم کارت محبوبیتی (تصمیم علی 2026-10-18).
///
/// درجه‌ی ذاتی از محبوبیت (favourites):
/// عادی < ۶٬۰۰۰ | کمیاب ۶٬۰۰۰–۱۲٬۰۰۰ | فوق‌کمیاب ۱۲٬۰۰۰–۲۰٬۰۰۰ |
/// حماسی ۲۰٬۰۰۰–۳۰٬۰۰۰ | افسانه‌ای ۳۰٬۰۰۰+ |
/// وایفو: مؤنث ۳۰٬۰۰۰+ | هازبندو: مذکر ۳۰٬۰۰۰+
///
/// تاس با وزن‌های علی (از ۱۰۰۰۰): عادی 4900، کمیاب 2646، فوق‌کمیاب 1470،
/// حماسی 588، افسانه‌ای 196، وایفو 100، هازبندو 100.
void main() {
  group('weights (dice)', () {
    test('مجموع وزن‌ها دقیقاً 10000 است', () {
      final total = CardRarity.values.fold<int>(0, (a, r) => a + r.weight);
      expect(total, CardRarityX.totalWeight);
      expect(total, 10000);
    });

    test('درصدها با تصمیم علی می‌خوانند', () {
      expect(CardRarity.common.percent, 49.0);
      expect(CardRarity.rare.percent, 26.46);
      expect(CardRarity.superRare.percent, 14.7);
      expect(CardRarity.epic.percent, 5.88);
      expect(CardRarity.legendary.percent, 1.96);
      expect(CardRarity.waifu.percent, 1.0);
      expect(CardRarity.husbando.percent, 1.0);
    });
  });

  group('rollOutcome boundaries', () {
    // بازه‌ها: [0,4900) عادی، [4900,7546) کمیاب، [7546,9016) فوق‌کمیاب،
    // [9016,9604) حماسی، [9604,9800) افسانه‌ای، [9800,9900) وایفو، [9900,10000) هازبندو
    final edges = <int, CardRarity>{
      0: CardRarity.common,
      4899: CardRarity.common,
      4900: CardRarity.rare,
      7545: CardRarity.rare,
      7546: CardRarity.superRare,
      9015: CardRarity.superRare,
      9016: CardRarity.epic,
      9603: CardRarity.epic,
      9604: CardRarity.legendary,
      9799: CardRarity.legendary,
      9800: CardRarity.waifu,
      9899: CardRarity.waifu,
      9900: CardRarity.husbando,
      9999: CardRarity.husbando,
    };
    for (final e in edges.entries) {
      test('roll ${e.key} -> ${e.value.name}', () {
        expect(CardRarityX.rollOutcome(e.key), e.value);
      });
    }

    test('همه‌ی 10000 مقدار دقیقاً یک خروجی دارند', () {
      final counts = <CardRarity, int>{};
      for (var i = 0; i < 10000; i++) {
        final r = CardRarityX.rollOutcome(i);
        counts[r] = (counts[r] ?? 0) + 1;
      }
      for (final r in CardRarity.values) {
        expect(counts[r], r.weight, reason: r.name);
      }
    });
  });

  group('rarityFor (intrinsic, favourites)', () {
    test('مثال‌های علی: ۵٬۰۰۰ → عادی، ۳۰٬۰۰۰ → افسانه‌ای', () {
      expect(CardPool.rarityFor(5000, null), CardRarity.common);
      expect(CardPool.rarityFor(30000, null), CardRarity.legendary);
    });

    test('مرزهای آستانه', () {
      expect(CardPool.rarityFor(0, null), CardRarity.common);
      expect(CardPool.rarityFor(5999, null), CardRarity.common);
      expect(CardPool.rarityFor(6000, null), CardRarity.rare);
      expect(CardPool.rarityFor(11999, null), CardRarity.rare);
      expect(CardPool.rarityFor(12000, null), CardRarity.superRare);
      expect(CardPool.rarityFor(19999, null), CardRarity.superRare);
      expect(CardPool.rarityFor(20000, null), CardRarity.epic);
      expect(CardPool.rarityFor(29999, null), CardRarity.epic);
      expect(CardPool.rarityFor(30000, null), CardRarity.legendary);
      expect(CardPool.rarityFor(250000, null), CardRarity.legendary);
    });

    test('وایفو/هازبندو: جنسیت + سقف محبوبیت', () {
      expect(CardPool.rarityFor(30000, 'Female'), CardRarity.waifu);
      expect(CardPool.rarityFor(30000, 'female'), CardRarity.waifu);
      expect(CardPool.rarityFor(99999, 'Male'), CardRarity.husbando);
      expect(CardPool.rarityFor(30000, 'male'), CardRarity.husbando);
      // جنسیت نامشخص در سقف → افسانه‌ای
      expect(CardPool.rarityFor(30000, ''), CardRarity.legendary);
      expect(CardPool.rarityFor(30000, null), CardRarity.legendary);
      // زیر سقف، جنسیت تأثیری ندارد
      expect(CardPool.rarityFor(29999, 'Female'), CardRarity.epic);
      expect(CardPool.rarityFor(5000, 'Male'), CardRarity.common);
    });
  });

  group('fromKey legacy mapping', () {
    test('uncommon قدیم (کمیاب) به rare جدید نگاشت می‌شود', () {
      expect(CardRarityX.fromKey('uncommon'), CardRarity.rare);
    });
    test('کلیدهای جدید درست خوانده می‌شوند', () {
      expect(CardRarityX.fromKey('superRare'), CardRarity.superRare);
      expect(CardRarityX.fromKey('waifu'), CardRarity.waifu);
      expect(CardRarityX.fromKey('husbando'), CardRarity.husbando);
      expect(CardRarityX.fromKey('common'), CardRarity.common);
    });
    test('کلید ناشناخته به common می‌افتد', () {
      expect(CardRarityX.fromKey('nope'), CardRarity.common);
    });
  });

  group('pickForOutcome (intrinsic match)', () {
    List<Map<String, dynamic>> pool() => [
      {'id': 1, 'name': 'A', 'favourites': 500, 'gender': 'Female'},
      {'id': 2, 'name': 'B', 'favourites': 8000, 'gender': 'Male'},
      {'id': 3, 'name': 'C', 'favourites': 15000, 'gender': ''},
      {'id': 4, 'name': 'D', 'favourites': 25000, 'gender': 'Female'},
      {'id': 5, 'name': 'E', 'favourites': 40000, 'gender': 'Female'},
      {'id': 6, 'name': 'F', 'favourites': 50000, 'gender': 'Male'},
    ];

    test('هر خروجی فقط شخصیت هم‌درجه‌ی خودش را برمی‌دارد', () {
      final rnd = Random(42);
      final expected = {
        CardRarity.common: {1},
        CardRarity.rare: {2},
        CardRarity.superRare: {3},
        CardRarity.epic: {4},
        CardRarity.legendary: <int>{},
        CardRarity.waifu: {5},
        CardRarity.husbando: {6},
      };
      for (final entry in expected.entries) {
        for (var i = 0; i < 10; i++) {
          final p = CardPool.pickForOutcome(
            pool(),
            entry.key,
            rnd,
            const {},
          );
          if (entry.value.isEmpty) {
            expect(p, isNull, reason: entry.key.name);
          } else {
            expect(
              entry.value.contains(p!['id'] as int),
              isTrue,
              reason: entry.key.name,
            );
          }
        }
      }
    });

    test('شناسه‌های exclude نادیده گرفته می‌شوند', () {
      final p = CardPool.pickForOutcome(
        pool(),
        CardRarity.common,
        Random(1),
        {1},
      );
      expect(p, isNull);
    });

    test('outcomeی null یعنی هر درجه‌ای (آخرین راه‌حل)', () {
      final p = CardPool.pickForOutcome(pool(), null, Random(3), const {});
      expect(p, isNotNull);
    });

    test('استخر خالی null می‌دهد', () {
      expect(
        CardPool.pickForOutcome([], CardRarity.common, Random(1), const {}),
        isNull,
      );
    });
  });
}

import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';

/// درجه‌های کارت — تصمیم نهایی علی (2026-10-18).
///
/// پنج درجه + دو دسته‌ی ویژه‌ی هم‌سطح (وایفو/هازبندو). درجه‌ی هر شخصیت
/// از روی محبوبیتش در AniList (favourites) تعیین می‌شود — هرچه معروف‌تر،
/// درجه بالاتر و شانس دریافت کمتر:
///
/// عادی < ۶٬۰۰۰ | کمیاب ۶٬۰۰۰–۱۲٬۰۰۰ | فوق‌کمیاب ۱۲٬۰۰۰–۲۰٬۰۰۰ |
/// حماسی ۲۰٬۰۰۰–۳۰٬۰۰۰ | افسانه‌ای ۳۰٬۰۰۰+ |
/// وایفو: مؤنث با ۳۰٬۰۰۰+ | هازبندو: مذکر با ۳۰٬۰۰۰+
///
/// تاس، خروجی را با وزن‌های زیر (از ۱۰۰۰۰) انتخاب می‌کند و شخصیت از میان
/// واجدین همان درجه برداشته می‌شود:
/// عادی 4900 (49٪)، کمیاب 2646 (26.46٪)، فوق‌کمیاب 1470 (14.7٪)،
/// حماسی 588 (5.88٪)، افسانه‌ای 196 (1.96٪)، وایفو 100 (1٪)، هازبندو 100 (1٪).
enum CardRarity { common, rare, superRare, epic, legendary, waifu, husbando }

extension CardRarityX on CardRarity {
  /// مجموع وزن‌ها — مخرج توزیع احتمال.
  static const int totalWeight = 10000;

  String get labelFa {
    switch (this) {
      case CardRarity.common:
        return tr('common');
      case CardRarity.rare:
        return tr('rare');
      case CardRarity.superRare:
        return tr('super_rare');
      case CardRarity.epic:
        return tr('epic');
      case CardRarity.legendary:
        return tr('legendary');
      case CardRarity.waifu:
        return tr('waifu');
      case CardRarity.husbando:
        return tr('husbando');
    }
  }

  int get weight {
    switch (this) {
      case CardRarity.common:
        return 4900;
      case CardRarity.rare:
        return 2646;
      case CardRarity.superRare:
        return 1470;
      case CardRarity.epic:
        return 588;
      case CardRarity.legendary:
        return 196;
      case CardRarity.waifu:
        return 100;
      case CardRarity.husbando:
        return 100;
    }
  }

  /// درصد نمایشی (مثلاً 26.46 برای وزن 2646).
  double get percent => weight / 100.0;

  int get duplicateCoins {
    switch (this) {
      case CardRarity.common:
        return 5;
      case CardRarity.rare:
        return 10;
      case CardRarity.superRare:
        return 20;
      case CardRarity.epic:
        return 40;
      case CardRarity.legendary:
        return 80;
      case CardRarity.waifu:
        return 150;
      case CardRarity.husbando:
        return 150;
    }
  }

  Color get color {
    switch (this) {
      case CardRarity.common:
        return const Color(0xFF9CA3AF);
      case CardRarity.rare:
        return const Color(0xFF38BDF8);
      case CardRarity.superRare:
        return const Color(0xFFA78BFA);
      case CardRarity.epic:
        return const Color(0xFFF59E0B);
      case CardRarity.legendary:
        return const Color(0xFFF43F5E);
      case CardRarity.waifu:
        return const Color(0xFFF472B6);
      case CardRarity.husbando:
        return const Color(0xFF60A5FA);
    }
  }

  /// نگاشت قطعی عدد تاس در [0, totalWeight) به خروجی — خالص و تست‌پذیر.
  /// بازه‌ها تجمعی و بدون هم‌پوشانی‌اند:
  /// [0,4900) عادی، [4900,7546) کمیاب، [7546,9016) فوق‌کمیاب،
  /// [9016,9604) حماسی، [9604,9800) افسانه‌ای، [9800,9900) وایفو،
  /// [9900,10000) هازبندو.
  static CardRarity rollOutcome(int roll) {
    var acc = 0;
    for (final r in CardRarity.values) {
      acc += r.weight;
      if (roll < acc) return r;
    }
    return CardRarity.common; // برای roll خارج از بازه؛ در عمل رخ نمی‌دهد
  }

  /// خواندن درجه از روی کلید ذخیره‌شده.
  ///
  /// نگاشت شناسه‌های قدیمی (سیستم قبلی با ۷ درجه‌ی محبوبیتی):
  /// 'uncommon' (کمیابِ قدیم) → rare (کمیابِ جدید)، چون نام نمایشی یکی است.
  /// توجه: 'rare' قدیم یعنی فوق‌کمیاب بود؛ کارت‌های قدیمیِ 'rare' با
  /// مهاجرت یک‌باره‌ی [CardPool.migrateLegacyRarities] به 'superRare'
  /// تبدیل می‌شوند تا با 'rare' جدید (کمیاب) قاطی نشوند.
  static CardRarity fromKey(String key) {
    if (key == 'uncommon') return CardRarity.rare;
    for (final r in CardRarity.values) {
      if (r.name == key) return r;
    }
    return CardRarity.common;
  }
}

class CollectibleCard {
  final int charId;
  final String name;
  final String? image;
  final CardRarity rarity;
  final int count;

  const CollectibleCard({
    required this.charId,
    required this.name,
    this.image,
    required this.rarity,
    this.count = 0,
  });

  bool get owned => count > 0;
}

class PackResult {
  final List<CollectibleCard> cards;

  final List<bool> duplicates;
  final int coinsFromDuplicates;

  const PackResult({
    required this.cards,
    required this.duplicates,
    required this.coinsFromDuplicates,
  });
}

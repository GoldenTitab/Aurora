import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';

/// کمیابی کارت‌ها با وزن شانس و جایزه تکراری.
///
/// درجه هر کارت از روی محبوبیت شخصیت (تعداد علاقه‌مندی‌های AniList)
/// تعیین می‌شود، نه شانسی: شخصیت ناشناخته هیچ‌وقت افسانه‌ای نمی‌شود.
/// وایفو/هازبندو دو درجه ویژه‌اند برای محبوب‌ترین شخصیت‌ها
/// (به‌ترتیب زن و مرد) با شانسی کمتر از افسانه‌ای.
enum CardRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  waifu,
  husbando,
}

extension CardRarityX on CardRarity {
  String get labelFa {
    switch (this) {
      case CardRarity.common:
        return tr('common');
      case CardRarity.uncommon:
        return tr('uncommon');
      case CardRarity.rare:
        return tr('rare');
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

  /// وزن شانس (مجموع ۱۰۰۰ — برای دقت نیم‌درصدی درجه‌های ویژه).
  ///
  /// عادی ۴۸٪، کمیاب ۲۶٪، فوق‌کمیاب ۱۵٪، حماسی ۷٪،
  /// افسانه‌ای ۳٪، وایفو ۰٫۵٪، هازبندو ۰٫۵٪.
  int get weight {
    switch (this) {
      case CardRarity.common:
        return 480;
      case CardRarity.uncommon:
        return 260;
      case CardRarity.rare:
        return 150;
      case CardRarity.epic:
        return 70;
      case CardRarity.legendary:
        return 30;
      case CardRarity.waifu:
        return 5;
      case CardRarity.husbando:
        return 5;
    }
  }

  /// سکه‌ای که نسخه تکراری به آن تبدیل می‌شود.
  int get duplicateCoins {
    switch (this) {
      case CardRarity.common:
        return 5;
      case CardRarity.uncommon:
        return 10;
      case CardRarity.rare:
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
      case CardRarity.uncommon:
        return const Color(0xFF38BDF8);
      case CardRarity.rare:
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

  static CardRarity fromKey(String key) {
    for (final r in CardRarity.values) {
      if (r.name == key) return r;
    }
    return CardRarity.common;
  }
}

/// یک کارت کلکسیونی (شخصیت انیمه).
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

/// نتیجه باز کردن یک بسته.
class PackResult {
  final List<CollectibleCard> cards;

  /// true یعنی کارت تکراری بوده و به سکه تبدیل شده.
  final List<bool> duplicates;
  final int coinsFromDuplicates;

  const PackResult({
    required this.cards,
    required this.duplicates,
    required this.coinsFromDuplicates,
  });
}

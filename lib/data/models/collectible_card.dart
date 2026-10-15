import 'package:flutter/material.dart';

/// کمیابی کارت‌ها با وزن شانس و جایزه تکراری.
enum CardRarity { common, uncommon, rare, epic, legendary }

extension CardRarityX on CardRarity {
  String get labelFa {
    switch (this) {
      case CardRarity.common:
        return 'عادی';
      case CardRarity.uncommon:
        return 'کمیاب';
      case CardRarity.rare:
        return 'فوق کمیاب';
      case CardRarity.epic:
        return 'حماسی';
      case CardRarity.legendary:
        return 'افسانه‌ای';
    }
  }

  /// وزن شانس (مجموع ۱۰۰).
  int get weight {
    switch (this) {
      case CardRarity.common:
        return 50;
      case CardRarity.uncommon:
        return 26;
      case CardRarity.rare:
        return 14;
      case CardRarity.epic:
        return 7;
      case CardRarity.legendary:
        return 3;
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

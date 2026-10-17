import 'package:flutter/material.dart';
import '../../core/i18n/lang.dart';

enum CardRarity { common, uncommon, rare, epic, legendary, waifu, husbando }

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

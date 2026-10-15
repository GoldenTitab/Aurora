import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import '../models/collectible_card.dart';
import '../remote/anilist_client.dart';
import '../repository/franchise_repository.dart';
import '../storage/economy.dart';

const int packPriceCoins = 100;
const int packSize = 3;

/// مدیریت استخر کارت‌ها (شخصیت‌های انیمه‌های کتابخانه) و باز کردن بسته.
class CardPool {
  CardPool(this._meta, this._cache, this._ani, this._repo);

  final Box<String> _meta;
  final Box<String> _cache;
  final AniListClient _ani;
  final FranchiseRepository _repo;

  static const _poolKey = 'cardpool';
  static const _poolTtl = Duration(days: 7);
  static const _maxFranchises = 40;
  static const _charsPerMedia = 20;

  /// ساخت/به‌روزرسانی استخر از شخصیت‌های انیمه‌های کتابخانه.
  /// خروجی: تعداد شخصیت‌های استخر.
  Future<int> rebuildPool({bool force = false}) async {
    if (!force) {
      final raw = _cache.get(_poolKey);
      if (raw != null) {
        try {
          final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
          final ts = m['ts'] as int? ?? 0;
          final items = (m['items'] as List?) ?? const [];
          if (DateTime.now().millisecondsSinceEpoch - ts <
                  _poolTtl.inMilliseconds &&
              items.isNotEmpty) {
            return items.length;
          }
        } catch (_) {}
      }
    }

    final franchises = _repo.allCachedFranchises().take(_maxFranchises);
    final seen = <int>{};
    final pool = <Map<String, dynamic>>[];
    for (final f in franchises) {
      if (f.anilistId <= 0) continue;
      try {
        final chars = await _ani.fetchCharacters(f.anilistId,
            perPage: _charsPerMedia);
        for (final c in chars) {
          final id = c['id'] as int;
          if (!seen.add(id)) continue;
          pool.add({
            'id': id,
            'name': c['name'] ?? '—',
            'image': c['image'],
          });
        }
      } catch (_) {}
      if (pool.length >= 600) break;
    }

    await _cache.put(
      _poolKey,
      jsonEncode({
        'ts': DateTime.now().millisecondsSinceEpoch,
        'items': pool,
      }),
    );
    return pool.length;
  }

  List<Map<String, dynamic>> _poolItems() {
    try {
      final raw = _cache.get(_poolKey);
      if (raw == null) return const [];
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return ((m['items'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  int poolSize() => _poolItems().length;

  CardRarity _rollRarity(Random rnd) {
    final roll = rnd.nextInt(100);
    var acc = 0;
    for (final r in CardRarity.values) {
      acc += r.weight;
      if (roll < acc) return r;
    }
    return CardRarity.common;
  }

  int _ownedCount(int charId) =>
      int.tryParse(_meta.get('card:$charId') ?? '') ?? 0;

  CardRarity _ownedRarity(int charId) {
    try {
      final raw = _meta.get('cardinfo:$charId');
      if (raw == null) return CardRarity.common;
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return CardRarityX.fromKey(m['rarity'] as String? ?? 'common');
    } catch (_) {
      return CardRarity.common;
    }
  }

  /// باز کردن یک بسته (۳ کارت، ۱۰۰ سکه). null یعنی سکه کافی نیست یا استخر خالی.
  Future<PackResult?> openPack(Economy eco) async {
    final pool = _poolItems();
    if (pool.isEmpty) return null;
    if (!await eco.spendCoins(packPriceCoins)) return null;

    final rnd = Random();
    final picked = <Map<String, dynamic>>[...pool]..shuffle(rnd);
    final cards = <CollectibleCard>[];
    final dups = <bool>[];
    var dupCoins = 0;

    for (final p in picked.take(packSize)) {
      final id = p['id'] as int;
      final rarity = _rollRarity(rnd);
      final owned = _ownedCount(id);
      if (owned > 0) {
        dups.add(true);
        dupCoins += rarity.duplicateCoins;
      } else {
        dups.add(false);
      }
      await _meta.put('card:$id', '${owned + 1}');
      await _meta.put(
        'cardinfo:$id',
        jsonEncode({
          'name': p['name'],
          'image': p['image'],
          'rarity': owned > 0 ? _ownedRarity(id).name : rarity.name,
        }),
      );
      cards.add(
        CollectibleCard(
          charId: id,
          name: (p['name'] as String?) ?? '—',
          image: p['image'] as String?,
          rarity: owned > 0 ? _ownedRarity(id) : rarity,
          count: owned + 1,
        ),
      );
    }

    if (dupCoins > 0) await eco.addCoins(dupCoins);
    await eco.bumpStat('packs_opened');
    await eco.bumpMissionCounter('pack_w', Economy.weekId());
    return PackResult(
      cards: cards,
      duplicates: dups,
      coinsFromDuplicates: dupCoins,
    );
  }

  /// کلکسیون کاربر گروه‌بندی‌شده بر اساس کمیابی.
  Map<CardRarity, List<CollectibleCard>> collection() {
    final out = <CardRarity, List<CollectibleCard>>{
      for (final r in CardRarity.values) r: [],
    };
    for (final k in _meta.keys.map((e) => e.toString())) {
      if (!k.startsWith('card:')) continue;
      final id = int.tryParse(k.substring(5));
      if (id == null) continue;
      final count = _ownedCount(id);
      if (count <= 0) continue;
      String name = '—';
      String? image;
      var rarity = CardRarity.common;
      try {
        final raw = _meta.get('cardinfo:$id');
        if (raw != null) {
          final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
          name = (m['name'] as String?) ?? '—';
          image = m['image'] as String?;
          rarity = CardRarityX.fromKey(m['rarity'] as String? ?? 'common');
        }
      } catch (_) {}
      out[rarity]!.add(
        CollectibleCard(
          charId: id,
          name: name,
          image: image,
          rarity: rarity,
          count: count,
        ),
      );
    }
    for (final list in out.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return out;
  }

  int totalOwned() {
    var n = 0;
    for (final k in _meta.keys.map((e) => e.toString())) {
      if (k.startsWith('card:')) n++;
    }
    return n;
  }

  Map<String, int> ownedPerRarity() {
    final out = <String, int>{};
    for (final k in _meta.keys.map((e) => e.toString())) {
      if (!k.startsWith('card:')) continue;
      final id = int.tryParse(k.substring(5));
      if (id == null) continue;
      final r = _ownedRarity(id).name;
      out[r] = (out[r] ?? 0) + 1;
    }
    return out;
  }
}

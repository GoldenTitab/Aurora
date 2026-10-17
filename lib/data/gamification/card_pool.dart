import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';

import '../models/collectible_card.dart';
import '../remote/anilist_client.dart';
import '../repository/franchise_repository.dart';
import '../storage/economy.dart';

const int packPriceCoins = 100;
const int packSize = 3;

class CardPool {
  CardPool(this._meta, this._cache, this._ani, this._repo);

  final Box<String> _meta;
  final Box<String> _cache;
  final AniListClient _ani;
  final FranchiseRepository _repo;

  static const _poolKey = 'cardpool';

  static const _poolVersion = 2;
  static const _poolTtl = Duration(days: 7);
  static const _maxFranchises = 40;
  static const _charsPerMedia = 20;

  static const int _favUncommon = 80;
  static const int _favRare = 300;
  static const int _favEpic = 1000;
  static const int _favLegendary = 3000;
  static const int _favSpecial = 10000;

  static CardRarity rarityFor(int favourites, String? gender) {
    if (favourites >= _favSpecial) {
      final g = (gender ?? '').toLowerCase();
      if (g == 'female') return CardRarity.waifu;
      if (g == 'male') return CardRarity.husbando;
      return CardRarity.legendary;
    }
    if (favourites >= _favLegendary) return CardRarity.legendary;
    if (favourites >= _favEpic) return CardRarity.epic;
    if (favourites >= _favRare) return CardRarity.rare;
    if (favourites >= _favUncommon) return CardRarity.uncommon;
    return CardRarity.common;
  }

  Future<int> rebuildPool({bool force = false}) async {
    if (!force) {
      final items = _poolItems();
      if (items.isNotEmpty) return items.length;
    }

    final franchises = _repo.allCachedFranchises().take(_maxFranchises);
    final seen = <int>{};
    final pool = <Map<String, dynamic>>[];
    for (final f in franchises) {
      if (f.anilistId <= 0) continue;
      try {
        final chars = await _ani.fetchCharacters(
          f.anilistId,
          perPage: _charsPerMedia,
        );
        for (final c in chars) {
          final id = c['id'] as int;
          if (!seen.add(id)) continue;
          final fav = (c['favourites'] as num?)?.toInt() ?? 0;
          final gender = (c['gender'] as String?) ?? '';
          pool.add({
            'id': id,
            'name': c['name'] ?? '—',
            'image': c['image'],
            'favourites': fav,
            'gender': gender,
            'rarity': rarityFor(fav, gender).name,
          });
        }
      } catch (_) {}
      if (pool.length >= 600) break;
    }

    await _cache.put(
      _poolKey,
      jsonEncode({
        'v': _poolVersion,
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
      if ((m['v'] as int?) != _poolVersion) return const [];
      final ts = m['ts'] as int? ?? 0;
      final items = (m['items'] as List?) ?? const [];
      if (DateTime.now().millisecondsSinceEpoch - ts >
              _poolTtl.inMilliseconds ||
          items.isEmpty) {
        return const [];
      }
      return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  int poolSize() => _poolItems().length;

  Future<void> clearPool() => _cache.delete(_poolKey);

  Map<CardRarity, int> rarityBreakdown() {
    final out = <CardRarity, int>{};
    for (final p in _poolItems()) {
      final r = CardRarityX.fromKey(p['rarity'] as String? ?? '');
      out[r] = (out[r] ?? 0) + 1;
    }
    return out;
  }

  CardRarity _rollRarity(Random rnd) {
    final roll = rnd.nextInt(1000);
    var acc = 0;
    for (final r in CardRarity.values) {
      acc += r.weight;
      if (roll < acc) return r;
    }
    return CardRarity.common;
  }

  Map<String, dynamic>? _pickForTier(
    List<Map<String, dynamic>> pool,
    CardRarity tier,
    Random rnd,
    Set<int> exclude,
  ) {
    final order = <CardRarity>[tier];
    final idx = CardRarity.values.indexOf(tier);
    for (var d = 1; d < CardRarity.values.length; d++) {
      if (idx - d >= 0) order.add(CardRarity.values[idx - d]);
      if (idx + d < CardRarity.values.length) {
        order.add(CardRarity.values[idx + d]);
      }
    }
    for (final r in order) {
      final list = pool
          .where((p) => p['rarity'] == r.name && !exclude.contains(p['id']))
          .toList();
      if (list.isNotEmpty) return list[rnd.nextInt(list.length)];
    }
    return null;
  }

  int _ownedCount(int charId) =>
      int.tryParse(_meta.get('card:$charId') ?? '') ?? 0;

  CardRarity _effectiveRarity(
    int charId,
    Map<int, Map<String, dynamic>> poolIndex,
  ) {
    final p = poolIndex[charId];
    if (p != null) return CardRarityX.fromKey(p['rarity'] as String? ?? '');
    try {
      final raw = _meta.get('cardinfo:$charId');
      if (raw == null) return CardRarity.common;
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return CardRarityX.fromKey(m['rarity'] as String? ?? 'common');
    } catch (_) {
      return CardRarity.common;
    }
  }

  Future<PackResult?> openPack(Economy eco) async {
    var pool = _poolItems();
    if (pool.isEmpty) {
      await rebuildPool();
      pool = _poolItems();
      if (pool.isEmpty) return null;
    }
    if (!await eco.spendCoins(packPriceCoins)) return null;

    final rnd = Random();
    final pickedIds = <int>{};
    final cards = <CollectibleCard>[];
    final dups = <bool>[];
    var dupCoins = 0;

    for (var i = 0; i < packSize; i++) {
      var tier = _rollRarity(rnd);
      Map<String, dynamic>? p;
      for (var attempt = 0; attempt < 6; attempt++) {
        final cand = _pickForTier(pool, tier, rnd, pickedIds);
        if (cand == null) break;
        final actual = CardRarityX.fromKey(
          cand['rarity'] as String? ?? tier.name,
        );
        if (actual == tier || attempt == 5) {
          p = cand;
          break;
        }
        tier = _rollRarity(rnd);
      }
      if (p == null) continue;
      final id = p['id'] as int;
      pickedIds.add(id);
      final rarity = CardRarityX.fromKey(p['rarity'] as String? ?? tier.name);
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
          'rarity': rarity.name,
        }),
      );
      cards.add(
        CollectibleCard(
          charId: id,
          name: (p['name'] as String?) ?? '—',
          image: p['image'] as String?,
          rarity: rarity,
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

  Map<CardRarity, List<CollectibleCard>> collection() {
    final pool = _poolItems();
    final poolIndex = {for (final p in pool) (p['id'] as int): p};
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
      try {
        final raw = _meta.get('cardinfo:$id');
        if (raw != null) {
          final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
          name = (m['name'] as String?) ?? '—';
          image = m['image'] as String?;
        }
      } catch (_) {}
      final rarity = _effectiveRarity(id, poolIndex);
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
    final pool = _poolItems();
    final poolIndex = {for (final p in pool) (p['id'] as int): p};
    final out = <String, int>{};
    for (final k in _meta.keys.map((e) => e.toString())) {
      if (!k.startsWith('card:')) continue;
      final id = int.tryParse(k.substring(5));
      if (id == null) continue;
      final r = _effectiveRarity(id, poolIndex).name;
      out[r] = (out[r] ?? 0) + 1;
    }
    return out;
  }
}

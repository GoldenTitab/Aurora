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
///
/// سیستم محبوبیتی (تصمیم علی، 2026-10-18): درجه‌ی هر شخصیت از روی
/// محبوبیتش در AniList (favourites) تعیین می‌شود — هرچه معروف‌تر،
/// درجه بالاتر و شانس دریافت کمتر:
///
/// عادی < ۶٬۰۰۰ | کمیاب ۶٬۰۰۰–۱۲٬۰۰۰ | فوق‌کمیاب ۱۲٬۰۰۰–۲۰٬۰۰۰ |
/// حماسی ۲۰٬۰۰۰–۳۰٬۰۰۰ | افسانه‌ای ۳۰٬۰۰۰+ |
/// وایفو: مؤنث با ۳۰٬۰۰۰+ | هازبندو: مذکر با ۳۰٬۰۰۰+
///
/// تاس، خروجی را با وزن‌های مصوب علی (از ۱۰۰۰۰: عادی 4900، کمیاب 2646،
/// فوق‌کمیاب 1470، حماسی 588، افسانه‌ای 196، وایفو 100، هازبندو 100)
/// انتخاب می‌کند؛ سپس شخصیت به‌صورت یکنواخت از میان شخصیت‌هایی که
/// درجه‌ی ذاتی‌شان با خروجیِ تاس یکی است برداشته می‌شود (به‌جز
/// تکراری‌های همین بسته).
///
/// اگر برای خروجیِ تاس‌آمده شخصیتی نباشد، تاس از نو انداخته می‌شود
/// (حداکثر ۱۰ تلاش). در حالت نادرِ اتمام تلاش‌ها، از میان باقی‌مانده‌ی
/// استخر یک شخصیت برداشته و درجه‌ی ذاتی خودش روی کارت می‌نشیند —
/// این رفتار مستند است و توزیع را فقط در موارد مرزی جابه‌جا می‌کند.
class CardPool {
  CardPool(this._meta, this._cache, this._ani, this._repo);

  final Box<String> _meta;
  final Box<String> _cache;
  final AniListClient _ani;
  final FranchiseRepository _repo;

  static const _poolKey = 'cardpool';

  /// نسخه‌ی ساختار کش استخر؛ با تغییر ساختار، کش قدیمی نادیده گرفته می‌شود.
  static const _poolVersion = 4;
  static const _poolTtl = Duration(days: 7);
  static const _maxFranchises = 40;
  static const _charsPerMedia = 20;

  /// حداکثر تلاش برای تاس مجدد خروجی وقتی واجد شرایطی ندارد.
  static const _maxOutcomeRerolls = 10;

  /// آستانه‌های محبوبیت (تعداد علاقه‌مندی‌های AniList) — مصوب علی.
  static const int _favRare = 6000;
  static const int _favSuperRare = 12000;
  static const int _favEpic = 20000;
  static const int _favLegendary = 30000;

  /// کلید نگه‌بان مهاجرت یک‌باره‌ی درجه‌های قدیمی.
  static const _rarityMigrationKey = 'card_rarity_v4_done';

  /// نگاشت شناسه‌های درجه‌ی قدیمی به جدید (نام نمایشی عوض نمی‌شود):
  /// 'uncommon' (کمیاب قدیم) → 'rare' (کمیاب جدید)،
  /// 'rare' (فوق‌کمیاب قدیم) → 'superRare' (فوق‌کمیاب جدید).
  static const _legacyRarityMap = {'uncommon': 'rare', 'rare': 'superRare'};

  /// درجه‌ی ذاتی شخصیت از روی محبوبیت و جنسیت — خالص و تست‌پذیر.
  static CardRarity rarityFor(int favourites, String? gender) {
    if (favourites >= _favLegendary) {
      final g = (gender ?? '').toLowerCase();
      if (g == 'female') return CardRarity.waifu;
      if (g == 'male') return CardRarity.husbando;
      return CardRarity.legendary;
    }
    if (favourites >= _favEpic) return CardRarity.epic;
    if (favourites >= _favSuperRare) return CardRarity.superRare;
    if (favourites >= _favRare) return CardRarity.rare;
    return CardRarity.common;
  }

  /// ساخت/به‌روزرسانی استخر از شخصیت‌های انیمه‌های کتابخانه.
  /// خروجی: تعداد شخصیت‌های استخر.
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
          pool.add({
            'id': id,
            'name': c['name'] ?? '—',
            'image': c['image'],
            'favourites': (c['favourites'] as num?)?.toInt() ?? 0,
            'gender': (c['gender'] as String?) ?? '',
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

  /// پاک‌سازی کش استخر؛ در باز کردن بعدیِ بسته، استخر از نو ساخته می‌شود.
  Future<void> clearPool() => _cache.delete(_poolKey);

  /// ترکیب استخر بر اساس درجه‌ی ذاتی (برای شفافیت: کاربر ببیند استخرش
  /// از هر درجه چند شخصیت دارد).
  Map<CardRarity, int> rarityBreakdown() {
    final out = <CardRarity, int>{};
    for (final p in _poolItems()) {
      final r = rarityFor(
        (p['favourites'] as num?)?.toInt() ?? 0,
        p['gender'] as String?,
      );
      out[r] = (out[r] ?? 0) + 1;
    }
    return out;
  }

  /// مهاجرت یک‌باره‌ی درجه‌های ذخیره‌شده‌ی قدیمی به شناسه‌های جدید.
  /// کارت‌ها دوباره تاس انداخته نمی‌شوند؛ فقط شناسه‌ی ذخیره‌شده با
  /// حفظ نام نمایشی نرمال می‌شود. خواندن‌ها ([_storedRarity]) مستقل از
  /// این مهاجرت هم درست کار می‌کنند (کمربند ایمنی).
  Future<void> migrateLegacyRarities() async {
    if ((_meta.get(_rarityMigrationKey) ?? '') == '1') return;
    for (final k in _meta.keys.map((e) => e.toString())) {
      if (!k.startsWith('cardinfo:')) continue;
      try {
        final raw = _meta.get(k);
        if (raw == null) continue;
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final r = m['rarity'] as String?;
        final mapped = _legacyRarityMap[r];
        if (mapped != null) {
          m['rarity'] = mapped;
          await _meta.put(k, jsonEncode(m));
        }
      } catch (_) {}
    }
    await _meta.put(_rarityMigrationKey, '1');
  }

  /// انتخاب شخصیت برای یک خروجی — خالص و تست‌پذیر.
  ///
  /// فقط شخصیت‌هایی که درجه‌ی ذاتی‌شان با [outcome] یکی است واجد
  /// شرایط‌اند ([outcome]ی null یعنی هر درجه‌ای — برای آخرین راه‌حل).
  /// [exclude]: شناسه‌هایی که در همین بسته قبلاً برداشته شده‌اند.
  /// خروجی null یعنی هیچ واجد شرایطی نیست.
  static Map<String, dynamic>? pickForOutcome(
    List<Map<String, dynamic>> pool,
    CardRarity? outcome,
    Random rnd,
    Set<int> exclude,
  ) {
    final list = pool.where((p) {
      if (exclude.contains(p['id'] as int)) return false;
      if (outcome == null) return true;
      return rarityFor(
            (p['favourites'] as num?)?.toInt() ?? 0,
            p['gender'] as String?,
          ) ==
          outcome;
    }).toList();
    if (list.isEmpty) return null;
    return list[rnd.nextInt(list.length)];
  }

  int _ownedCount(int charId) =>
      int.tryParse(_meta.get('card:$charId') ?? '') ?? 0;

  /// درجه‌ی ذخیره‌شده‌ی یک کارت، با نرمال‌سازی شناسه‌های قدیمی.
  /// (کمربند ایمنی وقتی شخصیت در استخر نیست.)
  CardRarity _storedRarity(int charId) {
    try {
      final raw = _meta.get('cardinfo:$charId');
      if (raw == null) return CardRarity.common;
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final r = m['rarity'] as String? ?? 'common';
      return CardRarityX.fromKey(_legacyRarityMap[r] ?? r);
    } catch (_) {
      return CardRarity.common;
    }
  }

  /// درجه‌ی مؤثر یک کارت: اگر شخصیت در استخر باشد، درجه‌ی ذاتی‌اش از
  /// روی محبوبیت فعلی؛ وگرنه مقدار ذخیره‌شده (نرمال‌شده).
  CardRarity _effectiveRarity(
    int charId,
    Map<int, Map<String, dynamic>> poolIndex,
  ) {
    final p = poolIndex[charId];
    if (p != null) {
      return rarityFor(
        (p['favourites'] as num?)?.toInt() ?? 0,
        p['gender'] as String?,
      );
    }
    return _storedRarity(charId);
  }

  /// باز کردن یک بسته (۳ کارت، ۱۰۰ سکه). null یعنی سکه کافی نیست یا استخر خالی.
  /// [random] برای تست تزریق می‌شود.
  Future<PackResult?> openPack(Economy eco, {Random? random}) async {
    await migrateLegacyRarities();
    var pool = _poolItems();
    if (pool.isEmpty) {
      await rebuildPool();
      pool = _poolItems();
      if (pool.isEmpty) return null;
    }
    if (!await eco.spendCoins(packPriceCoins)) return null;

    final rnd = random ?? Random();
    final pickedIds = <int>{};
    final cards = <CollectibleCard>[];
    final dups = <bool>[];
    var dupCoins = 0;

    for (var i = 0; i < packSize; i++) {
      Map<String, dynamic>? p;
      for (var attempt = 0; attempt < _maxOutcomeRerolls; attempt++) {
        final o = CardRarityX.rollOutcome(
          rnd.nextInt(CardRarityX.totalWeight),
        );
        final cand = pickForOutcome(pool, o, rnd, pickedIds);
        if (cand != null) {
          p = cand;
          break;
        }
        // خروجیِ تاس‌آمده شخصیت نداشت — تاس از نو (نه سقوط بی‌صدا).
      }
      // آخرین راه‌حلِ مستند: هر شخصیت باقی‌مانده با درجه‌ی ذاتی خودش.
      p ??= pickForOutcome(pool, null, rnd, pickedIds);
      if (p == null) continue;
      final id = p['id'] as int;
      pickedIds.add(id);
      // درجه = درجه‌ی ذاتی شخصیت (نه برچسب تصادفی).
      final rarity = rarityFor(
        (p['favourites'] as num?)?.toInt() ?? 0,
        p['gender'] as String?,
      );
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
    // تازه‌ها: ترتیب گرفتن کارت‌ها (سقف ۱۲)
    try {
      final ids = [for (final c in cards) c.charId];
      final raw = _meta.get('card_recent');
      final list = <int>[
        ...ids,
        if (raw != null && raw.isNotEmpty)
          ...(raw.split(',').map(int.tryParse).whereType<int>()),
      ];
      final seen = <int>{};
      final deduped = [
        for (final id in list)
          if (seen.add(id)) id,
      ];
      await _meta.put('card_recent', deduped.take(12).join(','));
    } catch (_) {}
    return PackResult(
      cards: cards,
      duplicates: dups,
      coinsFromDuplicates: dupCoins,
    );
  }

  /// شناسه‌ی کارت‌های تازه‌گرفته‌شده (به ترتیب زمانی، سقف ۱۲).
  List<int> recentCardIds() {
    try {
      final raw = _meta.get('card_recent');
      if (raw == null || raw.isEmpty) return const [];
      return raw.split(',').map(int.tryParse).whereType<int>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// ورودی استخر برای یک شخصیت (برای نمایش فیو و جنسیت در جزئیات کارت).
  Map<String, dynamic>? poolEntry(int charId) {
    try {
      for (final p in _poolItems()) {
        if ((p['id'] as int?) == charId) return p;
      }
    } catch (_) {}
    return null;
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

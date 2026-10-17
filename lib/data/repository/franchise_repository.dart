import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';

import '../../core/constants/app_config.dart';
import '../../core/utils/text_utils.dart';
import '../models/anime_card_data.dart';
import '../models/entry.dart';
import '../models/franchise.dart';
import '../remote/anilist_client.dart';
import '../remote/api_exception.dart';
import '../remote/jikan_client.dart';
import '../remote/mal_client.dart';
import '../storage/migrations.dart';
import '../../core/i18n/lang.dart';

class _Item {
  final Map<String, dynamic> media;
  bool isMain;
  _Item(this.media, this.isMain);
}

class _Cached {
  final Franchise franchise;
  final bool fresh;
  _Cached(this.franchise, this.fresh);
}

class FranchiseRepository {
  FranchiseRepository(this._ani, this._jikan, this._mal, this._box);

  final AniListClient _ani;
  final JikanClient _jikan;
  final MalClient _mal;
  final Box<String> _box;

  static const Duration _ttl = Duration(days: 3);

  /// روابطی که زنجیره اصلی را می‌سازند و BFS روی آن‌ها ادامه می‌یابد.
  static const Set<String> _chainRelations = {
    'PREQUEL',
    'SEQUEL',
    'PARENT',
    'CHILD',
  };

  /// روابطی که به‌عنوان محتوای مرتبط به فرنچایز اضافه می‌شوند.
  /// نکته: CHARACTER عمداً اینجا نیست — در AniList برای محتوای جانبیِ
  /// شخصیت‌محور به کار می‌رود و باعث قاطی شدن فرنچایزهای نامرتبط می‌شد
  /// (مثلاً Dragon Ball Z با رابطه CHARACTER از طریق MONSTERS وارد
  /// فرنچایز One Piece شده و چون قدیمی‌تر بود ریشه را های‌جک کرده بود).
  static const Set<String> _relatedRelations = {
    'SIDE_STORY',
    'SPIN_OFF',
    'SUMMARY',
    'OTHER',
    'COMPILATION',
    'CONTAINS',
    'ALTERNATIVE',
  };

  static const Set<String> _mainFormats = {'TV', 'TV_SHORT', 'MOVIE', 'ONA'};

  static const Set<String> _searchFormats = {'TV', 'TV_SHORT', 'MOVIE', 'ONA'};

  static const int _maxChainNodes = 20;

  /// حداکثر تعداد نگاشت MAL/Jikan → AniList در هر ساخت فرنچایز.
  static const int _maxCrossResolves = 8;

  Future<Franchise> getFranchise(int anyId, {bool forceRefresh = false}) async {
    final rootKey = _box.get('a:al-$anyId') ?? 'al-$anyId';
    final cached = _readCache(rootKey);
    if (cached != null && cached.fresh && !forceRefresh) {
      return _withManual(cached.franchise);
    }
    try {
      final franchise = await _buildSerial(anyId);
      await _save(franchise, 'a:al-$anyId');
      return _withManual(franchise);
    } catch (e) {
      if (cached != null) return _withManual(cached.franchise);
      rethrow;
    }
  }

  /// گرفتن فرنچایز از روی شناسه MAL.
  /// اگر در AniList نگاشت داشته باشد همان فرنچایز کامل ساخته می‌شود،
  /// وگرنه یک فرنچایز تک‌عضوی از روی دیتای Jikan ساخته می‌شود.
  Future<Franchise> getFranchiseByMal(
    int malId, {
    bool forceRefresh = false,
  }) async {
    final aliasKey = 'a:mal-$malId';
    final rootKey = _box.get(aliasKey);
    if (rootKey != null && !forceRefresh) {
      final cached = _readCache(rootKey);
      if (cached != null && cached.fresh) return _withManual(cached.franchise);
    }

    // ۱) آیا قبلاً در کش فرنچایزی با همین malId داریم؟
    for (final f in allCachedFranchises()) {
      if (f.malId == malId || f.entries.any((e) => e.malId == malId)) {
        await _box.put(aliasKey, f.id);
        return f;
      }
    }

    // ۲) نگاشت به AniList
    final media = await _ani.fetchMediaByMal(malId);
    if (media != null) {
      final id = media['id'] as int;
      final f = await getFranchise(id, forceRefresh: forceRefresh);
      await _box.put(aliasKey, f.id);
      return f;
    }

    // ۳) فرنچایز تک‌عضوی از Jikan
    final detail = await _jikan.fetchAnime(malId);
    if (detail == null) {
      throw  ApiException(
        tr('this_anime_wasn_t_found_on_anilist_or_any_other_'),
      );
    }
    final entry = Entry.fromJikanSearch(detail);
    final images = detail['images'] as Map?;
    final jpg = images?['jpg'] as Map?;
    final genres =
        ((detail['genres'] as List?) ?? const [])
            .map((g) => ((g as Map)['name'] ?? '') as String)
            .where((g) => g.isNotEmpty)
            .toList();
    final f = Franchise(
      id: 'mal-$malId',
      anilistId: 0,
      malId: malId,
      titleFa: entry.title,
      titleEn: entry.title,
      cover: (jpg?['large_image_url'] ?? entry.cover ?? '') as String,
      score: entry.score,
      year: entry.year ?? 0,
      genres: genres,
      synopsis: stripHtml(detail['synopsis'] as String?),
      entries: [entry],
    );
    await _save(f, aliasKey);
    return _withManual(f);
  }

  Future<void> _buildTail = Future.value();

  Future<Franchise> _buildSerial(int id) {
    final completer = Completer<Franchise>();
    _buildTail = _buildTail.then((_) async {
      try {
        completer.complete(await _build(id));
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<Franchise> _build(int anyId) async {
    final items = <int, _Item>{};
    // نگاشت هر نود به (والد، نوع رابطه) برای ساخت درخت فرنچایز
    final edgeOf = <int, ({int parent, String rel})>{};
    final queue = <int>[anyId];
    final visited = <int>{};

    while (queue.isNotEmpty && visited.length < _maxChainNodes) {
      final id = queue.removeAt(0);
      if (!visited.add(id)) continue;

      final media = await _ani.fetchMedia(id);
      // دیتای کامل جایگزین نود ناقصِ یال‌ها می‌شود
      items[id] = _Item(media, _mainFormats.contains(media['format']));

      final edges = (media['relations']?['edges'] as List?) ?? const [];
      for (final raw in edges) {
        final edge = (raw as Map).cast<String, dynamic>();
        final nodeRaw = edge['node'];
        if (nodeRaw == null) continue;
        final node = (nodeRaw as Map).cast<String, dynamic>();

        if (node['type'] != 'ANIME' || node['format'] == 'MUSIC') continue;
        final nid = node['id'] as int;
        final rel = (edge['relationType'] as String?)?.toUpperCase();
        if (rel == null) continue;

        final inChain = _chainRelations.contains(rel);
        final inRelated = _relatedRelations.contains(rel);
        if (!inChain && !inRelated) continue;

        items.putIfAbsent(
          nid,
          () => _Item(node, _mainFormats.contains(node['format'])),
        );

        // ثبت یال برای درخت: برای PREQUEL و PARENT، والد همان نود مقصد است
        if (rel == 'PREQUEL' || rel == 'PARENT') {
          edgeOf.putIfAbsent(id, () => (parent: nid, rel: rel));
        } else {
          edgeOf.putIfAbsent(nid, () => (parent: id, rel: rel));
        }

        if (inChain && !visited.contains(nid) && !queue.contains(nid)) {
          queue.add(nid);
        }
      }
    }

    // ── تکمیل از MAL و Jikan (روابطی که AniList ندارد) ──
    await _mergeCrossApiRelations(items, edgeOf, anyId);

    // ── ارتقای داستان اصلی با شباهت عنوان ──
    _promoteByTitleSimilarity(items, edgeOf);

    final sorted = items.values.toList()..sort(_compareByDate);
    final entries = sorted.map((i) {
      final nid = i.media['id'] as int;
      final edge = edgeOf[nid];
      String? parentId;
      String? rel;
      if (edge != null && edge.parent != nid && items.containsKey(edge.parent)) {
        parentId = 'al-${edge.parent}';
        rel = edge.rel;
      }
      return Entry.fromAniList(
        i.media,
        isMainStory: i.isMain,
        relationType: rel,
        parentEntryId: parentId,
      );
    }).toList();

    // انتخاب ریشه به متد استاتیک pickRootId سپرده شده (تست‌پذیر).
    final rootId = pickRootId(
      {for (final e in items.entries) e.key: e.value.media},
      _mainFormats,
      anyId,
    );
    final root = items[rootId]?.media ?? items.values.first.media;
    final t = (root['title'] ?? {}) as Map;
    final titleEn =
        (t['english'] ?? t['romaji'] ?? t['native'] ?? '—') as String;
    final cover = root['coverImage'] as Map?;
    final avg = root['averageScore'] as int?;
    final malId = root['idMal'] as int?;

    var franchise = Franchise(
      id: 'al-$rootId',
      anilistId: rootId,
      malId: malId,
      titleFa: persianTitles[rootId] ?? titleEn,
      titleEn: titleEn,
      cover: (cover?['extraLarge'] ?? cover?['large'] ?? '') as String,
      banner: root['bannerImage'] as String?,
      score: avg == null ? 0 : avg / 10.0,
      year:
          (root['seasonYear'] as int?) ??
          ((root['startDate'] as Map?)?['year'] as int?) ??
          0,
      genres: ((root['genres'] as List?) ?? const []).cast<String>(),
      synopsis: stripHtml(root['description'] as String?),
      entries: entries,
    );

    if (malId != null) {
      final malScore =
          await _mal.fetchScore(malId) ?? await _jikan.fetchScore(malId);
      if (malScore != null) franchise = franchise.copyWith(malScore: malScore);
    }
    return franchise;
  }

  /// ادغام روابط MAL و Jikan برای نود ریشه؛ مواردی که AniList ندارد
  /// از طریق idMal به AniList نگاشت و به آیتم‌ها اضافه می‌شوند.
  Future<void> _mergeCrossApiRelations(
    Map<int, _Item> items,
    Map<int, ({int parent, String rel})> edgeOf,
    int rootAniId,
  ) async {
    final rootMedia = items[rootAniId]?.media;
    final rootMalId = rootMedia?['idMal'] as int?;
    if (rootMalId == null) return;

    final extra = <({int malId, String rel})>[];
    try {
      for (final r in await _mal.related(rootMalId)) {
        final norm = mapExternalRelation(r.relation);
        if (norm == null) continue;
        final rid = (r.node['id'] as num?)?.toInt();
        if (rid == null) continue;
        extra.add((malId: rid, rel: norm));
      }
    } catch (_) {}
    try {
      for (final r in await _jikan.relations(rootMalId)) {
        final norm = mapExternalRelation(r.relation);
        if (norm != null) extra.add((malId: r.malId, rel: norm));
      }
    } catch (_) {}
    if (extra.isEmpty) return;

    final knownMal = <int>{
      for (final it in items.values)
        if (it.media['idMal'] is int) it.media['idMal'] as int,
    };
    var added = 0;
    for (final e in extra) {
      if (added >= _maxCrossResolves) break;
      if (knownMal.contains(e.malId)) continue;
      Map<String, dynamic>? media;
      try {
        media = await _ani.fetchMediaByMal(e.malId);
      } catch (_) {
        media = null;
      }
      if (media == null) continue;
      final nid = media['id'] as int;
      if (items.containsKey(nid)) {
        knownMal.add(e.malId);
        continue;
      }
      items[nid] = _Item(media, _mainFormats.contains(media['format']));
      knownMal.add(e.malId);
      if (e.rel == 'PREQUEL' || e.rel == 'PARENT') {
        edgeOf.putIfAbsent(rootAniId, () => (parent: nid, rel: e.rel));
      } else {
        edgeOf.putIfAbsent(nid, () => (parent: rootAniId, rel: e.rel));
      }
      added++;
    }
  }

  /// نگاشت نام رابطه MAL/Jikan به نام استاندارد AniList.
  ///
  /// public است تا مستقیم تست‌پذیر باشد (رگرسیون CHARACTER).
  static String? mapExternalRelation(String raw) {
    final r = raw.trim().toLowerCase().replaceAll(RegExp(r'[_\s-]'), '');
    switch (r) {
      case 'sequel':
        return 'SEQUEL';
      case 'prequel':
        return 'PREQUEL';
      case 'parentstory':
        return 'PARENT';
      case 'fullstory':
        return 'PARENT';
      case 'sidestory':
        return 'SIDE_STORY';
      case 'spinoff':
        return 'SPIN_OFF';
      case 'summary':
        return 'SUMMARY';
      case 'character':
        // مثل CHARACTER در گراف اصلی: سست است و فرنچایزها را قاطی می‌کند.
        return null;
      case 'other':
        return 'OTHER';
      case 'alternativesetting':
      case 'alternativeversion':
        return 'ALTERNATIVE';
      case 'adaptation':
      case 'manga':
      case 'novel':
        return null;
      default:
        // رابطه ناشناخته از منبع خارجی: حدس نزن و ادغام نکن.
        // قبلاً 'OTHER' برمی‌گرداند که باعث قاطی شدن فرنچایزهای
        // نامرتبط می‌شد.
        return null;
    }
  }

  /// اگر عنوان یک محتوای مرتبط خیلی شبیه عنوان ریشه باشد،
  /// احتمالاً جزو داستان اصلی است (مثلاً فصل‌بندی اشتباه API).
  void _promoteByTitleSimilarity(
    Map<int, _Item> items,
    Map<int, ({int parent, String rel})> edgeOf,
  ) {
    if (items.isEmpty) return;
    final sorted = items.values.toList()..sort(_compareByDate);
    Map<String, dynamic>? root;
    for (final m in sorted) {
      if (_mainFormats.contains(m.media['format'])) {
        root = m.media;
        break;
      }
    }
    root ??= sorted.first.media;
    final t = (root['title'] ?? {}) as Map;
    final rootTitle =
        (t['english'] ?? t['romaji'] ?? t['native'] ?? '') as String;
    if (rootTitle.isEmpty) return;

    const promotable = {
      'OTHER',
      'CHARACTER',
      'SIDE_STORY',
      'ALTERNATIVE',
      'SPIN_OFF',
      'SUMMARY',
    };
    for (final e in items.entries) {
      final it = e.value;
      if (it.isMain) continue;
      final rel = edgeOf[e.key]?.rel;
      if (rel != null && !promotable.contains(rel)) continue;
      final nt = (it.media['title'] ?? {}) as Map;
      final title =
          (nt['english'] ?? nt['romaji'] ?? nt['native'] ?? '') as String;
      if (title.isEmpty) continue;
      if (titleSimilarity(title, rootTitle) >= 0.6) {
        it.isMain = true;
      }
    }
  }

  /// انتخاب شناسه‌ی ریشه‌ی فرنچایز از بین مدیاهای جمع‌آوری‌شده.
  ///
  /// اولویت‌ها به ترتیب (دقیقاً همان semantics قبلی کد، فقط استخراج‌شده
  /// برای تست‌پذیری — هیچ تغییری در رفتار ندارد):
  /// ۱. قدیمی‌ترین آیتم با فرمت اصلی (مرتب‌سازی با [dateKey]).
  /// ۲. وگرنه خودِ [anyId] (اگر در مپ باشد).
  /// ۳. وگرنه اولین آیتم مپ.
  ///
  /// نکته: باگ One Piece/DBZ با حذف رابطه‌ی CHARACTER از
  /// _relatedRelations حل شده (DBZ اصلاً وارد آیتم‌ها نمی‌شود)؛ این متد
  /// فقط همان منطق قبلی را نگه می‌دارد.
  ///
  /// public و استاتیک است تا مستقیم تست‌پذیر باشد.
  static int pickRootId(
    Map<int, Map<String, dynamic>> mediaById,
    Set<String> mainFormats,
    int anyId,
  ) {
    final candidates = mediaById.entries.toList()
      ..sort((a, b) => dateKey(a.value).compareTo(dateKey(b.value)));
    for (final e in candidates) {
      if (mainFormats.contains(e.value['format'])) return e.key;
    }
    if (mediaById.containsKey(anyId)) return anyId;
    return mediaById.keys.first;
  }

  static int dateKey(Map<String, dynamic> m) {
    final d = m['startDate'] as Map?;
    final y = d?['year'] as int?;
    if (y == null) return 99999999;
    return y * 10000 +
        ((d?['month'] as int?) ?? 1) * 100 +
        ((d?['day'] as int?) ?? 1);
  }

  static int _compareByDate(_Item a, _Item b) {
    final c = dateKey(a.media).compareTo(dateKey(b.media));
    if (c != 0) return c;
    return (a.media['id'] as int).compareTo(b.media['id'] as int);
  }

  Future<void> _save(Franchise f, String requestedKey) async {
    await _box.put(
      'f:${f.id}',
      jsonEncode({
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': f.toJson(),
      }),
    );
    for (final e in f.entries) {
      await _box.put('a:${e.id}', f.id);
    }
    await _box.put(requestedKey, f.id);
  }

  _Cached? _readCache(String franchiseId) {
    return _decode(_box.get('f:$franchiseId'));
  }

  _Cached? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final ts = DateTime.fromMillisecondsSinceEpoch(map['ts'] as int);
      final f = Franchise.fromJson(
        (map['data'] as Map).cast<String, dynamic>(),
      );
      return _Cached(f, DateTime.now().difference(ts) < _ttl);
    } catch (_) {
      return null;
    }
  }

  List<Franchise> allCachedFranchises() {
    final result = <Franchise>[];
    for (final key in _box.keys) {
      final k = key.toString();
      if (!k.startsWith('f:')) continue;
      final c = _decode(_box.get(k));
      if (c != null) result.add(_withManual(c.franchise));
    }
    return result;
  }


  String? aliasOf(int anilistId) => _box.get('a:al-$anilistId');

  // ── ورودی‌های دستی کاربر ──────────────────────────────────────────
  //
  // وقتی API یک انیمه را در فرنچایز جا می‌اندازد، کاربر می‌تواند آن را
  // دستی اضافه کند. این ورودی‌ها در باکس meta (نه کش فرنچایز) ذخیره
  // می‌شوند تا با پاک شدن کش از بین نروند، و در هر بار خواندن فرنچایز
  // (تازه یا از کش) با [_withManual] ادغام می‌شوند.

  List<Entry> _readManualList(String franchiseId) {
    try {
      final raw = Hive.box<String>(
        Boxes.meta,
      ).get('manual_entries:$franchiseId');
      if (raw == null) return [];
      final items =
          ((jsonDecode(raw) as Map).cast<String, dynamic>()['items'] as List?) ??
          const [];
      return items
          .map((e) => Entry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// همه ورودی‌های دستی یک فرنچایز.
  List<Entry> manualEntries(String franchiseId) => _readManualList(franchiseId);

  /// افزودن دستی یک انیمه به فرنچایز.
  Future<void> addManualEntry(String franchiseId, Entry entry) async {
    final list = _readManualList(franchiseId);
    if (list.any((e) => e.id == entry.id)) return;
    list.add(entry.copyWith(manual: true, isMainStory: true));
    await Hive.box<String>(Boxes.meta).put(
      'manual_entries:$franchiseId',
      jsonEncode({'items': list.map((e) => e.toJson()).toList()}),
    );
  }

  /// حذف یک ورودی دستی از فرنچایز.
  Future<void> removeManualEntry(String franchiseId, String entryId) async {
    final list = _readManualList(franchiseId);
    list.removeWhere((e) => e.id == entryId);
    await Hive.box<String>(Boxes.meta).put(
      'manual_entries:$franchiseId',
      jsonEncode({'items': list.map((e) => e.toJson()).toList()}),
    );
  }

  /// ادغام ورودی‌های دستی کاربر به فرنچایز (بعد از ساخت یا خواندن از کش).
  Franchise _withManual(Franchise f) {
    final manual = _readManualList(f.id);
    if (manual.isEmpty) return f;
    final ids = f.entries.map((e) => e.id).toSet();
    final extra = manual.where((e) => !ids.contains(e.id)).toList();
    if (extra.isEmpty) return f;
    return f.copyWith(entries: [...f.entries, ...extra]);
  }

  /// ساخت Entry کامل از یک نتیجه جست‌وجو (برای افزودن دستی).
  /// null یعنی دیتای کامل پیدا نشد.
  Future<Entry?> resolveManualEntry(AnimeCardData d) async {
    try {
      if (d.anilistId > 0) {
        final media = await _ani.fetchMedia(d.anilistId);
        return Entry.fromAniList(media, isMainStory: true);
      }
      if (d.malId > 0) {
        final media = await _ani.fetchMediaByMal(d.malId);
        if (media != null) {
          return Entry.fromAniList(media, isMainStory: true);
        }
        final detail = await _jikan.fetchAnime(d.malId);
        if (detail != null) return Entry.fromJikanSearch(detail);
      }
    } catch (_) {}
    return null;
  }

  List<Franchise> localSearch(String query) {
    final q = normalizeQuery(query);
    if (q.isEmpty) return const [];
    return allCachedFranchises().where((f) {
      if (normalizeQuery(f.titleFa).contains(q)) return true;
      if (normalizeQuery(f.titleEn).contains(q)) return true;
      return f.entries.any((e) => normalizeQuery(e.title).contains(q));
    }).toList();
  }

  /// جست‌وجوی جهانی دو مرحله‌ای (برای سرعت درک‌شده):
  /// مرحله ۱ فقط AniList است (سریع‌ترین و کامل‌ترین) و مرحله ۲
  /// Jikan + MAL را برای پوشش موارد جامانده اضافه می‌کند.
  /// نتایج تکراری بر اساس malId/anilistId حذف و منبع هر نتیجه مشخص است.
  Future<List<AnimeCardData>> searchRemote(String query) async {
    final p = await searchPrimary(query);
    final out = [...p.items];
    out.addAll((await searchSecondary(query, p.seenAni, p.seenMal)).items);
    return out;
  }

  /// مرحله ۱ جست‌وجو: فقط AniList.
  Future<
    ({
      List<AnimeCardData> items,
      Set<int> seenAni,
      Set<int> seenMal,
      bool ok,
    })
  >
  searchPrimary(String query) async {
    final out = <AnimeCardData>[];
    final seenAni = <int>{};
    final seenMal = <int>{};
    List<Map<String, dynamic>> raw;
    try {
      raw = await _ani.search(query);
    } catch (_) {
      return (items: out, seenAni: seenAni, seenMal: seenMal, ok: false);
    }
    for (final m in raw) {
      if (!_searchFormats.contains(m['format'])) continue;
      final id = m['id'] as int;
      if (!seenAni.add(id)) continue;
      final malId = (m['idMal'] as int?) ?? 0;
      if (malId != 0) seenMal.add(malId);
      final t = (m['title'] ?? {}) as Map;
      final en = (t['english'] ?? t['romaji'] ?? t['native'] ?? '—') as String;
      final avg = m['averageScore'] as int?;
      out.add(
        AnimeCardData(
          anilistId: id,
          malId: malId,
          source: SearchSource.anilist,
          titleFa: persianTitles[id] ?? en,
          titleEn: en,
          cover: (m['coverImage'] as Map?)?['large'] as String?,
          year:
              (m['seasonYear'] as int?) ??
              ((m['startDate'] as Map?)?['year'] as int?),
          score: avg == null ? 0 : avg / 10.0,
        ),
      );
    }
    return (items: out, seenAni: seenAni, seenMal: seenMal, ok: true);
  }

  /// مرحله ۲ جست‌وجو: Jikan + MAL (موازی با هم) برای مواردی که
  /// مرحله ۱ نداشت.
  Future<({List<AnimeCardData> items, bool ok})> searchSecondary(
    String query,
    Set<int> seenAni,
    Set<int> seenMal,
  ) async {
    final out = <AnimeCardData>[];

    Future<List<Map<String, dynamic>>> safe(
      Future<List<Map<String, dynamic>>> f,
    ) async {
      try {
        return await f;
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([
      safe(_jikan.search(query)),
      safe(_mal.search(query)),
    ]);
    var ok = false;

    // Jikan (بدون احراز هویت) — مواردی که AniList نداشت
    if (results[0].isNotEmpty) ok = true;
    for (final m in results[0]) {
      if (out.length >= 24) break;
      final malId = (m['mal_id'] as num?)?.toInt() ?? 0;
      if (malId == 0 || !seenMal.add(malId)) continue;
      final entry = Entry.fromJikanSearch(m);
      out.add(
        AnimeCardData(
          anilistId: 0,
          malId: malId,
          source: SearchSource.jikan,
          titleFa: entry.title,
          titleEn: entry.title,
          cover: entry.cover,
          year: entry.year,
          score: entry.score,
        ),
      );
    }

    // MAL مستقیم — مواردی که هیچ‌کدام نداشتند
    if (results[1].isNotEmpty) ok = true;
    for (final m in results[1]) {
      if (out.length >= 24) break;
      final malId = (m['id'] as num?)?.toInt() ?? 0;
      if (malId == 0 || !seenMal.add(malId)) continue;
      final entry = Entry.fromMalSearch(m);
      out.add(
        AnimeCardData(
          anilistId: 0,
          malId: malId,
          source: SearchSource.mal,
          titleFa: entry.title,
          titleEn: entry.title,
          cover: entry.cover,
          year: null,
          score: 0,
        ),
      );
    }

    return (items: out, ok: ok);
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_exception.dart';
import 'api_gateway.dart';

const String _nodeFields = '''
  id idMal type format status episodes duration averageScore seasonYear
  startDate { year month day }
  nextAiringEpisode { episode airingAt }
  coverImage { large extraLarge }
  title { romaji english native }
''';

final String _mediaByMalQuery =
    '''
query (\$idMal: Int) {
  Media(idMal: \$idMal, type: ANIME) {
    $_nodeFields
    genres
    description(asHtml: false)
    bannerImage
    relations {
      edges {
        relationType(version: 2)
        node { $_nodeFields }
      }
    }
  }
}
''';

final String _mediaQuery =
    '''
query (\$id: Int) {
  Media(id: \$id, type: ANIME) {
    $_nodeFields
    genres
    description(asHtml: false)
    bannerImage
    relations {
      edges {
        relationType(version: 2)
        node { $_nodeFields }
      }
    }
  }
}
''';

final String _searchQuery =
    '''
query (\$search: String, \$perPage: Int) {
  Page(page: 1, perPage: \$perPage) {
    media(search: \$search, type: ANIME, sort: SEARCH_MATCH, isAdult: false) {
      $_nodeFields
    }
  }
}
''';

const String _browseQuery = r'''
query ($perPage: Int, $sort: [MediaSort], $status: MediaStatus,
       $season: MediaSeason, $seasonYear: Int, $format: MediaFormat,
       $formatIn: [MediaFormat], $popularityGreater: Int) {
  Page(page: 1, perPage: $perPage) {
    media(type: ANIME, isAdult: false, sort: $sort, status: $status,
          season: $season, seasonYear: $seasonYear, format: $format,
          format_in: $formatIn, popularity_greater: $popularityGreater) {
      id idMal format episodes averageScore seasonYear
      startDate { year }
      coverImage { large }
      title { romaji english native }
    }
  }
}
''';

class AniListClient {
  AniListClient(this._gw);

  final ApiGateway _gw;
  static final Uri _endpoint = Uri.parse('https://graphql.anilist.co');

  Future<Map<String, dynamic>> fetchMedia(int id) async {
    final data = await _query(
      _mediaQuery,
      {'id': id},
      cacheTtl: const Duration(hours: 6),
    );
    final media = data['Media'];
    if (media == null) {
      throw const ApiException('این انیمه در AniList پیدا نشد.');
    }
    return (media as Map).cast<String, dynamic>();
  }

  /// پیدا کردن مدیای AniList از روی شناسه MAL (برای نگاشت نتایج MAL/Jikan).
  /// اگر پیدا نشود null برمی‌گرداند.
  Future<Map<String, dynamic>?> fetchMediaByMal(int idMal) async {
    try {
      final data = await _query(
        _mediaByMalQuery,
        {'idMal': idMal},
        cacheTtl: const Duration(hours: 12),
      );
      final media = data['Media'];
      if (media == null) return null;
      return (media as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> search(
    String text, {
    int perPage = 20,
  }) async {
    final data = await _query(_searchQuery, {
      'search': text,
      'perPage': perPage,
    }, cacheTtl: const Duration(minutes: 15));
    final list = (data['Page']?['media'] as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> browse({
    List<String> sort = const ['POPULARITY_DESC'],
    String? status,
    String? season,
    int? seasonYear,
    String? format,
    List<String>? formatIn,
    int? popularityGreater,
    int perPage = 15,
  }) async {
    final data = await _query(_browseQuery, {
      'perPage': perPage,
      'sort': sort,
      'status': status,
      'season': season,
      'seasonYear': seasonYear,
      'format': format,
      'formatIn': formatIn,
      'popularityGreater': popularityGreater,
    });
    final list = (data['Page']?['media'] as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<({List<Map<String, dynamic>> items, bool hasNext})> browsePage(
    String key,
    String args, {
    int page = 1,
    int perPage = 15,
  }) async {
    final q =
        '{ Page(page: $page, perPage: $perPage) { pageInfo { hasNextPage } '
        'media(type: ANIME, isAdult: false, $args) '
        '{ id averageScore seasonYear title { romaji english } coverImage { large } } } }';
    final sw = Stopwatch()..start();
    try {
      final data = await _query(q, const {});
      final pageData = data['Page'] as Map?;
      final list = (pageData?['media'] as List?) ?? const [];
      final hasNext =
          ((pageData?['pageInfo'] as Map?)?['hasNextPage'] as bool?) ?? false;
      if (kDebugMode) {
        debugPrint('Home[$key p$page] OK ${sw.elapsedMilliseconds}ms, ${list.length} items');
      }
      return (
        items: list.map((e) => (e as Map).cast<String, dynamic>()).toList(),
        hasNext: hasNext,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Home[$key p$page] FAILED after ${sw.elapsedMilliseconds}ms: ${e.runtimeType}: $e');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> browseSection(
    String key,
    String args, {
    int perPage = 15,
  }) async => (await browsePage(key, args, perPage: perPage)).items;

  /// شخصیت‌های یک انیمه (برای استخر کارت‌های کلکسیونی).
  Future<List<Map<String, dynamic>>> fetchCharacters(
    int mediaId, {
    int perPage = 20,
  }) async {
    const q = r'''
query ($id: Int, $perPage: Int) {
  Media(id: $id, type: ANIME) {
    characters(perPage: $perPage, sort: [ROLE, FAVOURITES_DESC]) {
      edges {
        role
        node { id name { full } image { large } favourites gender }
      }
    }
  }
}
''';
    final data = await _query(
      q,
      {'id': mediaId, 'perPage': perPage},
      cacheTtl: const Duration(days: 3),
    );
    final edges =
        ((data['Media'] as Map?)?['characters'] as Map?)?['edges'] as List? ??
            const [];
    final out = <Map<String, dynamic>>[];
    for (final e in edges) {
      final m = (e as Map).cast<String, dynamic>();
      final node = (m['node'] as Map?)?.cast<String, dynamic>();
      if (node == null) continue;
      out.add({
        'id': node['id'],
        'name': ((node['name'] as Map?)?['full'] as String?) ?? '—',
        'image': ((node['image'] as Map?)?['large'] as String?),
        'role': m['role'],
        'favourites': (node['favourites'] as num?)?.toInt() ?? 0,
        'gender': (node['gender'] as String?) ?? '',
      });
    }
    return out;
  }

  /// برنامه پخش بعدی چند مدیا (برای تقویم هفتگی) — کش کوتاه ۶ ساعته.
  ///
  /// فقط مدیاهایی که قسمت بعدیِ اعلام‌شده دارند در خروجی هستند.
  Future<Map<int, ({int episode, int airingAt})>> fetchAiringSchedule(
    List<int> ids,
  ) async {
    final out = <int, ({int episode, int airingAt})>{};
    if (ids.isEmpty) return out;
    const q = r'''
query ($ids: [Int]) {
  Page(perPage: 50) {
    media(id_in: $ids, type: ANIME) {
      id
      nextAiringEpisode { episode airingAt }
    }
  }
}
''';
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, (i + 50).clamp(0, ids.length));
      try {
        final data = await _query(
          q,
          {'ids': chunk},
          cacheTtl: const Duration(hours: 6),
        );
        final list = (data['Page']?['media'] as List?) ?? const [];
        for (final m in list) {
          final mm = (m as Map).cast<String, dynamic>();
          final id = (mm['id'] as num?)?.toInt();
          final next = mm['nextAiringEpisode'] as Map?;
          if (id == null || next == null) continue;
          final ep = (next['episode'] as num?)?.toInt();
          final at = (next['airingAt'] as num?)?.toInt();
          if (ep == null || at == null) continue;
          out[id] = (episode: ep, airingAt: at);
        }
      } catch (_) {}
    }
    return out;
  }

  /// پیشنهادهای AniList برای یک مدیا («اگه اینو دوست داشتی...»).
  Future<List<Map<String, dynamic>>> fetchRecommendations(
    int mediaId, {
    int perPage = 8,
  }) async {
    const q = r'''
query ($id: Int, $perPage: Int) {
  Media(id: $id, type: ANIME) {
    recommendations(sort: RATING_DESC, perPage: $perPage) {
      nodes {
        rating
        mediaRecommendation {
          id idMal averageScore
          title { romaji english }
          coverImage { large }
        }
      }
    }
  }
}
''';
    try {
      final data = await _query(
        q,
        {'id': mediaId, 'perPage': perPage},
        cacheTtl: const Duration(days: 1),
      );
      final nodes =
          ((data['Media'] as Map?)?['recommendations'] as Map?)?['nodes']
                  as List? ??
              const [];
      return nodes
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// لیست عمومی انیمه‌های یک کاربر (برای ایمپورت). null یعنی پیدا نشد/خصوصی.
  Future<List<Map<String, dynamic>>?> fetchUserAnimeList(
    String username,
  ) async {
    const q = r'''
query ($userName: String) {
  MediaListCollection(userName: $userName, type: ANIME) {
    lists {
      status
      entries {
        score
        progress
        media { id idMal }
      }
    }
  }
}
''';
    try {
      final data = await _query(q, {'userName': username});
      final lists =
          (data['MediaListCollection'] as Map?)?['lists'] as List? ?? const [];
      final out = <Map<String, dynamic>>[];
      for (final l in lists) {
        final lm = (l as Map).cast<String, dynamic>();
        final status = lm['status'] as String?;
        for (final e in (lm['entries'] as List? ?? const [])) {
          final em = (e as Map).cast<String, dynamic>();
          out.add({...em, 'listStatus': status});
        }
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  /// جست‌وجوی پیشرفته با فیلترهای ترکیبی.
  Future<({List<Map<String, dynamic>> items, bool hasNext})> advancedBrowse({
    int page = 1,
    int perPage = 24,
    List<String>? genres,
    int? scoreMin,
    int? scoreMax,
    int? yearMin,
    int? yearMax,
    int? epMin,
    int? epMax,
    String? format,
    String? sort,
  }) async {
    const q = r'''
query ($page: Int, $perPage: Int, $sort: [MediaSort], $genreIn: [String],
       $scoreGreater: Int, $scoreLesser: Int, $yearGreater: Int, $yearLesser: Int,
       $epGreater: Int, $epLesser: Int, $format: MediaFormat) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage }
    media(type: ANIME, isAdult: false, sort: $sort, genre_in: $genreIn,
          averageScore_greater: $scoreGreater, averageScore_lesser: $scoreLesser,
          seasonYear_greater: $yearGreater, seasonYear_lesser: $yearLesser,
          episodes_greater: $epGreater, episodes_lesser: $epLesser,
          format: $format) {
      id idMal format episodes averageScore seasonYear
      startDate { year }
      coverImage { large }
      title { romaji english native }
      studios { nodes { name } }
      genres
    }
  }
}
''';
    final data = await _query(q, {
      'page': page,
      'perPage': perPage,
      'sort': [sort ?? 'POPULARITY_DESC'],
      'genreIn': genres,
      'scoreGreater': scoreMin,
      'scoreLesser': scoreMax,
      'yearGreater': yearMin,
      'yearLesser': yearMax,
      'epGreater': epMin,
      'epLesser': epMax,
      'format': format,
    });
    final pageData = data['Page'] as Map?;
    final list = (pageData?['media'] as List?) ?? const [];
    final hasNext =
        ((pageData?['pageInfo'] as Map?)?['hasNextPage'] as bool?) ?? false;
    return (
      items: list.map((e) => (e as Map).cast<String, dynamic>()).toList(),
      hasNext: hasNext,
    );
  }

  Future<Map<String, dynamic>> _query(
    String q,
    Map<String, dynamic> vars, {
    Duration? cacheTtl,
  }) async {
    final res = await _gw.post(
      ApiHost.anilist,
      _endpoint,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'query': q, 'variables': vars}),
      cacheTtl: cacheTtl,
    );

    Map<String, dynamic>? body;
    try {
      body = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {
      body = null;
    }

    if (res.statusCode == 404) {
      throw const ApiException('این انیمه در AniList پیدا نشد.');
    }
    if (res.statusCode != 200 || body == null || body['errors'] != null) {
      if (kDebugMode) {
        debugPrint('[AniList] error ${res.statusCode}: ${res.body}');
      }
      throw ApiException('خطا از سمت AniList (کد ${res.statusCode}).');
    }
    final data = body['data'];
    if (data == null) throw const ApiException('پاسخ AniList خالی بود.');
    return (data as Map).cast<String, dynamic>();
  }
}

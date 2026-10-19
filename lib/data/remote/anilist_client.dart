import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_exception.dart';
import 'api_gateway.dart';
import '../../core/i18n/lang.dart';

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
      id idMal format episodes averageScore seasonYear countryOfOrigin status
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
    final data = await _query(_mediaQuery, {
      'id': id,
    }, cacheTtl: const Duration(hours: 6));
    final media = data['Media'];
    if (media == null) {
      throw ApiException(tr('this_anime_wasn_t_found_on_anilist'));
    }
    return (media as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> fetchMediaByMal(int idMal) async {
    try {
      final data = await _query(_mediaByMalQuery, {
        'idMal': idMal,
      }, cacheTtl: const Duration(hours: 12));
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
        '{ id averageScore seasonYear status countryOfOrigin title { romaji english } coverImage { large } } } }';
    final sw = Stopwatch()..start();
    try {
      final data = await _query(q, const {});
      final pageData = data['Page'] as Map?;
      final list = (pageData?['media'] as List?) ?? const [];
      final hasNext =
          ((pageData?['pageInfo'] as Map?)?['hasNextPage'] as bool?) ?? false;
      if (kDebugMode) {
        debugPrint(
          'Home[$key p$page] OK ${sw.elapsedMilliseconds}ms, ${list.length} items',
        );
      }
      return (
        items: list.map((e) => (e as Map).cast<String, dynamic>()).toList(),
        hasNext: hasNext,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Home[$key p$page] FAILED after ${sw.elapsedMilliseconds}ms: ${e.runtimeType}: $e',
        );
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> browseSection(
    String key,
    String args, {
    int perPage = 15,
  }) async => (await browsePage(key, args, perPage: perPage)).items;

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
    final data = await _query(q, {
      'id': mediaId,
      'perPage': perPage,
    }, cacheTtl: const Duration(days: 3));
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

  Future<List<Map<String, dynamic>>> fetchWeeklyAiringGuide() async {
    const q = r'''
query ($page: Int, $perPage: Int, $gte: Int, $lte: Int) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage }
    airingSchedules(airingAt_greater: $gte, airingAt_lesser: $lte, sort: TIME) {
      airingAt
      episode
      media {
        id idMal averageScore countryOfOrigin
        title { romaji english native }
        coverImage { large }
      }
    }
  }
}
''';
    final now = (DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 3600) * 3600;
    final out = <Map<String, dynamic>>[];
    final seen = <int>{};
    for (var page = 1; page <= 3; page++) {
      Map<String, dynamic> data;
      try {
        data = await _query(q, {
          'page': page,
          'perPage': 50,
          'gte': now,
          'lte': now + 7 * 86400,
        }, cacheTtl: const Duration(hours: 6));
      } catch (_) {
        break;
      }
      final list = (data['Page']?['airingSchedules'] as List?) ?? const [];
      if (list.isEmpty) break;
      for (final s in list) {
        final sm = (s as Map).cast<String, dynamic>();
        final media = (sm['media'] as Map?)?.cast<String, dynamic>();
        if (media == null) continue;
        final id = (media['id'] as num?)?.toInt();
        if (id == null || !seen.add(id)) continue;
        out.add({
          'airingAt': (sm['airingAt'] as num?)?.toInt() ?? 0,
          'episode': (sm['episode'] as num?)?.toInt() ?? 0,
          'media': media,
        });
      }
      final hasNext =
          (data['Page']?['pageInfo']?['hasNextPage'] as bool?) ?? false;
      if (!hasNext) break;
    }
    return out;
  }

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
      final data = await _query(q, {
        'id': mediaId,
        'perPage': perPage,
      }, cacheTtl: const Duration(days: 1));
      final nodes =
          ((data['Media'] as Map?)?['recommendations'] as Map?)?['nodes']
              as List? ??
          const [];
      return nodes.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// لیست انیمه‌ی کاربر.
  ///
  /// * برمی‌گرداند null فقط وقتی کاربر وجود ندارد یا لیستش خصوصی است
  ///   (AniList در این حالت MediaListCollection را null می‌دهد).
  /// * خطاهای شبکه/سرور به‌صورت [ApiException] پرتاب می‌شوند تا پیام
  ///   واقعی («عدم اتصال» و...) به کاربر برسد، نه پیام گمراه‌کننده‌ی
  ///   «کاربر پیدا نشد».
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
    final data = await _query(q, {'userName': username});
    final coll = data['MediaListCollection'] as Map?;
    if (coll == null) return null;
    final lists = coll['lists'] as List? ?? const [];
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
  }

  Future<({List<Map<String, dynamic>> items, bool hasNext})> advancedBrowse({
    int page = 1,
    int perPage = 24,
    String? query,
    List<String>? genres,
    List<String>? genresExclude,
    int? scoreMin,
    int? scoreMax,
    int? yearMin,
    int? yearMax,
    int? seasonYear,
    String? season,
    String? status,
    int? epMin,
    int? epMax,
    String? format,
    String? sort,
  }) async {
    const q = r'''
query ($page: Int, $perPage: Int, $sort: [MediaSort], $genreIn: [String],
       $genreNotIn: [String], $scoreGreater: Int, $scoreLesser: Int,
       $yearGreater: Int, $yearLesser: Int, $seasonYear: Int, $season: MediaSeason,
       $status: MediaStatus, $epGreater: Int, $epLesser: Int,
       $format: MediaFormat, $search: String) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage }
    media(type: ANIME, isAdult: false, sort: $sort, genre_in: $genreIn,
          genre_not_in: $genreNotIn, averageScore_greater: $scoreGreater,
          averageScore_lesser: $scoreLesser, seasonYear_greater: $yearGreater,
          seasonYear_lesser: $yearLesser, seasonYear: $seasonYear, season: $season,
          status: $status, episodes_greater: $epGreater, episodes_lesser: $epLesser,
          format: $format, search: $search) {
      id idMal format episodes averageScore seasonYear status
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
      'search': query?.trim().isEmpty ?? true ? null : query!.trim(),
      'genreIn': genres,
      'genreNotIn': genresExclude,
      'scoreGreater': scoreMin,
      'scoreLesser': scoreMax,
      'yearGreater': yearMin,
      'yearLesser': yearMax,
      'seasonYear': seasonYear,
      'season': season,
      'status': status,
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
      throw ApiException(tr('this_anime_wasn_t_found_on_anilist'));
    }
    if (res.statusCode != 200 || body == null || body['errors'] != null) {
      if (kDebugMode) {
        debugPrint('[AniList] error ${res.statusCode}: ${res.body}');
      }
      throw ApiException(tr('anilist_error_code', [res.statusCode]));
    }
    final data = body['data'];
    if (data == null) {
      throw ApiException(tr('anilist_returned_an_empty_response'));
    }
    return (data as Map).cast<String, dynamic>();
  }
}

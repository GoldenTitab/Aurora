import '../../core/i18n/lang.dart';

enum EntryType { series, movie, ova, special }

extension EntryTypeX on EntryType {
  String get labelFa {
    switch (this) {
      case EntryType.series:
        return tr('tv_series');
      case EntryType.movie:
        return tr('movie_2');
      case EntryType.ova:
        return 'OVA';
      case EntryType.special:
        return tr('special');
    }
  }

  static EntryType fromAniListFormat(String? format) {
    switch (format) {
      case 'TV':
      case 'TV_SHORT':
      case 'ONA':
        return EntryType.series;
      case 'MOVIE':
        return EntryType.movie;
      case 'OVA':
        return EntryType.ova;
      default:
        return EntryType.special;
    }
  }
}

enum ReleaseState { announced, airing, released, unknown }

extension ReleaseStateX on ReleaseState {
  String get labelFa {
    switch (this) {
      case ReleaseState.announced:
        return tr('announced');
      case ReleaseState.airing:
        return tr('airing');
      case ReleaseState.released:
        return tr('released');
      case ReleaseState.unknown:
        return tr('unknown');
    }
  }

  bool get excludedFromProgress => this == ReleaseState.announced;
}

class Entry {
  final String id;
  final int anilistId;
  final int? malId;
  final EntryType type;
  final String title;
  final int episodes;
  final double score;
  final bool isMainStory;
  final int? year;
  final String? cover;

  final String? status;

  final String? startDate;

  final int? nextEpisode;
  final int? nextAiringAt;

  final int durationMin;

  final String? relationType;

  final String? parentEntryId;

  final bool manual;

  const Entry({
    required this.id,
    required this.anilistId,
    this.malId,
    required this.type,
    required this.title,
    required this.episodes,
    required this.score,
    required this.isMainStory,
    this.year,
    this.cover,
    this.status,
    this.startDate,
    this.nextEpisode,
    this.nextAiringAt,
    this.durationMin = 24,
    this.relationType,
    this.parentEntryId,
    this.manual = false,
  });

  factory Entry.fromAniList(
    Map<String, dynamic> m, {
    required bool isMainStory,
    String? relationType,
    String? parentEntryId,
  }) {
    final titleMap = (m['title'] ?? {}) as Map;
    final type = EntryTypeX.fromAniListFormat(m['format'] as String?);
    final eps = m['episodes'] as int?;
    final avg = m['averageScore'] as int?;
    final id = m['id'] as int;
    final next = m['nextAiringEpisode'] as Map?;
    final dur = m['duration'] as int?;

    return Entry(
      id: 'al-$id',
      anilistId: id,
      malId: m['idMal'] as int?,
      type: type,
      title:
          (titleMap['english'] ??
                  titleMap['romaji'] ??
                  titleMap['native'] ??
                  '—')
              as String,
      episodes: eps ?? (type == EntryType.movie ? 1 : 0),
      score: avg == null ? 0 : avg / 10.0,
      isMainStory: isMainStory,
      year:
          (m['seasonYear'] as int?) ??
          ((m['startDate'] as Map?)?['year'] as int?),
      cover: (m['coverImage'] as Map?)?['large'] as String?,
      status: m['status'] as String?,
      startDate: _formatStartDate(m['startDate'] as Map?),
      nextEpisode: next?['episode'] as int?,
      nextAiringAt: next?['airingAt'] as int?,
      durationMin: dur != null && dur > 0
          ? dur
          : (type == EntryType.movie ? 100 : 24),
      relationType: relationType,
      parentEntryId: parentEntryId,
    );
  }

  factory Entry.fromMalSearch(Map<String, dynamic> m) {
    final id = (m['id'] as num).toInt();
    final pics = m['main_picture'] as Map?;
    return Entry(
      id: 'mal-$id',
      anilistId: 0,
      malId: id,
      type: _malType(m['media_type'] as String?),
      title: (m['title'] ?? '—') as String,
      episodes: (m['num_episodes'] as num?)?.toInt() ?? 0,
      score: 0,
      isMainStory: true,
      cover: pics?['large'] as String? ?? pics?['medium'] as String?,
      status: _malStatus(m['status'] as String?),
    );
  }

  factory Entry.fromJikanSearch(Map<String, dynamic> m) {
    final id = (m['mal_id'] as num).toInt();
    final images = m['images'] as Map?;
    final jpg = images?['jpg'] as Map?;
    final titles = (m['titles'] as List?) ?? const [];
    String title = '—';
    for (final t in titles) {
      final tm = (t as Map).cast<String, dynamic>();
      if (tm['type'] == 'English' && (tm['title'] as String).isNotEmpty) {
        title = tm['title'] as String;
        break;
      }
    }
    if (title == '—') {
      for (final t in titles) {
        final tm = (t as Map).cast<String, dynamic>();
        if (tm['type'] == 'Default' && (tm['title'] as String).isNotEmpty) {
          title = tm['title'] as String;
          break;
        }
      }
    }
    return Entry(
      id: 'mal-$id',
      anilistId: 0,
      malId: id,
      type: _jikanType(m['type'] as String?),
      title: title,
      episodes: (m['episodes'] as num?)?.toInt() ?? 0,
      score: ((m['score'] as num?) ?? 0).toDouble(),
      isMainStory: true,
      year: (m['year'] as num?)?.toInt(),
      cover: jpg?['large_image_url'] as String?,
      status: _jikanStatus(m['status'] as String?),
      durationMin: _parseJikanDuration(m['duration'] as String?),
    );
  }

  static EntryType _malType(String? t) {
    switch (t) {
      case 'tv':
      case 'ona':
        return EntryType.series;
      case 'movie':
        return EntryType.movie;
      case 'ova':
        return EntryType.ova;
      default:
        return EntryType.special;
    }
  }

  static EntryType _jikanType(String? t) {
    switch (t) {
      case 'TV':
      case 'ONA':
        return EntryType.series;
      case 'Movie':
        return EntryType.movie;
      case 'OVA':
        return EntryType.ova;
      default:
        return EntryType.special;
    }
  }

  static String? _malStatus(String? s) {
    switch (s) {
      case 'finished_airing':
        return 'FINISHED';
      case 'currently_airing':
        return 'RELEASING';
      case 'not_yet_aired':
        return 'NOT_YET_RELEASED';
      default:
        return null;
    }
  }

  static String? _jikanStatus(String? s) {
    if (s == null) return null;
    if (s.startsWith('Finished')) return 'FINISHED';
    if (s.startsWith('Currently')) return 'RELEASING';
    if (s.startsWith('Not yet')) return 'NOT_YET_RELEASED';
    return null;
  }

  static int _parseJikanDuration(String? d) {
    if (d == null) return 24;
    final m = RegExp(r'(\d+)\s*min').firstMatch(d);
    final min = m == null ? null : int.tryParse(m.group(1)!);
    if (min == null || min <= 0) return 24;
    return min;
  }

  static String? _formatStartDate(Map? d) {
    final y = d?['year'] as int?;
    if (y == null) return null;
    final mo = d?['month'] as int?;
    if (mo == null) return '$y';
    final day = d?['day'] as int?;
    final mm = mo.toString().padLeft(2, '0');
    if (day == null) return '$y-$mm';
    return '$y-$mm-${day.toString().padLeft(2, '0')}';
  }

  Entry copyWith({
    String? id,
    int? anilistId,
    int? malId,
    EntryType? type,
    String? title,
    int? episodes,
    double? score,
    bool? isMainStory,
    int? year,
    String? cover,
    String? status,
    String? startDate,
    int? nextEpisode,
    int? nextAiringAt,
    int? durationMin,
    String? relationType,
    String? parentEntryId,
    bool? manual,
  }) {
    return Entry(
      id: id ?? this.id,
      anilistId: anilistId ?? this.anilistId,
      malId: malId ?? this.malId,
      type: type ?? this.type,
      title: title ?? this.title,
      episodes: episodes ?? this.episodes,
      score: score ?? this.score,
      isMainStory: isMainStory ?? this.isMainStory,
      year: year ?? this.year,
      cover: cover ?? this.cover,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      nextEpisode: nextEpisode ?? this.nextEpisode,
      nextAiringAt: nextAiringAt ?? this.nextAiringAt,
      durationMin: durationMin ?? this.durationMin,
      relationType: relationType ?? this.relationType,
      parentEntryId: parentEntryId ?? this.parentEntryId,
      manual: manual ?? this.manual,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'anilistId': anilistId,
    'malId': malId,
    'type': type.name,
    'title': title,
    'episodes': episodes,
    'score': score,
    'isMainStory': isMainStory,
    'year': year,
    'cover': cover,
    'status': status,
    'startDate': startDate,
    'nextEpisode': nextEpisode,
    'nextAiringAt': nextAiringAt,
    'durationMin': durationMin,
    'relationType': relationType,
    'parentEntryId': parentEntryId,
    'manual': manual,
  };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    anilistId: (j['anilistId'] as num).toInt(),
    malId: (j['malId'] as num?)?.toInt(),
    type: EntryType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => EntryType.special,
    ),
    title: j['title'] as String,
    episodes: (j['episodes'] as num).toInt(),
    score: (j['score'] as num).toDouble(),
    isMainStory: j['isMainStory'] as bool,
    year: (j['year'] as num?)?.toInt(),
    cover: j['cover'] as String?,
    status: j['status'] as String?,
    startDate: j['startDate'] as String?,
    nextEpisode: (j['nextEpisode'] as num?)?.toInt(),
    nextAiringAt: (j['nextAiringAt'] as num?)?.toInt(),
    durationMin: (j['durationMin'] as num?)?.toInt() ?? 24,
    relationType: j['relationType'] as String?,
    parentEntryId: j['parentEntryId'] as String?,
    manual: (j['manual'] as bool?) ?? false,
  );

  ReleaseState get releaseState {
    switch (status) {
      case 'NOT_YET_RELEASED':
        return ReleaseState.announced;
      case 'RELEASING':
      case 'HIATUS':
        return ReleaseState.airing;
      case 'FINISHED':
      case 'CANCELLED':
        return ReleaseState.released;
      default:
        return ReleaseState.unknown;
    }
  }

  int? airedEpisodes({DateTime? now}) {
    final t = now ?? DateTime.now();
    int? result;
    switch (releaseState) {
      case ReleaseState.announced:
        result = 0;
      case ReleaseState.released:
        result = episodes > 0 ? episodes : null;
      case ReleaseState.airing:
        final next = nextEpisode;
        final at = nextAiringAt;
        if (next == null) return null;
        result = next - 1;
        if (at != null) {
          final airAt = DateTime.fromMillisecondsSinceEpoch(at * 1000);
          if (!t.isBefore(airAt)) {
            if (t.difference(airAt) > const Duration(days: 7)) return null;
            result = next;
          }
        }
      case ReleaseState.unknown:
        return null;
    }
    if (result != null && episodes > 0 && result > episodes) result = episodes;
    return result;
  }
}

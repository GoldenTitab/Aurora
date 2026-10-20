import 'entry.dart';

class Franchise {
  final String id;
  final int anilistId;
  final int? malId;
  final String titleFa;
  final String titleEn;
  final String cover;
  final String? banner;
  final double score;
  final double? malScore;
  final int year;
  final List<String> genres;
  final String synopsis;
  final List<Entry> entries;

  const Franchise({
    required this.id,
    required this.anilistId,
    this.malId,
    required this.titleFa,
    required this.titleEn,
    required this.cover,
    this.banner,
    required this.score,
    this.malScore,
    required this.year,
    required this.genres,
    required this.synopsis,
    required this.entries,
  });

  List<Entry> get mainEntries =>
      entries.where((e) => e.isMainStory).toList(growable: false);

  List<Entry> get relatedEntries =>
      entries.where((e) => !e.isMainStory).toList(growable: false);

  int get totalEpisodes => entries.fold(0, (sum, e) => sum + e.episodes);

  Franchise copyWith({
    String? titleFa,
    double? malScore,
    List<Entry>? entries,
    String? cover,
    String? banner,
    String? synopsis,
    List<String>? genres,
  }) => Franchise(
    id: id,
    anilistId: anilistId,
    malId: malId,
    titleFa: titleFa ?? this.titleFa,
    titleEn: titleEn,
    cover: cover ?? this.cover,
    banner: banner ?? this.banner,
    score: score,
    malScore: malScore ?? this.malScore,
    year: year,
    genres: genres ?? this.genres,
    synopsis: synopsis ?? this.synopsis,
    entries: entries ?? this.entries,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'anilistId': anilistId,
    'malId': malId,
    'titleFa': titleFa,
    'titleEn': titleEn,
    'cover': cover,
    'banner': banner,
    'score': score,
    'malScore': malScore,
    'year': year,
    'genres': genres,
    'synopsis': synopsis,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory Franchise.fromJson(Map<String, dynamic> j) => Franchise(
    id: j['id'] as String,
    anilistId: (j['anilistId'] as num).toInt(),
    malId: (j['malId'] as num?)?.toInt(),
    titleFa: j['titleFa'] as String,
    titleEn: j['titleEn'] as String,
    cover: j['cover'] as String,
    banner: j['banner'] as String?,
    score: (j['score'] as num).toDouble(),
    malScore: (j['malScore'] as num?)?.toDouble(),
    year: (j['year'] as num).toInt(),
    genres: List<String>.from(j['genres'] as List),
    synopsis: j['synopsis'] as String,
    entries: (j['entries'] as List)
        .map((e) => Entry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

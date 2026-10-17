import 'franchise.dart';
import '../../core/i18n/lang.dart';

/// منشأ نتیجه جست‌وجو (برای «جست‌وجوی جهانی بین دو API»).
enum SearchSource { local, anilist, mal, jikan }

extension SearchSourceX on SearchSource {
  String get labelFa {
    switch (this) {
      case SearchSource.local:
        return tr('library');
      case SearchSource.anilist:
        return 'AniList';
      case SearchSource.mal:
        return 'MAL';
      case SearchSource.jikan:
        return 'Jikan';
    }
  }
}

class AnimeCardData {
  /// شناسه AniList؛ اگر ۰ باشد یعنی فقط در MAL/Jikan پیدا شده و هنوز
  /// به AniList نگاشت نشده است.
  final int anilistId;

  /// شناسه MAL (۰ یعنی نامشخص).
  final int malId;

  final SearchSource source;
  final String titleFa;
  final String titleEn;
  final String? cover;
  final int? year;
  final double score;

  /// کد کشور سازنده (ISO مثل JP/CN/KR)؛ null یعنی نامشخص.
  final String? countryOfOrigin;

  /// وضعیت پخش در AniList (مثل FINISHED/RELEASING)؛ null یعنی نامشخص.
  final String? status;

  const AnimeCardData({
    required this.anilistId,
    this.malId = 0,
    this.source = SearchSource.anilist,
    required this.titleFa,
    required this.titleEn,
    this.cover,
    this.year,
    required this.score,
    this.countryOfOrigin,
    this.status,
  });

  /// آیا این کارت مستقیماً به صفحه فرنچایز می‌رود؟
  bool get resolvable => anilistId > 0;

  factory AnimeCardData.fromFranchise(Franchise f) => AnimeCardData(
    anilistId: f.anilistId,
    malId: f.malId ?? 0,
    source: SearchSource.local,
    titleFa: f.titleFa,
    titleEn: f.titleEn,
    cover: f.cover,
    year: f.year == 0 ? null : f.year,
    score: f.score,
  );
}

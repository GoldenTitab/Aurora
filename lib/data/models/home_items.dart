// مدل‌های سبک برای ویجت‌های صفحه خانه (ادامه تماشا، قسمت‌های جدید، تقویم پخش).

class ContinueWatchItem {
  final String entryId;
  final int franchiseAnilistId;
  final String franchiseTitleFa;
  final String entryTitle;
  final String? cover;
  final int lastEpisode;
  final int totalEpisodes;
  final int updatedAtMs;

  const ContinueWatchItem({
    required this.entryId,
    required this.franchiseAnilistId,
    required this.franchiseTitleFa,
    required this.entryTitle,
    this.cover,
    required this.lastEpisode,
    required this.totalEpisodes,
    required this.updatedAtMs,
  });

  double get progressRatio =>
      totalEpisodes <= 0 ? 0 : lastEpisode / totalEpisodes;
}

class NewEpisodeItem {
  final String entryId;
  final int franchiseAnilistId;
  final String franchiseTitleFa;
  final String entryTitle;
  final String? cover;

  /// تعداد قسمت‌های پخش‌شده‌ای که هنوز دیده نشده‌اند.
  final int newCount;

  /// آخرین قسمت پخش‌شده.
  final int latestEpisode;

  /// زمان پخش آخرین قسمت (epoch seconds)؛ برای مرتب‌سازی و dismiss.
  final int airingAt;

  const NewEpisodeItem({
    required this.entryId,
    required this.franchiseAnilistId,
    required this.franchiseTitleFa,
    required this.entryTitle,
    this.cover,
    required this.newCount,
    required this.latestEpisode,
    required this.airingAt,
  });
}

class AiringEntry {
  final String entryId;
  final int franchiseAnilistId;
  final String franchiseTitleFa;
  final String entryTitle;
  final String? cover;
  final int episode;
  final int airingAt;

  const AiringEntry({
    required this.entryId,
    required this.franchiseAnilistId,
    required this.franchiseTitleFa,
    required this.entryTitle,
    this.cover,
    required this.episode,
    required this.airingAt,
  });
}

class AiringDay {
  /// 1=دوشنبه ... 7=یکشنبه (مطابق DateTime.weekday)
  final int weekday;
  final List<AiringEntry> items;

  const AiringDay({required this.weekday, required this.items});

  static const List<String> weekdayFa = [
    '',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];

  String get labelFa =>
      weekday >= 1 && weekday <= 7 ? weekdayFa[weekday] : 'نامشخص';
}

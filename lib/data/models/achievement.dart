class AchievementDef {
  final String id;
  final String titleFa;
  final String descFa;
  final String categoryFa;
  final int xp;
  final int coins;

  final bool Function(AchCtx) test;

  /// اچیومنت مخفی: تا باز نشه اسم و شرطش معلوم نیست.
  final bool hidden;

  /// پیشرفت ۰ تا ۱ برای اچیومنت‌های مرحله‌ای؛ null یعنی قابل‌اندازه‌گیری نیست.
  final double Function(AchCtx)? progress;

  const AchievementDef({
    required this.id,
    required this.titleFa,
    required this.descFa,
    required this.categoryFa,
    required this.xp,
    required this.coins,
    required this.test,
    this.hidden = false,
    this.progress,
  });

  /// پیشرفت فعلی (۰ تا ۱)؛ اگه قابل‌اندازه‌گیری نباشه، بازشده=۱ و قفل=۰.
  double progressOf(AchCtx ctx, bool unlocked) {
    if (unlocked) return 1.0;
    final f = progress;
    if (f == null) return 0.0;
    try {
      return f(ctx).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }
}

class AchCtx {
  final int episodesWatched;
  final int franchisesStarted;
  final int franchisesCompleted;
  final int distinctGenres;
  final int streak;
  final int ratingsGiven;
  final int notesWritten;
  final int franchiseRatings;
  final int cardsOwned;
  final Map<String, int> cardsPerRarity;
  final int packsOpened;
  final int coinsEarned;
  final int missionsDone;
  final int level;
  final int watchMinutes;
  final bool importDone;
  final int checkins;
  final int xpTotal;

  const AchCtx({
    this.episodesWatched = 0,
    this.franchisesStarted = 0,
    this.franchisesCompleted = 0,
    this.distinctGenres = 0,
    this.streak = 0,
    this.ratingsGiven = 0,
    this.notesWritten = 0,
    this.franchiseRatings = 0,
    this.cardsOwned = 0,
    this.cardsPerRarity = const {},
    this.packsOpened = 0,
    this.coinsEarned = 0,
    this.missionsDone = 0,
    this.level = 0,
    this.watchMinutes = 0,
    this.importDone = false,
    this.checkins = 0,
    this.xpTotal = 0,
  });
}

/// تعریف یک اچیومنت.
class AchievementDef {
  final String id;
  final String titleFa;
  final String descFa;
  final String categoryFa;
  final int xp;
  final int coins;

  /// شرط باز شدن؛ روی اسنپ‌شات آماری ارزیابی می‌شود.
  final bool Function(AchCtx) test;

  const AchievementDef({
    required this.id,
    required this.titleFa,
    required this.descFa,
    required this.categoryFa,
    required this.xp,
    required this.coins,
    required this.test,
  });
}

/// اسنپ‌شات آماری برای ارزیابی اچیومنت‌ها.
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

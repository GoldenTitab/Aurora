// آمار تماشای کتابخانه (داشبورد آماری).

class FranchiseStat {
  final String franchiseId;
  final int anilistId;
  final String titleFa;
  final String? cover;
  final int watchedEpisodes;
  final int watchedMinutes;

  const FranchiseStat({
    required this.franchiseId,
    required this.anilistId,
    required this.titleFa,
    this.cover,
    required this.watchedEpisodes,
    required this.watchedMinutes,
  });
}

class LibraryStats {
  final int started;
  final int completed;
  final int dropped;
  final int onHold;
  final int planToWatch;
  final int totalWatchedEpisodes;
  final int totalWatchedMinutes;
  final int totalRemainingMinutes;
  final int totalFranchises;
  final List<FranchiseStat> topFranchises;

  const LibraryStats({
    required this.started,
    required this.completed,
    required this.dropped,
    required this.onHold,
    required this.planToWatch,
    required this.totalWatchedEpisodes,
    required this.totalWatchedMinutes,
    required this.totalRemainingMinutes,
    required this.totalFranchises,
    required this.topFranchises,
  });

  int get tracked => started + completed + dropped + onHold + planToWatch;

  /// قالب‌بندی «X ساعت» یا «Y روز و Z ساعت».
  static String formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes دقیقه';
    final h = minutes ~/ 60;
    if (h < 24) return '$h ساعت';
    final d = h ~/ 24;
    final rh = h % 24;
    if (rh == 0) return '$d روز';
    return '$d روز و $rh ساعت';
  }
}

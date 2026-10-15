import 'dart:math';

import '../models/franchise.dart';
import '../models/watch_status.dart';

class Suggestion {
  final Franchise franchise;
  final int score;
  final String reasonFa;

  const Suggestion({
    required this.franchise,
    required this.score,
    required this.reasonFa,
  });
}

class SuggestionEngine {
  SuggestionEngine({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  /// پیشنهاد هوشمند از کتابخانهٔ کاربر (بدون سرویس خارجی).
  Suggestion? pick({
    required List<Franchise> franchises,
    required Map<String, WatchStatus> statuses,
    required Set<String> recentFranchiseIds,
    required Map<String, int> recentGenreCounts,
  }) {
    if (franchises.isEmpty) return null;

    final loved = <String, int>{};
    final disliked = <String, int>{};

    for (final f in franchises) {
      final statusList = f.entries
          .map((e) => statuses[e.id])
          .whereType<WatchStatus>()
          .toList();
      if (statusList.isEmpty) continue;

      final completed = statusList.contains(WatchStatus.completed);
      final watching = statusList.contains(WatchStatus.watching);
      final dropped = statusList.contains(WatchStatus.dropped);
      final hold = statusList.contains(WatchStatus.onHold);

      if (completed || watching) {
        for (final g in f.genres) {
          loved[g] = (loved[g] ?? 0) + 2;
        }
      } else if (dropped) {
        for (final g in f.genres) {
          disliked[g] = (disliked[g] ?? 0) + 3;
        }
      } else if (hold) {
        for (final g in f.genres) {
          loved[g] = (loved[g] ?? 0) + 1;
        }
      }
    }

    final candidates = <_Candidate>[];
    for (final f in franchises) {
      if (recentFranchiseIds.contains(f.id)) continue;

      final statusList = f.entries
          .map((e) => statuses[e.id])
          .whereType<WatchStatus>()
          .toList();

      if (statusList.isNotEmpty &&
          statusList.every((s) => s == WatchStatus.completed)) {
        continue;
      }
      if (statusList.contains(WatchStatus.dropped) &&
          !statusList.contains(WatchStatus.planToWatch) &&
          !statusList.contains(WatchStatus.watching)) {
        continue;
      }

      var score = 0;
      score += (f.score * 4).round();

      if (statusList.contains(WatchStatus.planToWatch)) score += 40;
      if (statusList.contains(WatchStatus.watching)) score += 30;
      if (statusList.contains(WatchStatus.onHold)) score -= 5;
      if (statusList.isEmpty) score += 10;

      for (final g in f.genres) {
        score += (loved[g] ?? 0) * 4;
        score -= (disliked[g] ?? 0) * 6;
        score -= (recentGenreCounts[g] ?? 0) * 8;
      }

      score += _rng.nextInt(15);
      candidates.add(_Candidate(f, score));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final top = candidates.take(5).toList();
    final picked = top[_rng.nextInt(top.length)];

    return Suggestion(
      franchise: picked.franchise,
      score: picked.score,
      reasonFa: _reason(picked.franchise, loved),
    );
  }

  String _reason(Franchise f, Map<String, int> loved) {
    final matched = f.genres.where((g) => (loved[g] ?? 0) >= 4).toList();
    if (matched.isNotEmpty) {
      return 'چون ${matched.take(2).join(' و ')} دوست داری.';
    }
    if (f.score >= 8) return 'امتیاز بالای ${f.score.toStringAsFixed(1)}.';
    return 'برای تنوع انتخاب شد.';
  }
}

class _Candidate {
  final Franchise franchise;
  final int score;
  _Candidate(this.franchise, this.score);
}

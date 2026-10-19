import 'dart:math';

import '../../core/i18n/lang.dart';
import '../models/anime_card_data.dart';

class Suggestion {
  final AnimeCardData data;
  final int score;

  /// مسیر موتور (حالت سلیقه‌ای): کلید منبع — دلیل تنبل ساخته می‌شود.
  final String sourceKey;

  /// حالت‌های دیگر پیکر: کلید دلیل + کلیدهای آرگومان.
  final String reasonKey;
  final List<String> reasonArgKeys;

  const Suggestion({
    required this.data,
    required this.score,
    this.sourceKey = '',
    this.reasonKey = '',
    this.reasonArgKeys = const [],
  });

  /// تنبل محاسبه می‌شود تا همیشه زبان فعلی اپ را دنبال کند.
  String get reasonFa {
    if (reasonKey.isNotEmpty) {
      return tr(reasonKey, [for (final k in reasonArgKeys) tr(k)]);
    }
    if (sourceKey.isEmpty) return '';
    final src = tr(sourceKey);
    if (data.score >= 8.5) {
      return tr('high_score_of_from', [data.score.toStringAsFixed(1), src]);
    }
    return tr('picked_from_for_variety', [src]);
  }

  String get historyId =>
      data.anilistId > 0 ? 'al-${data.anilistId}' : 'mal-${data.malId}';
}

class SuggestionEngine {
  SuggestionEngine({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  Suggestion? pickExternal({
    required List<({AnimeCardData data, String sourceFa})> candidates,
    required Set<String> excludedEntryIds,
    required Set<String> recentIds,
  }) {
    final seen = <String>{};
    final pool = <({AnimeCardData data, String sourceFa})>[];
    for (final c in candidates) {
      final d = c.data;
      final key = d.anilistId > 0 ? 'al-${d.anilistId}' : 'mal-${d.malId}';
      if (!seen.add(key)) continue;
      if (excludedEntryIds.contains(key)) continue;
      if (recentIds.contains(key)) continue;
      pool.add(c);
    }
    if (pool.isEmpty) return null;

    final scored = <_Candidate>[];
    for (final c in pool) {
      var score = (c.data.score * 4).round();
      switch (c.sourceFa) {
        case 'top':
          score += 15;
        case 'underrated':
          score += 10;
        case 'seasonal':
          score += 5;
      }
      score += _rng.nextInt(15);
      scored.add(_Candidate(c.data, c.sourceFa, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(5).toList();
    final picked = top[_rng.nextInt(top.length)];

    return Suggestion(
      data: picked.data,
      score: picked.score,
      sourceKey: picked.sourceFa,
    );
  }
}

class _Candidate {
  final AnimeCardData data;
  final String sourceFa;
  final int score;
  _Candidate(this.data, this.sourceFa, this.score);
}

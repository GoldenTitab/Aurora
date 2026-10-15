import 'dart:math';

import '../models/anime_card_data.dart';

/// یک پیشنهاد از بیرون «لیست من».
class Suggestion {
  final AnimeCardData data;
  final int score;
  final String reasonFa;

  const Suggestion({
    required this.data,
    required this.score,
    required this.reasonFa,
  });

  /// شناسه برای تاریخچه پیشنهادها (تکراری پیشنهاد نشود).
  String get historyId => data.anilistId > 0
      ? 'al-${data.anilistId}'
      : 'mal-${data.malId}';
}

/// موتور پیشنهاد: از انیمه‌های بیرون «لیست من» (بخش‌های کشف) انتخاب می‌کند.
///
/// هیچ‌وقت چیزی که در لیست کاربر هست (وضعیت ثبت‌شده) یا در کتابخانه‌اش
/// (فرنچایز کش‌شده) هست را پیشنهاد نمی‌دهد.
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
      // وزن بخش منبع: ترندها و برترین‌های هفته تازه‌ترند.
      switch (c.sourceFa) {
        case 'ترند':
          score += 15;
        case 'هفته':
          score += 10;
        case 'فصل':
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
      reasonFa: _reason(picked),
    );
  }

  String _reason(_Candidate c) {
    final d = c.data;
    if (d.score >= 8.5) {
      return 'امتیاز بالای ${d.score.toStringAsFixed(1)} از «${c.sourceFa}».';
    }
    return 'از «${c.sourceFa}» برای تنوع انتخاب شد.';
  }
}

class _Candidate {
  final AnimeCardData data;
  final String sourceFa;
  final int score;
  _Candidate(this.data, this.sourceFa, this.score);
}

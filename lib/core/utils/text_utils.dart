import 'dart:ui' show TextDirection;

String stripHtml(String? input) {
  if (input == null) return '';
  return input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&#039;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

final RegExp _persianChars = RegExp(r'[\u0600-\u06FF]');

bool hasPersian(String s) => _persianChars.hasMatch(s);

TextDirection dirFor(String s) =>
    hasPersian(s) ? TextDirection.rtl : TextDirection.ltr;

String normalizeQuery(String s) => s
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('\u200c', ' ')
    .trim()
    .toLowerCase();

/// نرمال‌سازی عنوان برای مقایسه: حذف علائم، فصل‌ها و کلمات رایج.
String normalizeTitle(String s) {
  var t = normalizeQuery(s);
  t = t.replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF ]'), ' ');
  t = t
      .replaceAll(RegExp(r'\b(season|s|part| cour|movie|ova|ona|special)\b'), ' ')
      .replaceAll(RegExp(r'\b\d+(st|nd|rd|th)?\b'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// شباهت دو عنوان بین ۰ تا ۱ (ترکیب توکن مشترک و فاصله لونشتاین).
double titleSimilarity(String a, String b) {
  final na = normalizeTitle(a);
  final nb = normalizeTitle(b);
  if (na.isEmpty || nb.isEmpty) return 0;
  if (na == nb) return 1;

  final ta = na.split(' ').where((w) => w.length > 1).toSet();
  final tb = nb.split(' ').where((w) => w.length > 1).toSet();
  double tokenScore = 0;
  if (ta.isNotEmpty && tb.isNotEmpty) {
    final inter = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    tokenScore = union == 0 ? 0 : inter / union;
  }

  final maxLen = na.length > nb.length ? na.length : nb.length;
  final dist = _levenshtein(na, nb);
  final levScore = maxLen == 0 ? 0 : 1 - dist / maxLen;

  return (tokenScore * 0.6 + levScore * 0.4).clamp(0.0, 1.0);
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

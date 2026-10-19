import 'dart:convert';

/// پارسر فایل ایمپورت گروهی: txt / csv / json / متن چسبانده‌شده.
/// خروجی همیشه لیست تمیز عنوان‌هاست.
class BulkImportParser {
  /// [ext] پسوند بدون نقطه: txt، csv، json. برای متن خام 'txt' بده.
  static List<String> parse(String content, String ext) {
    final e = ext.toLowerCase().trim();
    if (e == 'json') return _parseJson(content);
    if (e == 'csv') return _parseCsv(content);
    return _parseLines(content);
  }

  /// تمیزکاری یک عنوان: حذف سال داخل پرانتز، فاصله‌های اضافه، خط کامنت.
  static String cleanTitle(String raw) {
    var t = raw.trim();
    if (t.isEmpty || t.startsWith('#')) return '';
    // حذف « (2013)» یا « [TV]» انتهایی
    t = t.replaceAll(RegExp(r'\s*[\(\[]\s*\d{4}\s*[\)\]]\s*$'), '').trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  static List<String> _parseLines(String c) {
    return c
        .split('\n')
        .map(cleanTitle)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static List<String> _parseCsv(String c) {
    final lines = c
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty) return const [];
    // تشخیص ستون عنوان از هدر
    final header = _splitCsv(lines.first).map((h) => h.toLowerCase()).toList();
    var titleIdx = 0;
    const keys = ['title', 'name', 'anime', 'english', 'romaji'];
    for (var i = 0; i < header.length; i++) {
      if (keys.any((k) => header[i].contains(k))) {
        titleIdx = i;
        break;
      }
    }
    final hasHeader = keys.any((k) => header.any((h) => h.contains(k)));
    final rows = hasHeader ? lines.skip(1) : lines;
    final out = <String>[];
    for (final row in rows) {
      final cols = _splitCsv(row);
      if (titleIdx < cols.length) {
        final t = cleanTitle(cols[titleIdx]);
        if (t.isNotEmpty) out.add(t);
      }
    }
    return out;
  }

  /// اسپلیتر ساده CSV که کوتیشن دوتایی را هم می‌فهمد.
  static List<String> _splitCsv(String line) {
    final cols = <String>[];
    final buf = StringBuffer();
    var inQ = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQ && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQ = !inQ;
        }
      } else if (ch == ',' && !inQ) {
        cols.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    cols.add(buf.toString().trim());
    return cols;
  }

  static List<String> _parseJson(String c) {
    try {
      final d = jsonDecode(c);
      final out = <String>[];
      void add(dynamic v) {
        if (v is String) {
          final t = cleanTitle(v);
          if (t.isNotEmpty) {
            out.add(t);
          }
        } else if (v is Map) {
          for (final k in ['title', 'name', 'english', 'romaji', 'anime']) {
            final val = v[k];
            if (val is String && val.trim().isNotEmpty) {
              final t = cleanTitle(val);
              if (t.isNotEmpty) {
                out.add(t);
              }
              return;
            }
          }
        }
      }

      if (d is List) {
        for (final v in d) add(v);
      } else if (d is Map) {
        for (final k in ['anime', 'titles', 'list', 'data', 'items']) {
          final v = d[k];
          if (v is List) {
            for (final e in v) add(e);
            return out;
          }
        }
        // آبجکت تکی
        add(d);
      }
      return out;
    } catch (_) {
      // اگر JSON خراب بود، به‌عنوان متن خط‌به‌خط تلاش کن
      return _parseLines(c);
    }
  }

  /// نرمال‌سازی برای مقایسه عنوان‌ها (انگلیسی).
  static String norm(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// آیا نتیجه سرچ به کوئری می‌خورد؟ (برای تشخیص اطمینان)
  static bool confident(String query, String titleA, String titleB) {
    final q = norm(query);
    if (q.isEmpty) return false;
    final a = norm(titleA);
    final b = norm(titleB);
    if (q == a || (b.isNotEmpty && q == b)) return true;
    // کوئری زیررشته عنوان باشد یا برعکس (با حداقل طول)
    if (q.length >= 4) {
      if (a.isNotEmpty && (a.contains(q) || q.contains(a))) return true;
      if (b.isNotEmpty && (b.contains(q) || q.contains(b))) return true;
    }
    return false;
  }
}

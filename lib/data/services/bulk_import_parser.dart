import 'dart:convert';

class BulkImportParser {
  static List<String> parse(String content, String ext) {
    var c = content;
    if (c.startsWith('\uFEFF')) {
      c = c.substring(1);
    }
    final e = ext.toLowerCase().trim();
    if (e == 'json') return _parseJson(c);
    if (e == 'csv') return _parseCsv(c);
    return _parseLines(c);
  }

  static String cleanTitle(String raw) {
    var t = raw.trim();
    if (t.isEmpty || t.startsWith('#')) return '';
    t = t.replaceAll(RegExp(r'^\d{1,4}\s*[.)]\s+'), '').trim();
    t = t.replaceAll(RegExp(r'^[-•*]\s+'), '').trim();
    t = t.replaceAll(RegExp(r'\s*[\(\[]\s*\d{4}\s*[\)\]]\s*$'), '').trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  static List<String> _parseLines(String c) {
    return c.split('\n').map(cleanTitle).where((t) => t.isNotEmpty).toList();
  }

  static List<String> _parseCsv(String c) {
    final lines = c
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (lines.isEmpty) return const [];
    final header = _splitCsv(lines.first).map((h) => h.toLowerCase()).toList();
    var titleIdx = 0;
    var hasHeader = false;
    const keys = ['title', 'name', 'anime', 'english', 'romaji'];
    for (var pass = 0; pass < 2 && !hasHeader; pass++) {
      for (var i = 0; i < header.length; i++) {
        final cell = header[i].trim();
        final hit = pass == 0
            ? keys.any((k) => cell == k)
            : keys.any((k) => cell.contains(k));
        if (hit) {
          titleIdx = i;
          hasHeader = true;
          break;
        }
      }
    }
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
            String? text;
            if (val is String) {
              text = val;
            } else if (val is Map) {
              for (final nk in [
                'english',
                'romaji',
                'native',
                'title',
                'name',
              ]) {
                final nested = val[nk];
                if (nested is String && nested.trim().isNotEmpty) {
                  text = nested;
                  break;
                }
              }
            }
            if (text != null && text.trim().isNotEmpty) {
              final t = cleanTitle(text);
              if (t.isNotEmpty) {
                out.add(t);
              }
              return;
            }
          }
        }
      }

      if (d is List) {
        for (final v in d) {
          add(v);
        }
      } else if (d is Map) {
        for (final k in ['anime', 'titles', 'list', 'data', 'items']) {
          final v = d[k];
          if (v is List) {
            final before = out.length;
            for (final e in v) {
              add(e);
            }
            if (out.length > before) {
              return out;
            }
          }
        }
        add(d);
      }
      return out;
    } catch (_) {
      return _parseLines(c);
    }
  }

  static String norm(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool confident(String query, String titleA, String titleB) {
    final q = norm(query);
    if (q.isEmpty) return false;
    final a = norm(titleA);
    final b = norm(titleB);
    if (q == a || (b.isNotEmpty && q == b)) return true;
    if (q.length >= 4) {
      if (a.isNotEmpty && a.contains(q)) {
        return true;
      }
      if (a.length >= 4 && q.contains(a)) {
        return true;
      }
      if (b.isNotEmpty && b.contains(q)) {
        return true;
      }
      if (b.length >= 4 && q.contains(b)) {
        return true;
      }
    }
    return false;
  }
}

import 'dart:convert';

import 'package:hive/hive.dart';

/// ذخیره ترتیب شخصی تماشا و تاریخچه پیشنهادها داخل meta box.
class WatchOrderStorage {
  WatchOrderStorage(this._box);
  final Box<String> _box;

  static const _orderPrefix = 'wo:';
  static const _recentKey = 'sh:recent';
  static const _genreKey = 'sh:genre_counts';

  List<String>? customOrderOf(String franchiseId) {
    final raw = _box.get('$_orderPrefix$franchiseId');
    if (raw == null || raw.isEmpty) return null;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCustomOrder(String franchiseId, List<String> ids) async {
    await _box.put('$_orderPrefix$franchiseId', jsonEncode(ids));
  }

  Future<void> clearCustomOrder(String franchiseId) async {
    await _box.delete('$_orderPrefix$franchiseId');
  }

  List<String> recentSuggestions() {
    final raw = _box.get(_recentKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  Map<String, int> recentGenreCounts() {
    final raw = _box.get(_genreKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final m = jsonDecode(raw) as Map;
      return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return const {};
    }
  }

  Future<void> pushSuggestion({
    required String franchiseId,
    required List<String> genres,
  }) async {
    final list = [...recentSuggestions(), franchiseId];
    while (list.length > 5) {
      list.removeAt(0);
    }
    await _box.put(_recentKey, jsonEncode(list));

    final counts = Map<String, int>.from(recentGenreCounts());
    for (final g in genres) {
      counts[g] = (counts[g] ?? 0) + 1;
    }
    final decayed = <String, int>{};
    counts.forEach((k, v) {
      if (v > 1) decayed[k] = v - 1;
    });
    await _box.put(_genreKey, jsonEncode(decayed));
  }

  Future<void> clearHistory() async {
    await _box.delete(_recentKey);
    await _box.delete(_genreKey);
  }
}

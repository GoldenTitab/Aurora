import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// دیتای شخصی کاربر داخل meta box:
/// یادداشت فرنچایز، امتیاز کاربر به هر اثر، زمان آخرین فعالیت،
/// تم و رنگ اصلی، و زمان بستن بنر قسمت‌های جدید.
class UserExtras {
  UserExtras(this._box);
  final Box<String> _box;

  // ── یادداشت فرنچایز ──────────────────────────────────────────
  String? noteOf(String franchiseId) => _box.get('note:$franchiseId');

  Future<void> saveNote(String franchiseId, String note) async {
    if (note.trim().isEmpty) {
      await _box.delete('note:$franchiseId');
    } else {
      await _box.put('note:$franchiseId', note);
    }
  }

  // ── امتیاز کاربر به اثر (۰ تا ۱۰) ─────────────────────────────
  double? scoreOf(String entryId) {
    final raw = _box.get('uscore:$entryId');
    return raw == null ? null : double.tryParse(raw);
  }

  Future<void> saveScore(String entryId, double? score) async {
    if (score == null || score <= 0) {
      await _box.delete('uscore:$entryId');
    } else {
      await _box.put('uscore:$entryId', score.toString());
    }
  }

  // ── آخرین فعالیت روی اثر (برای «ادامه تماشا») ──────────────────
  int lastSeenOf(String entryId) =>
      int.tryParse(_box.get('seen:$entryId') ?? '') ?? 0;

  Future<void> touchSeen(String entryId) =>
      _box.put('seen:$entryId', DateTime.now().millisecondsSinceEpoch.toString());

  // ── تم و رنگ اصلی ─────────────────────────────────────────────
  ThemeMode themeMode() {
    switch (_box.get('theme_mode')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _box.put('theme_mode', mode.name);

  Color seedColor() {
    final v = int.tryParse(_box.get('seed_color') ?? '');
    if (v == null) return const Color(0xFF8B5CF6);
    return Color(v);
  }

  Future<void> setSeedColor(Color color) =>
      _box.put('seed_color', color.toARGB32().toString());

  // ── زبان اپ (fa/en) ────────────────────────────────────────────
  String language() {
    final v = _box.get('app_lang');
    return v == 'en' ? 'en' : 'fa';
  }

  Future<void> setLanguage(String lang) =>
      _box.put('app_lang', lang == 'en' ? 'en' : 'fa');

  // ── بنر قسمت‌های جدید ─────────────────────────────────────────
  int dismissedNewEpisodesAt() =>
      int.tryParse(_box.get('dismissed_new_ep') ?? '') ?? 0;

  Future<void> dismissNewEpisodes() => _box.put(
    'dismissed_new_ep',
    DateTime.now().millisecondsSinceEpoch.toString(),
  );

  // ── حالت بدون اسپویل ────────────────────────────────────────────
  bool spoilerFree() => _box.get('spoiler_free') == '1';

  Future<void> setSpoilerFree(bool v) =>
      _box.put('spoiler_free', v ? '1' : '0');

  // ── یادداشت هر قسمت ─────────────────────────────────────────────
  String? episodeNoteOf(String entryId, int ep) =>
      _box.get('enote:$entryId:$ep');

  Future<void> saveEpisodeNote(String entryId, int ep, String note) {
    final key = 'enote:$entryId:$ep';
    if (note.trim().isEmpty) {
      return _box.delete(key);
    }
    return _box.put(key, note.trim());
  }

  /// پاک‌سازی کامل ردپای یک فرنچایز از «لیست من»: یادداشت فرنچایز،
  /// امتیازها، یادداشت قسمت‌ها و آخرین بازدیدِ همه‌ی ورودی‌هایش.
  /// (وضعیت‌ها و پیشرفت قسمت‌ها جدا و توسط notifierها پاک می‌شوند.)
  Future<void> clearFranchise(String franchiseId, Iterable<String> entryIds) {
    final ids = entryIds.toSet();
    final remove = <String>[];
    for (final k in _box.keys.map((e) => e.toString())) {
      if (k == 'note:$franchiseId') {
        remove.add(k);
        continue;
      }
      for (final e in ids) {
        if (k == 'seen:$e' ||
            k == 'uscore:$e' ||
            k.startsWith('enote:$e:')) {
          remove.add(k);
          break;
        }
      }
    }
    if (remove.isEmpty) return Future.value();
    return _box.deleteAll(remove);
  }
}

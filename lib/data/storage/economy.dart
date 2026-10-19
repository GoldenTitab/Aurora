import 'dart:convert';

import 'package:hive/hive.dart';

class Economy {
  Economy(this._box);
  final Box<String> _box;

  static const List<String> levelNames = [
    'Beginner',
    'Novice',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  static const List<int> levelThresholds = [0, 1000, 3000, 5000, 7000];

  static int levelForXp(int xp) {
    var level = 0;
    for (var i = 0; i < levelThresholds.length; i++) {
      if (xp >= levelThresholds[i]) level = i;
    }
    return level;
  }

  static int xpForNextLevel(int xp) {
    for (final t in levelThresholds) {
      if (xp < t) return t;
    }
    return levelThresholds.last;
  }

  int xpTotal() => int.tryParse(_box.get('xp_total') ?? '') ?? 0;

  Future<int?> addXp(int n, {String? reason}) async {
    if (n <= 0) return null;
    final before = xpTotal();
    final after = before + n;
    await _box.put('xp_total', '$after');
    await _logXp(n, reason ?? '');
    final lb = levelForXp(before);
    final la = levelForXp(after);
    return la > lb ? la : null;
  }

  List<({int time, int amount, String reason})> xpLog() {
    final raw = _box.get('xp_log');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          (
            time: (e['t'] as num?)?.toInt() ?? 0,
            amount: (e['n'] as num?)?.toInt() ?? 0,
            reason: (e['r'] as String?) ?? '',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _logXp(int n, String reason) async {
    try {
      final log = [
        {'t': DateTime.now().millisecondsSinceEpoch, 'n': n, 'r': reason},
        for (final e in xpLog().take(19))
          {'t': e.time, 'n': e.amount, 'r': e.reason},
      ];
      await _box.put('xp_log', jsonEncode(log));
    } catch (_) {}
  }

  int level() => levelForXp(xpTotal());

  int coins() => int.tryParse(_box.get('coins') ?? '') ?? 0;

  Future<void> addCoins(int n) async {
    if (n <= 0) return;
    await _box.put('coins', '${coins() + n}');
    await bumpStat('coins_earned', n);
  }

  Future<bool> spendCoins(int n) async {
    if (n <= 0) return true;
    final bal = coins();
    if (bal < n) return false;
    await _box.put('coins', '${bal - n}');
    return true;
  }

  int statOf(String name) => int.tryParse(_box.get('stat:$name') ?? '') ?? 0;

  Future<void> bumpStat(String name, [int by = 1]) async {
    if (by <= 0) return;
    await _box.put('stat:$name', '${statOf(name) + by}');
  }

  static String _dayStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String todayStr([DateTime? now]) => _dayStr(now ?? DateTime.now());

  static String yesterdayStr([DateTime? now]) {
    final n = now ?? DateTime.now();
    return _dayStr(DateTime(n.year, n.month, n.day - 1));
  }

  Future<bool> dailyCheckIn() async {
    final today = todayStr();
    if (_box.get('last_checkin') == today) return false;
    await _box.put('last_checkin', today);
    await addXp(5, reason: 'checkin');
    await addCoins(20);
    await bumpStat('checkin_total');
    return true;
  }

  int streak() => int.tryParse(_box.get('streak_count') ?? '') ?? 0;

  int maxStreak() => int.tryParse(_box.get('streak_max') ?? '') ?? 0;

  Future<int> recordWatchDay() async {
    final today = todayStr();
    final last = _box.get('streak_last') ?? '';
    if (last == today) return streak();
    final next = last == yesterdayStr() ? streak() + 1 : 1;
    await _box.put('streak_last', today);
    await _box.put('streak_count', '$next');
    if (next > maxStreak()) await _box.put('streak_max', '$next');
    return next;
  }

  Future<void> bumpHeatDay([DateTime? now]) async {
    final key = 'heat:${todayStr(now)}';
    final cur = int.tryParse(_box.get(key) ?? '') ?? 0;
    await _box.put(key, '${cur + 1}');
  }

  List<({String day, int count})> heatDays(int n) {
    final now = DateTime.now();
    final out = <({String day, int count})>[];
    for (var i = n - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      final key = 'heat:${_dayStr(d)}';
      out.add((day: _dayStr(d), count: int.tryParse(_box.get(key) ?? '') ?? 0));
    }
    return out;
  }

  int missionCounter(String counter, String period) =>
      int.tryParse(_box.get('mx:$counter:$period') ?? '') ?? 0;

  Future<void> bumpMissionCounter(
    String counter,
    String period, [
    int by = 1,
  ]) async {
    if (by <= 0) return;
    final key = 'mx:$counter:$period';
    final cur = int.tryParse(_box.get(key) ?? '') ?? 0;
    await _box.put(key, '${cur + by}');
  }

  bool missionClaimed(String period, String missionId) =>
      _box.get('mission_claimed:$period:$missionId') == '1';

  Future<void> markMissionClaimed(String period, String missionId) =>
      _box.put('mission_claimed:$period:$missionId', '1');

  static String weekId([DateTime? now]) {
    final d = now ?? DateTime.now();
    final sat = DateTime(d.year, d.month, d.day - ((d.weekday + 1) % 7));
    return _dayStr(sat);
  }

  Future<int> markEpisodesAwarded(String entryId, Set<int> eps) async {
    if (eps.isEmpty) return 0;
    final key = 'xpep:$entryId';
    final seen = <int>{};
    final raw = _box.get(key);
    if (raw != null && raw.isNotEmpty) {
      for (final part in raw.split(',')) {
        final n = int.tryParse(part.trim());
        if (n != null) seen.add(n);
      }
    }
    final fresh = eps.difference(seen);
    if (fresh.isEmpty) return 0;
    seen.addAll(fresh);
    final sorted = seen.toList()..sort();
    await _box.put(key, sorted.join(','));
    return fresh.length;
  }

  bool achievementUnlocked(String id) => _box.get('ach:$id') != null;

  int? achievementUnlockedAt(String id) =>
      int.tryParse(_box.get('ach:$id') ?? '');

  Future<void> unlockAchievement(String id) =>
      _box.put('ach:$id', '${DateTime.now().millisecondsSinceEpoch}');

  List<String> unlockedAchievements() => _box.keys
      .map((k) => k.toString())
      .where((k) => k.startsWith('ach:'))
      .map((k) => k.substring(4))
      .toList();

  int? fratingOf(String franchiseId) {
    final raw = _box.get('frating:$franchiseId');
    final v = int.tryParse(raw ?? '');
    if (v == null || v < 1 || v > 10) return null;
    return v;
  }

  Future<bool> saveFranchiseRating(String franchiseId, int v) async {
    final first = fratingOf(franchiseId) == null;
    if (v < 1 || v > 10) {
      await _box.delete('frating:$franchiseId');
    } else {
      await _box.put('frating:$franchiseId', '$v');
    }
    return first;
  }

  Future<void> deleteFranchiseRating(String franchiseId) =>
      _box.delete('frating:$franchiseId');

  int fratingCount() => _box.keys
      .map((k) => k.toString())
      .where((k) => k.startsWith('frating:'))
      .length;
}

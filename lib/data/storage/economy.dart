import 'package:hive/hive.dart';

/// اقتصاد بازی‌وار اپ: XP، لول، سکه «شفق»، سر زدن روزانه، استریک و هیت‌مپ.
/// همه‌چیز داخل [Boxes.meta] نگه‌داری می‌شود (کلیدها با پیشوند مشخص).
class Economy {
  Economy(this._box);
  final Box<String> _box;

  // ── لول‌ها ─────────────────────────────────────────────────────
  static const List<String> levelNames = [
    'Beginner',
    'Novice',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  /// آستانه XP هر لول (ایندکس ۰ تا ۴).
  static const List<int> levelThresholds = [0, 500, 1500, 3000, 5000];

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

  // ── XP ──────────────────────────────────────────────────────────
  int xpTotal() => int.tryParse(_box.get('xp_total') ?? '') ?? 0;

  /// XP اضافه می‌کند؛ اگر لول بالا رفت، ایندکس لول جدید را برمی‌گرداند.
  Future<int?> addXp(int n) async {
    if (n <= 0) return null;
    final before = xpTotal();
    final after = before + n;
    await _box.put('xp_total', '$after');
    final lb = levelForXp(before);
    final la = levelForXp(after);
    return la > lb ? la : null;
  }

  int level() => levelForXp(xpTotal());

  // ── سکه «شفق» ───────────────────────────────────────────────────
  int coins() => int.tryParse(_box.get('coins') ?? '') ?? 0;

  Future<void> addCoins(int n) async {
    if (n <= 0) return;
    await _box.put('coins', '${coins() + n}');
    await bumpStat('coins_earned', n);
  }

  /// true یعنی پرداخت موفق بود.
  Future<bool> spendCoins(int n) async {
    if (n <= 0) return true;
    final bal = coins();
    if (bal < n) return false;
    await _box.put('coins', '${bal - n}');
    return true;
  }

  // ── شمارنده‌های آماری (برای مأموریت‌ها و اچیومنت‌ها) ─────────────
  int statOf(String name) => int.tryParse(_box.get('stat:$name') ?? '') ?? 0;

  Future<void> bumpStat(String name, [int by = 1]) async {
    if (by <= 0) return;
    await _box.put('stat:$name', '${statOf(name) + by}');
  }

  // ── سر زدن روزانه ────────────────────────────────────────────────
  static String _dayStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String todayStr([DateTime? now]) => _dayStr(now ?? DateTime.now());

  static String yesterdayStr([DateTime? now]) =>
      _dayStr((now ?? DateTime.now()).subtract(const Duration(days: 1)));

  /// اگر امروز هنوز سر نزده: +۵ XP و +۲۰ سکه. true یعنی تازه انجام شد.
  Future<bool> dailyCheckIn() async {
    final today = todayStr();
    if (_box.get('last_checkin') == today) return false;
    await _box.put('last_checkin', today);
    await addXp(5);
    await addCoins(20);
    await bumpStat('checkin_total');
    return true;
  }

  // ── استریک تماشا ─────────────────────────────────────────────────
  int streak() => int.tryParse(_box.get('streak_count') ?? '') ?? 0;

  /// ثبت «امروز قسمت دیده شد». تعداد روزهای متوالی را برمی‌گرداند.
  Future<int> recordWatchDay() async {
    final today = todayStr();
    final last = _box.get('streak_last') ?? '';
    if (last == today) return streak();
    final next = last == yesterdayStr() ? streak() + 1 : 1;
    await _box.put('streak_last', today);
    await _box.put('streak_count', '$next');
    return next;
  }

  // ── هیت‌مپ ───────────────────────────────────────────────────────
  Future<void> bumpHeatDay([DateTime? now]) async {
    final key = 'heat:${todayStr(now)}';
    final cur = int.tryParse(_box.get(key) ?? '') ?? 0;
    await _box.put(key, '${cur + 1}');
  }

  /// لیست (تاریخ، تعداد) برای N روز اخیر؛ قدیمی‌ترین اول.
  List<({String day, int count})> heatDays(int n) {
    final now = DateTime.now();
    final out = <({String day, int count})>[];
    for (var i = n - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = 'heat:${_dayStr(d)}';
      out.add((day: _dayStr(d), count: int.tryParse(_box.get(key) ?? '') ?? 0));
    }
    return out;
  }

  // ── شمارنده مأموریت‌ها ───────────────────────────────────────────
  int missionCounter(String counter, String period) =>
      int.tryParse(_box.get('mx:$counter:$period') ?? '') ?? 0;

  Future<void> bumpMissionCounter(String counter, String period,
      [int by = 1]) async {
    if (by <= 0) return;
    final key = 'mx:$counter:$period';
    final cur = int.tryParse(_box.get(key) ?? '') ?? 0;
    await _box.put(key, '${cur + by}');
  }

  bool missionClaimed(String period, String missionId) =>
      _box.get('mission_claimed:$period:$missionId') == '1';

  Future<void> markMissionClaimed(String period, String missionId) =>
      _box.put('mission_claimed:$period:$missionId', '1');

  /// شناسه هفته فارسی (شروع شنبه) مثل 2026-10-10.
  static String weekId([DateTime? now]) {
    final d = now ?? DateTime.now();
    final sat = d.subtract(Duration(days: (d.weekday + 1) % 7));
    return _dayStr(sat);
  }

  // ── جلوگیری از جایزه تکراری قسمت ───────────────────────────────────
  /// برای هر قسمت فقط بار اول XP/سکه داده می‌شود (تاگِل on/off/on یا
  /// clear و علامت‌گذاری دوباره، جایزه دوباره نمی‌دهد).
  /// تعداد قسمت‌هایی که «تازه» جایزه گرفته‌اند را برمی‌گرداند.
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

  // ── اچیومنت‌ها ───────────────────────────────────────────────────
  bool achievementUnlocked(String id) => _box.get('ach:$id') != null;

  Future<void> unlockAchievement(String id) => _box.put(
        'ach:$id',
        '${DateTime.now().millisecondsSinceEpoch}',
      );

  List<String> unlockedAchievements() => _box.keys
      .map((k) => k.toString())
      .where((k) => k.startsWith('ach:'))
      .map((k) => k.substring(4))
      .toList();

  // ── امتیاز فرنچایز (۱ تا ۱۰) ──────────────────────────────────────
  int? fratingOf(String franchiseId) {
    final raw = _box.get('frating:$franchiseId');
    final v = int.tryParse(raw ?? '');
    if (v == null || v < 1 || v > 10) return null;
    return v;
  }

  /// true یعنی اولین بار است که به این فرنچایز نمره داده می‌شود.
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

  /// تعداد فرنچایزهایی که نمره ۱ تا ۱۰ گرفته‌اند.
  int fratingCount() => _box.keys
      .map((k) => k.toString())
      .where((k) => k.startsWith('frating:'))
      .length;
}

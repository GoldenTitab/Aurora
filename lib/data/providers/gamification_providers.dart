import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../gamification/achievements_catalog.dart';
import '../gamification/card_pool.dart';
import '../gamification/missions.dart';
import '../models/achievement.dart';
import '../models/collectible_card.dart';
import '../models/watch_status.dart';
import '../storage/economy.dart';
import '../storage/migrations.dart' show Boxes;
import 'core_providers.dart';
import 'mylist_providers.dart';
import 'theme_providers.dart';

class EconomyState {
  final int xp;
  final int level;
  final int coins;
  final int streak;

  const EconomyState({
    required this.xp,
    required this.level,
    required this.coins,
    required this.streak,
  });
}

final levelUpEventProvider = StateProvider<int?>((ref) => null);

final achievementEventProvider = StateProvider<List<AchievementDef>>(
  (ref) => const [],
);

class EconomyNotifier extends Notifier<EconomyState> {
  Economy get _eco => Economy(Hive.box<String>(Boxes.meta));

  final Set<String> _completing = {};

  EconomyState _read() {
    final e = _eco;
    return EconomyState(
      xp: e.xpTotal(),
      level: e.level(),
      coins: e.coins(),
      streak: e.streak(),
    );
  }

  @override
  EconomyState build() => _read();

  void refresh() => state = _read();

  void _leveled(int? lv) {
    if (lv != null) ref.read(levelUpEventProvider.notifier).state = lv;
  }

  Future<void> onEpisodesWatched(int n) async {
    if (n <= 0) return;
    final e = _eco;
    _leveled(await e.addXp(10 * n));
    await e.addCoins(5 * n);
    await e.bumpStat('ep_total', n);
    await e.bumpMissionCounter('ep_d', Economy.todayStr(), n);
    await e.bumpMissionCounter('ep_w', Economy.weekId(), n);
    await e.recordWatchDay();
    for (var i = 0; i < n; i++) {
      await e.bumpHeatDay();
    }
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onRatingGiven() async {
    final e = _eco;
    _leveled(await e.addXp(5));
    await e.bumpStat('rate_total');
    await e.bumpMissionCounter('rate_d', Economy.todayStr());
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onNoteWritten() async {
    final e = _eco;
    _leveled(await e.addXp(5));
    await e.bumpStat('note_total');
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onFranchiseRating(bool first) async {
    if (!first) return;
    final e = _eco;
    _leveled(await e.addXp(5));
    await e.bumpStat('frating_total');
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }

  Future<void> onFranchiseCompleted(String franchiseId) async {
    if (_completing.contains(franchiseId)) return;
    final box = Hive.box<String>(Boxes.meta);
    if (box.get('frdone:$franchiseId') == '1') return;
    _completing.add(franchiseId);
    try {
      await box.put('frdone:$franchiseId', '1');
      _leveled(await _eco.addXp(50));
      refresh();
      unawaited(ref.read(achievementsProvider.notifier).evaluate());
    } finally {
      _completing.remove(franchiseId);
    }
  }

  Future<void> markImported() async {
    await Hive.box<String>(Boxes.meta).put('import_done', '1');
    refresh();
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
  }
}

final economyProvider = NotifierProvider<EconomyNotifier, EconomyState>(
  EconomyNotifier.new,
);

final streakProvider = Provider<int>(
  (ref) => ref.watch(economyProvider).streak,
);

final heatmapProvider = Provider<List<({String day, int count})>>((ref) {
  ref.watch(economyProvider);
  return Economy(Hive.box<String>(Boxes.meta)).heatDays(182);
});

final missionsProvider = NotifierProvider<MissionsNotifier, List<MissionState>>(
  MissionsNotifier.new,
);

class MissionsNotifier extends Notifier<List<MissionState>> {
  MissionEngine get _engine =>
      MissionEngine(Economy(Hive.box<String>(Boxes.meta)));

  @override
  List<MissionState> build() {
    ref.watch(langProvider);
    return _engine.states();
  }

  Future<bool> claim(MissionDef def) async {
    final r = await _engine.claim(def);
    if (!r.ok) return false;
    state = _engine.states();
    ref.read(economyProvider.notifier).refresh();
    if (r.leveledTo != null) {
      ref.read(levelUpEventProvider.notifier).state = r.leveledTo;
    }
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
    return true;
  }
}

final achievementsProvider =
    NotifierProvider<AchievementsNotifier, Set<String>>(
      AchievementsNotifier.new,
    );

class AchievementsNotifier extends Notifier<Set<String>> {
  List<AchievementDef> _defs = const [];

  final Set<String> _inflight = {};

  List<AchievementDef> get all => _defs;

  @override
  Set<String> build() {
    ref.watch(langProvider);
    _defs = buildAchievements();
    return Economy(Hive.box<String>(Boxes.meta)).unlockedAchievements().toSet();
  }

  AchCtx _buildCtx() {
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final franchises = ref.read(myListFranchisesProvider);
    final stats = ref.read(libraryStatsProvider);
    final genres = <String>{};
    for (final mf in franchises) {
      genres.addAll(mf.franchise.genres);
    }
    final pool = ref.read(cardPoolProvider);
    return AchCtx(
      episodesWatched: eco.statOf('ep_total'),
      franchisesStarted: franchises.length,
      franchisesCompleted: franchises
          .where((m) => m.status == WatchStatus.completed)
          .length,
      distinctGenres: genres.length,
      streak: eco.streak(),
      ratingsGiven: eco.statOf('rate_total'),
      notesWritten: eco.statOf('note_total'),
      franchiseRatings: eco.fratingCount(),
      cardsOwned: pool.totalOwned(),
      cardsPerRarity: pool.ownedPerRarity(),
      packsOpened: eco.statOf('packs_opened'),
      coinsEarned: eco.statOf('coins_earned'),
      missionsDone: eco.statOf('mission_done'),
      level: eco.level(),
      watchMinutes: stats.totalWatchedMinutes,
      importDone: Hive.box<String>(Boxes.meta).get('import_done') == '1',
      checkins: eco.statOf('checkin_total'),
      xpTotal: eco.xpTotal(),
    );
  }

  Future<void> evaluate() async {
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final ctx = _buildCtx();
    final newly = <AchievementDef>[];
    for (final d in _defs) {
      if (state.contains(d.id) || _inflight.contains(d.id)) continue;
      bool pass = false;
      try {
        pass = d.test(ctx);
      } catch (_) {}
      if (!pass) continue;
      if (eco.achievementUnlocked(d.id)) continue;
      _inflight.add(d.id);
      try {
        await eco.unlockAchievement(d.id);
        final leveled = await eco.addXp(d.xp);
        if (d.coins > 0) await eco.addCoins(d.coins);
        if (leveled != null) {
          ref.read(levelUpEventProvider.notifier).state = leveled;
        }
        newly.add(d);
      } finally {
        _inflight.remove(d.id);
      }
    }
    if (newly.isNotEmpty) {
      state = {...state, for (final d in newly) d.id};
      ref.read(achievementEventProvider.notifier).state = [
        ...ref.read(achievementEventProvider),
        ...newly,
      ];
      ref.read(economyProvider.notifier).refresh();
    }
  }
}

final cardPoolProvider = Provider<CardPool>((ref) {
  return CardPool(
    Hive.box<String>(Boxes.meta),
    Hive.box<String>('card_cache'),
    ref.watch(anilistClientProvider),
    ref.watch(franchiseRepositoryProvider),
  );
});

class CardsState {
  final Map<CardRarity, List<CollectibleCard>> collection;
  final int poolSize;

  final Map<CardRarity, int> poolBreakdown;
  final bool poolLoading;

  const CardsState({
    required this.collection,
    required this.poolSize,
    this.poolBreakdown = const {},
    this.poolLoading = false,
  });
}

final cardsProvider = NotifierProvider<CardsNotifier, CardsState>(
  CardsNotifier.new,
);

class CardsNotifier extends Notifier<CardsState> {
  CardPool get _pool => ref.read(cardPoolProvider);
  Economy get _eco => Economy(Hive.box<String>(Boxes.meta));

  CardsState _read({bool loading = false}) => CardsState(
    collection: _pool.collection(),
    poolSize: _pool.poolSize(),
    poolBreakdown: _pool.rarityBreakdown(),
    poolLoading: loading,
  );

  @override
  CardsState build() {
    unawaited(_pool.migrateLegacyRarities().then((_) => state = _read()));
    return _read();
  }

  Future<int> rebuildPool({bool force = false}) async {
    state = _read(loading: true);
    final n = await _pool.rebuildPool(force: force);
    state = _read();
    return n;
  }

  Future<void> clearPoolCache() async {
    await _pool.clearPool();
    state = _read();
  }

  Future<PackResult?> openPack() async {
    final r = await _pool.openPack(_eco);
    if (r == null) return null;
    state = _read();
    ref.read(economyProvider.notifier).refresh();
    ref.invalidate(missionsProvider);
    unawaited(ref.read(achievementsProvider.notifier).evaluate());
    return r;
  }
}

final franchiseRatingProvider =
    NotifierProvider.family<FranchiseRatingNotifier, int?, String>(
      FranchiseRatingNotifier.new,
    );

class FranchiseRatingNotifier extends FamilyNotifier<int?, String> {
  Economy get _eco => Economy(Hive.box<String>(Boxes.meta));

  @override
  int? build(String arg) => _eco.fratingOf(arg);

  Future<void> setRating(int v) async {
    final first = await _eco.saveFranchiseRating(arg, v);
    state = v;
    await ref.read(economyProvider.notifier).onFranchiseRating(first);
  }

  Future<void> clear() async {
    await _eco.deleteFranchiseRating(arg);
    state = null;
  }
}

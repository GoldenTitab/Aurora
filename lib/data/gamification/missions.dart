import '../storage/economy.dart';
import '../../core/i18n/lang.dart';

enum MissionPeriod { daily, weekly }

class MissionDef {
  final String id;
  final String titleFa;
  final String descFa;
  final int target;
  final int xp;
  final int coins;
  final MissionPeriod period;

  final String counter;

  const MissionDef({
    required this.id,
    required this.titleFa,
    required this.descFa,
    required this.target,
    required this.xp,
    required this.coins,
    required this.period,
    required this.counter,
  });
}

class MissionState {
  final MissionDef def;
  final int progress;
  final bool claimed;

  const MissionState({
    required this.def,
    required this.progress,
    required this.claimed,
  });

  bool get done => progress >= def.target;
  double get ratio =>
      def.target <= 0 ? 0 : (progress / def.target).clamp(0.0, 1.0).toDouble();
}

List<MissionDef> dailyMissions() =>  [
      MissionDef(
        id: 'd_ep3',
        titleFa: tr('daily_watcher'),
        descFa: tr('watch_3_anime_episodes'),
        target: 3,
        xp: 15,
        coins: 30,
        period: MissionPeriod.daily,
        counter: 'ep_d',
      ),
      MissionDef(
        id: 'd_rate1',
        titleFa: tr('critic'),
        descFa: tr('score_1_title'),
        target: 1,
        xp: 10,
        coins: 30,
        period: MissionPeriod.daily,
        counter: 'rate_d',
      ),
      MissionDef(
        id: 'd_open',
        titleFa: tr('check_in'),
        descFa: tr('open_the_app_today'),
        target: 1,
        xp: 5,
        coins: 30,
        period: MissionPeriod.daily,
        counter: 'open_d',
      ),
    ];

List<MissionDef> weeklyMissions() =>  [
      MissionDef(
        id: 'w_ep15',
        titleFa: tr('weekly_adventurer'),
        descFa: tr('watch_15_anime_episodes'),
        target: 15,
        xp: 40,
        coins: 30,
        period: MissionPeriod.weekly,
        counter: 'ep_w',
      ),
      MissionDef(
        id: 'w_pack1',
        titleFa: tr('collector'),
        descFa: tr('open_1_card_pack'),
        target: 1,
        xp: 20,
        coins: 30,
        period: MissionPeriod.weekly,
        counter: 'pack_w',
      ),
    ];

String _periodId(MissionPeriod p) =>
    p == MissionPeriod.daily ? Economy.todayStr() : Economy.weekId();

class MissionEngine {
  MissionEngine(this._eco);
  final Economy _eco;

  List<MissionState> states() {
    final out = <MissionState>[];
    for (final def in [...dailyMissions(), ...weeklyMissions()]) {
      final pid = _periodId(def.period);
      final progress = _eco.missionCounter(def.counter, pid);
      out.add(
        MissionState(
          def: def,
          progress: progress,
          claimed: _eco.missionClaimed(pid, def.id),
        ),
      );
    }
    return out;
  }

  Future<({bool ok, int? leveledTo})> claim(MissionDef def) async {
    final pid = _periodId(def.period);
    final progress = _eco.missionCounter(def.counter, pid);
    if (progress < def.target) return (ok: false, leveledTo: null);
    if (_eco.missionClaimed(pid, def.id)) return (ok: false, leveledTo: null);
    await _eco.markMissionClaimed(pid, def.id);
    final leveledTo = await _eco.addXp(def.xp, reason: tr('xp_reason_mission', [def.titleFa]));
    await _eco.addCoins(def.coins);
    await _eco.bumpStat('mission_done');
    return (ok: true, leveledTo: leveledTo);
  }
}

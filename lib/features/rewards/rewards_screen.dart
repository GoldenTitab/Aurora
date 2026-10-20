import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/section_title.dart';
import '../../data/gamification/missions.dart';
import '../../data/models/achievement.dart';
import '../../data/providers.dart';
import '../../data/storage/economy.dart';
import '../../data/storage/migrations.dart';
import 'cards_tab.dart';
import '../../core/i18n/lang.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(economyProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('rewards')),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.star.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.star.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        size: 16,
                        color: AppColors.starTextOf(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('shafaq', [toFa(eco.coins)]),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.starTextOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr('my_level')),
              Tab(text: tr('cards')),
              Tab(text: tr('missions')),
              Tab(text: tr('achievements')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LevelTab(),
            CardsTab(),
            _MissionsTab(),
            _AchievementsTab(),
          ],
        ),
      ),
    );
  }
}

class _LevelTab extends ConsumerWidget {
  const _LevelTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(economyProvider);
    final level = eco.level;
    final xp = eco.xp;
    final cur = Economy.levelThresholds[level];
    final next = level + 1 < Economy.levelThresholds.length
        ? Economy.levelThresholds[level + 1]
        : null;
    final ratio = next == null
        ? 1.0
        : ((xp - cur) / (next - cur)).clamp(0.0, 1.0).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFFF472B6)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.military_tech_rounded,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                Economy.levelNames[level],
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: 4),
              Text(
                '${toFa(xp)} XP',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                next == null
                    ? tr('you_reached_the_highest_level')
                    : tr('xp_to', [
                        toFa(next - xp),
                        Economy.levelNames[level + 1],
                      ]),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionTitle(tr('level_path')),
        const SizedBox(height: 12),
        for (var i = 0; i < Economy.levelNames.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: i == level
                    ? AppColors.primary
                    : AppColors.borderOf(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  i < level
                      ? Icons.check_circle_rounded
                      : i == level
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: i <= level
                      ? AppColors.primary
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Economy.levelNames[i],
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontWeight: i == level
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${toFa(Economy.levelThresholds[i])} XP',
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SectionTitle(tr('ways_to_earn_xp')),
        const SizedBox(height: 8),
        Text(
          tr('each_watched_episode_10_xp_and_5_shafaq') +
              tr('rating_5_xp') +
              tr('writing_a_note_5_xp') +
              tr('completing_a_franchise_100_xp') +
              tr('daily_check_in_5_xp_and_20_shafaq'),
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 13,
            height: 2,
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(tr('xp_history')),
        const SizedBox(height: 8),
        const _XpHistory(),
      ],
    );
  }
}

/// تاریخچه‌ی ۲۰ رویداد اخیر XP.
class _XpHistory extends ConsumerWidget {
  const _XpHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // با هر تغییر XP رفرش شود
    ref.watch(economyProvider);
    final log = Economy(Hive.box<String>(Boxes.meta)).xpLog();
    if (log.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            tr('not_enough_data'),
            style: TextStyle(color: AppColors.textSecondaryOf(context)),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < log.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+${toFa(log[i].amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.primaryTextOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _reasonLabel(log[i].reason),
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _timeAgo(log[i].time),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            if (i < log.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: AppColors.borderOf(context),
              ),
          ],
        ],
      ),
    );
  }

  String _reasonLabel(String r) {
    if (r.isEmpty) return '—';
    if (r == 'checkin') return tr('xp_reason_checkin');
    return r;
  }

  String _timeAgo(int ms) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (diff.inMinutes < 1) return tr('just_now');
    if (diff.inMinutes < 60)
      return tr('in_minutes_ago', [toFa(diff.inMinutes)]);
    if (diff.inHours < 24) return tr('in_hours_ago', [toFa(diff.inHours)]);
    return tr('in_days_ago', [toFa(diff.inDays)]);
  }
}

class _MissionsTab extends ConsumerWidget {
  const _MissionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionsProvider);
    final daily = missions
        .where((m) => m.def.period == MissionPeriod.daily)
        .toList();
    final weekly = missions
        .where((m) => m.def.period == MissionPeriod.weekly)
        .toList();

    final allDailyDone = daily.isNotEmpty && daily.every((m) => m.claimed);
    final allWeeklyDone = weekly.isNotEmpty && weekly.every((m) => m.claimed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ResetCountdowns(),
        const SizedBox(height: 16),
        SectionTitle(tr('daily_missions')),
        const SizedBox(height: 12),
        if (allDailyDone) const _AllDoneBanner(),
        for (final m in daily) _MissionCard(m: m),
        const SizedBox(height: 16),
        SectionTitle(tr('weekly_missions')),
        const SizedBox(height: 12),
        if (allWeeklyDone) const _AllDoneBanner(),
        for (final m in weekly) _MissionCard(m: m),
      ],
    );
  }
}

/// شمارش معکوس تا ریست روزانه و هفتگی.
class _ResetCountdowns extends StatelessWidget {
  const _ResetCountdowns();

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${toFa(h.toString().padLeft(2, '0'))}:${toFa(m.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dailyLeft = tomorrow.difference(now);
    final rawDaysToSaturday = (DateTime.saturday - now.weekday) % 7;
    final daysToSaturday = rawDaysToSaturday == 0 ? 7 : rawDaysToSaturday;
    final nextSaturday = DateTime(
      now.year,
      now.month,
      now.day + daysToSaturday,
    );
    final weeklyLeft = nextSaturday.difference(now);
    final weeklyStr = weeklyLeft.inDays > 0
        ? tr('d_h', [toFa(weeklyLeft.inDays), toFa(weeklyLeft.inHours % 24)])
        : _fmt(weeklyLeft);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('daily_reset_in', [_fmt(dailyLeft)]),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            tr('weekly_reset_in', [weeklyStr]),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.completed.withValues(alpha: 0.25),
            AppColors.primary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.completed.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('all_done_today'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('come_back_tomorrow'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends ConsumerWidget {
  const _MissionCard({required this.m});
  final MissionState m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: m.claimed
              ? AppColors.completed.withValues(alpha: 0.5)
              : AppColors.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.def.titleFa,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${toFa(m.progress)} / ${toFa(m.def.target)}',
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            m.def.descFa,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: m.ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHighOf(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                m.done ? AppColors.completed : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                tr('xp_shafaq', [toFa(m.def.xp), toFa(m.def.coins)]),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.starTextOf(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (m.claimed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.completed,
                    ),
                    SizedBox(width: 4),
                    Text(
                      tr('claimed'),
                      style: TextStyle(
                        color: AppColors.completed,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: m.done
                      ? () async {
                          final ok = await ref
                              .read(missionsProvider.notifier)
                              .claim(m.def);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr('mission_reward_claimed', [m.def.titleFa]),
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(tr('claim_reward')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementsTab extends ConsumerWidget {
  const _AchievementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(achievementsProvider.notifier);
    final unlocked = ref.watch(achievementsProvider);
    final all = notifier.all;
    final ctx = notifier.ctx;
    final eco = Economy(Hive.box<String>(Boxes.meta));

    final cats = <String, List<AchievementDef>>{};
    for (final a in all) {
      cats.putIfAbsent(a.categoryFa, () => []).add(a);
    }

    // تازه بازشده‌ها (۵ تای اخیر)
    final recent = unlocked.toList()
      ..sort(
        (a, b) => (eco.achievementUnlockedAt(b) ?? 0).compareTo(
          eco.achievementUnlockedAt(a) ?? 0,
        ),
      );
    final recentDefs = [
      for (final id in recent.take(5))
        for (final d in all)
          if (d.id == id) d,
    ];

    // نزدیک‌ترین‌ها: قفل ولی پیشرفت > ۰، مرتب بر اساس پیشرفت
    final almost =
        [
          for (final d in all)
            if (!unlocked.contains(d.id)) d,
        ]..sort(
          (a, b) =>
              b.progressOf(ctx, false).compareTo(a.progressOf(ctx, false)),
        );
    final almostTop = almost
        .where((d) => d.progressOf(ctx, false) > 0)
        .take(5)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: AppColors.starTextOf(context),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('of_achievements_unlocked', [
                    toFa(unlocked.length),
                    toFa(all.length),
                  ]),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: all.isEmpty ? 0 : unlocked.length / all.length,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceHighOf(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.star,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (recentDefs.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionTitle(tr('recently_unlocked')),
          const SizedBox(height: 10),
          for (final d in recentDefs)
            _AchievementRow(a: d, unlocked: true, ctx: ctx),
        ],
        if (almostTop.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionTitle(tr('almost_there')),
          const SizedBox(height: 10),
          for (final d in almostTop)
            _AchievementRow(a: d, unlocked: false, ctx: ctx),
        ],
        const SizedBox(height: 16),
        for (final entry in cats.entries) ...[
          SectionTitle(
            '${entry.key} (${toFa(entry.value.where((d) => unlocked.contains(d.id)).length)}/${toFa(entry.value.length)})',
          ),
          const SizedBox(height: 10),
          for (final a in entry.value)
            _AchievementRow(a: a, unlocked: unlocked.contains(a.id), ctx: ctx),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AchievementRow extends ConsumerWidget {
  const _AchievementRow({
    required this.a,
    required this.unlocked,
    required this.ctx,
  });
  final AchievementDef a;
  final bool unlocked;
  final AchCtx ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = a.hidden && !unlocked;
    final progress = a.progressOf(ctx, unlocked);
    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked
                ? AppColors.star.withValues(alpha: 0.5)
                : AppColors.borderOf(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: unlocked
                    ? AppColors.star.withValues(alpha: 0.15)
                    : AppColors.surfaceHighOf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                unlocked
                    ? Icons.emoji_events_rounded
                    : hidden
                    ? Icons.question_mark_rounded
                    : Icons.lock_outline_rounded,
                color: unlocked
                    ? AppColors.starTextOf(context)
                    : AppColors.textSecondaryOf(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hidden ? tr('hidden_achievement') : a.titleFa,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: unlocked
                          ? AppColors.textPrimaryOf(context)
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hidden ? tr('hidden_achievement_desc') : a.descFa,
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                  if (!unlocked && !hidden && progress > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceHighOf(context),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '+${toFa(a.xp)}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primaryTextOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final hidden = a.hidden && !unlocked;
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final at = eco.achievementUnlockedAt(a.id);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? AppColors.star.withValues(alpha: 0.15)
                          : AppColors.surfaceHighOf(ctx),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      unlocked
                          ? Icons.emoji_events_rounded
                          : hidden
                          ? Icons.question_mark_rounded
                          : Icons.lock_outline_rounded,
                      color: unlocked
                          ? AppColors.starTextOf(ctx)
                          : AppColors.textSecondaryOf(ctx),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hidden ? tr('hidden_achievement') : a.titleFa,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.categoryFa,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!hidden) ...[
                Text(
                  tr('how_to_unlock'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryOf(ctx),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.descFa,
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  _detailChip(
                    ctx,
                    '+${toFa(a.xp)} XP',
                    AppColors.primaryTextOf(ctx),
                  ),
                  const SizedBox(width: 8),
                  _detailChip(
                    ctx,
                    tr('shafaq', [toFa(a.coins)]),
                    AppColors.starTextOf(ctx),
                  ),
                  if (at != null) ...[
                    const SizedBox(width: 8),
                    _detailChip(
                      ctx,
                      _dateFa(at),
                      AppColors.textSecondaryOf(ctx),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(BuildContext ctx, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  String _dateFa(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${toFa(d.year)}/${toFa(d.month)}/${toFa(d.day)}';
  }
}

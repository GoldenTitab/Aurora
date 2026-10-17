import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/section_title.dart';
import '../../data/gamification/missions.dart';
import '../../data/models/achievement.dart';
import '../../data/providers.dart';
import '../../data/storage/economy.dart';
import 'cards_tab.dart';
import '../../core/i18n/lang.dart';

/// ناحیه «جوایز»: سطح، کارت‌ها، مأموریت‌ها و اچیومنت‌ها.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(economyProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title:  Text(tr('rewards')),
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
          bottom:  TabBar(
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

// ── تب سطح ────────────────────────────────────────────────────────────

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
                    : tr('xp_to', [toFa(next - xp), Economy.levelNames[level + 1]]),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
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
                color: i == level ? AppColors.primary : AppColors.borderOf(context),
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
                      fontWeight:
                          i == level ? FontWeight.w800 : FontWeight.w600,
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
          tr('completing_a_franchise_50_xp') +
          tr('daily_check_in_5_xp_and_20_shafaq'),
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 13,
            height: 2,
          ),
        ),
      ],
    );
  }
}

// ── تب مأموریت‌ها ─────────────────────────────────────────────────────

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
         SectionTitle(tr('daily_missions')),
        const SizedBox(height: 12),
        for (final m in daily) _MissionCard(m: m),
        const SizedBox(height: 16),
         SectionTitle(tr('weekly_missions')),
        const SizedBox(height: 12),
        for (final m in weekly) _MissionCard(m: m),
      ],
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
                  child:  Text(tr('claim_reward')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── تب اچیومنت‌ها ─────────────────────────────────────────────────────

class _AchievementsTab extends ConsumerWidget {
  const _AchievementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(achievementsProvider.notifier);
    final unlocked = ref.watch(achievementsProvider);
    final all = notifier.all;

    final cats = <String, List<AchievementDef>>{};
    for (final a in all) {
      cats.putIfAbsent(a.categoryFa, () => []).add(a);
    }

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
                  tr('of_achievements_unlocked', [toFa(unlocked.length), toFa(all.length)]),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              SizedBox(
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: all.isEmpty
                        ? 0
                        : unlocked.length / all.length,
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
        const SizedBox(height: 16),
        for (final entry in cats.entries) ...[
          SectionTitle(entry.key),
          const SizedBox(height: 10),
          for (final a in entry.value) _AchievementRow(a: a),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AchievementRow extends ConsumerWidget {
  const _AchievementRow({required this.a});
  final AchievementDef a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(achievementsProvider).contains(a.id);
    return Container(
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
                  : Icons.lock_outline_rounded,
              color: unlocked ? AppColors.starTextOf(context) : AppColors.textSecondaryOf(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.titleFa,
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
                  a.descFa,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
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
    );
  }
}

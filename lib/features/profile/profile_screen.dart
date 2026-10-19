import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/section_title.dart';
import '../../data/gamification/missions.dart';
import '../../data/models/library_stats.dart';
import '../../data/providers.dart';
import '../../data/storage/economy.dart';
import '../../data/storage/migrations.dart';
import '../../core/i18n/lang.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          _ProfileHeader(),
          SizedBox(height: 20),
          _LatestAchievements(),
          SizedBox(height: 20),
          _TodayMissions(),
          SizedBox(height: 20),
          _StatsPreview(),
          SizedBox(height: 20),
          _ToolsMenu(),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(economyProvider);
    final level = eco.level.clamp(0, Economy.levelNames.length - 1);
    final cur = Economy.levelThresholds[level];
    final next = level + 1 < Economy.levelThresholds.length
        ? Economy.levelThresholds[level + 1]
        : null;
    final ratio = next == null
        ? 1.0
        : ((eco.xp - cur) / (next - cur)).clamp(0.0, 1.0).toDouble();
    final days = _daysWithUs();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFF472B6)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    toFa(level + 1),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Economy.levelNames[level],
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.primaryTextOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? '${toFa(eco.xp)} XP'
                          : tr('of_xp', [toFa(eco.xp), toFa(next)]),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    if (days != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tr('days_with_us', [toFa(days)]),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌙', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      toFa(eco.coins),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primaryTextOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.borderOf(context),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                eco.streak > 0
                    ? tr('day_streak', [toFa(eco.streak)])
                    : tr('check_in_today_to_build_your_streak'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// روزهای همراهی؛ اولین بار که دیده می‌شود ذخیره می‌شود.
  int? _daysWithUs() {
    try {
      final box = Hive.box<String>(Boxes.meta);
      var raw = box.get('first_launch');
      if (raw == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        box.put('first_launch', '$now');
        return 1;
      }
      final first = DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
      final days = DateTime.now().difference(first).inDays + 1;
      return days.clamp(1, 100000);
    } catch (_) {
      return null;
    }
  }
}

/// آخرین دستاوردهای بازشده (۵ تای اخیر).
class _LatestAchievements extends ConsumerWidget {
  const _LatestAchievements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(achievementsProvider);
    if (unlocked.isEmpty) return const SizedBox.shrink();
    final defs = {
      for (final d in ref.watch(achievementsProvider.notifier).all) d.id: d,
    };
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final sorted = unlocked.toList()
      ..sort(
        (a, b) => (eco.achievementUnlockedAt(b) ?? 0).compareTo(
          eco.achievementUnlockedAt(a) ?? 0,
        ),
      );
    final recent = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(tr('latest_achievements'))),
            TextButton(
              onPressed: () => context.push('/rewards'),
              child: Text(tr('more')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final d = defs[recent[i]];
              if (d == null) return const SizedBox.shrink();
              return Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.star.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.star,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.titleFa,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${toFa(d.xp)} XP',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryTextOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// ماموریت‌های امروز — فشرده.
class _TodayMissions extends ConsumerWidget {
  const _TodayMissions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(missionsProvider);
    final daily = missions
        .where((m) => m.def.period == MissionPeriod.daily)
        .toList();
    if (daily.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(tr('todays_missions'))),
            TextButton(
              onPressed: () => context.push('/rewards'),
              child: Text(tr('more')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < daily.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              daily[i].def.titleFa,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: daily[i].ratio,
                                minHeight: 5,
                                backgroundColor: AppColors.surfaceHighOf(
                                  context,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  daily[i].done
                                      ? AppColors.completed
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${toFa(daily[i].progress)}/${toFa(daily[i].def.target)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < daily.length - 1)
                  Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: AppColors.borderOf(context),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// پیش‌نمایش آمار.
class _StatsPreview extends ConsumerWidget {
  const _StatsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(libraryStatsProvider);
    final total =
        stats.started +
        stats.completed +
        stats.planToWatch +
        stats.onHold +
        stats.dropped;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('watch_stats')),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => context.push('/stats'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              children: [
                _miniStat(
                  context,
                  toFa(total),
                  tr('my_list'),
                  AppColors.primaryTextOf(context),
                ),
                _miniStat(
                  context,
                  toFa(stats.totalWatchedEpisodes),
                  tr('episodes'),
                  AppColors.completed,
                ),
                _miniStat(
                  context,
                  toFa(
                    LibraryStats.formatMinutes(stats.totalWatchedMinutes),
                  ),
                  tr('watch_time'),
                  AppColors.onHold,
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsMenu extends StatelessWidget {
  const _ToolsMenu();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.schedule_outlined, tr('watch_plan'), '/plan'),
      (
        Icons.calendar_month_outlined,
        tr('weekly_airing_calendar'),
        '/calendar',
      ),
      (Icons.bar_chart_outlined, tr('watch_stats'), '/stats'),
      (Icons.emoji_events_outlined, tr('rewards_collection'), '/rewards'),
      (Icons.download_outlined, tr('import_list'), '/import'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('tools')),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _MenuTile(
                  icon: items[i].$1,
                  label: items[i].$2,
                  route: items[i].$3,
                ),
                if (i != items.length - 1)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.borderOf(context),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primaryTextOf(context), size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: AppColors.textSecondaryOf(context),
      ),
      onTap: () => context.push(route),
    );
  }
}

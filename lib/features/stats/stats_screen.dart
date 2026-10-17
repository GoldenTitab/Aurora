import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/route_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/section_title.dart';
import '../../data/models/library_stats.dart';
import '../../data/models/watch_status.dart';
import '../../data/providers.dart';
import '../../core/i18n/lang.dart';

/// صفحه داشبورد آمار تماشا.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(libraryStatsProvider);

    return Scaffold(
      appBar: AppBar(title:  Text(tr('watch_stats'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
           Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('statuses')),
          ),
          _StatusGrid(stats: stats),
           Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('watch_time')),
          ),
          _TimeCards(stats: stats),
           Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('streak_activity')),
          ),
          const _StreakCard(),
          const SizedBox(height: 12),
          const _Heatmap(),
           Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('most_watched_franchises')),
          ),
          _TopFranchises(stats: stats),
        ],
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final entries = <(WatchStatus, int)>[
      (WatchStatus.watching, stats.started),
      (WatchStatus.completed, stats.completed),
      (WatchStatus.planToWatch, stats.planToWatch),
      (WatchStatus.onHold, stats.onHold),
      (WatchStatus.dropped, stats.dropped),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        for (final e in entries)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(e.$1.icon, color: e.$1.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        toFa(e.$2),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        e.$1.labelFa,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimeCards extends StatelessWidget {
  const _TimeCards({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeCard(
            label: tr('time_watched'),
            value: toFa(
              LibraryStats.formatMinutes(stats.totalWatchedMinutes),
            ),
            sub: tr('episodes_watched', [toFa(stats.totalWatchedEpisodes)]),
            accent: AppColors.completed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TimeCard(
            label: tr('time_remaining'),
            value: toFa(
              LibraryStats.formatMinutes(stats.totalRemainingMinutes),
            ),
            sub: null,
            accent: AppColors.onHold,
          ),
        ),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    required this.accent,
    this.sub,
  });
  final String label;
  final String value;
  final String? sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// کارت استریک تماشای روزهای متوالی.
class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.onHold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.onHold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.onHold,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('days_in_a_row', [toFa(streak)]),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tr('watch_at_least_one_episode_a_day_to_keep_your_st'),
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
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

/// هیت‌مپ فعالیت ۲۶ هفته اخیر (به سبک گیت‌هاب).
class _Heatmap extends ConsumerWidget {
  const _Heatmap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(heatmapProvider);
    if (days.isEmpty) return const SizedBox.shrink();

    const weeks = 26;
    final cells = days.length >= weeks * 7
        ? days.sublist(days.length - weeks * 7)
        : days;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            tr('last_26_weeks_of_activity'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var w = 0; w < weeks; w++)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Column(
                      children: [
                        for (var d = 0; d < 7; d++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: _cell(
                              w * 7 + d < cells.length
                                  ? cells[w * 7 + d].count
                                  : 0,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                tr('less'),
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 10,
                ),
              ),
              SizedBox(width: 6),
              _LegendBox(level: 0),
              _LegendBox(level: 1),
              _LegendBox(level: 2),
              _LegendBox(level: 3),
              _LegendBox(level: 4),
              SizedBox(width: 6),
              Text(
                tr('more'),
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(int count) {
    final level = count <= 0
        ? 0
        : count == 1
            ? 1
            : count <= 3
                ? 2
                : count <= 6
                    ? 3
                    : 4;
    return _HeatBox(level: level);
  }
}

class _HeatBox extends StatelessWidget {
  const _HeatBox({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      0 => AppColors.surfaceHighOf(context),
      1 => AppColors.primary.withValues(alpha: 0.25),
      2 => AppColors.primary.withValues(alpha: 0.5),
      3 => AppColors.primary.withValues(alpha: 0.75),
      _ => AppColors.primary,
    };
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _LegendBox extends StatelessWidget {
  const _LegendBox({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 3),
        child: _HeatBox(level: level),
      );
}

class _TopFranchises extends StatelessWidget {
  const _TopFranchises({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.topFranchises.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          tr('no_titles_logged_yet'),
          style: TextStyle(color: AppColors.textSecondaryOf(context)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < stats.topFranchises.length; i++) ...[
            _FranchiseRow(stat: stats.topFranchises[i]),
            if (i < stats.topFranchises.length - 1)
              Divider(height: 1, color: AppColors.borderOf(context)),
          ],
        ],
      ),
    );
  }
}

class _FranchiseRow extends StatelessWidget {
  const _FranchiseRow({required this.stat});
  final FranchiseStat stat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        franchiseRouteFor(stat.anilistId, stat.franchiseId),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 66,
                child: CoverImage(url: stat.cover, cacheWidth: 140),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.titleFa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('episodes_2', [toFa(stat.watchedEpisodes), toFa(LibraryStats.formatMinutes(stat.watchedMinutes))]),
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

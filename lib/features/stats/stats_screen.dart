import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/route_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/section_title.dart';
import '../../data/models/library_stats.dart';
import '../../data/models/watch_status.dart';
import '../../data/providers.dart';
import '../../data/storage/economy.dart';
import '../../data/storage/migrations.dart';
import '../../core/i18n/lang.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(libraryStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('watch_stats'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('statuses')),
          ),
          _StatusGrid(stats: stats),
          const SizedBox(height: 4),
          _OverviewCards(stats: stats),
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
            child: SectionTitle(tr('score_distribution')),
          ),
          const _ScoreHistogram(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('top_genres')),
          ),
          const _TopGenres(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('weekly_activity')),
          ),
          const _WeeklyActivity(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('most_watched_franchises')),
          ),
          _TopFranchises(stats: stats),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SectionTitle(tr('records')),
          ),
          const _Records(),
        ],
      ),
    );
  }
}

/// نمای کلی: تعداد انیمه، قسمت‌ها، ساعت (تقریبی)، میانگین امتیاز.
class _OverviewCards extends ConsumerWidget {
  const _OverviewCards({required this.stats});
  final LibraryStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myListFranchisesProvider);
    final eco = Economy(Hive.box<String>(Boxes.meta));
    var sum = 0, n = 0;
    for (final i in items) {
      final r = eco.fratingOf(i.franchise.id);
      if (r != null) {
        sum += r;
        n++;
      }
    }
    final mean = n == 0 ? null : sum / n;
    final totalTitles =
        stats.started +
        stats.completed +
        stats.planToWatch +
        stats.onHold +
        stats.dropped;
    return Row(
      children: [
        Expanded(
          child: _OverviewCard(
            label: tr('titles'),
            value: toFa(totalTitles),
            accent: AppColors.primaryTextOf(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            label: tr('episodes'),
            value: toFa(stats.totalWatchedEpisodes),
            accent: AppColors.completed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            label: '${tr('hours')} (${tr('estimated')})',
            value: toFa((stats.totalWatchedMinutes / 60).round()),
            accent: AppColors.onHold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OverviewCard(
            label: tr('mean_score'),
            value: mean == null ? '—' : toFa(mean.toStringAsFixed(1)),
            accent: AppColors.starTextOf(context),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// هیستوگرام امتیازهای ۱ تا ۱۰.
class _ScoreHistogram extends ConsumerWidget {
  const _ScoreHistogram();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myListFranchisesProvider);
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final buckets = List<int>.filled(10, 0);
    for (final i in items) {
      final r = eco.fratingOf(i.franchise.id);
      if (r != null && r >= 1 && r <= 10) buckets[r - 1]++;
    }
    final max = buckets.fold<int>(0, (a, b) => a > b ? a : b);
    if (max == 0) return _empty(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 10; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    buckets[i] == 0 ? '' : toFa(buckets[i]),
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: (buckets[i] / max * 90).clamp(4.0, 90.0),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppColors.star.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    toFa(i + 1),
                    style: TextStyle(
                      fontSize: 10,
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

/// ژانرهای برتر لیست.
class _TopGenres extends ConsumerWidget {
  const _TopGenres();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(myListFranchisesProvider);
    final counts = <String, int>{};
    for (final i in items) {
      for (final g in i.franchise.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final list = top.take(6).toList();
    if (list.isEmpty) return _empty(context);
    final max = list.first.value;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          for (final e in list) ...[
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    e.key,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max == 0 ? 0 : e.value / max,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceHighOf(context),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    toFa(e.value),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// فعالیت ۸ هفته‌ی اخیر.
class _WeeklyActivity extends ConsumerWidget {
  const _WeeklyActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(heatmapProvider);
    if (days.isEmpty) return _empty(context);
    final cells = days.length >= 56 ? days.sublist(days.length - 56) : days;
    final weeks = <int>[];
    for (var i = 0; i < cells.length; i += 7) {
      var sum = 0;
      for (var j = i; j < i + 7 && j < cells.length; j++) {
        sum += cells[j].count;
      }
      weeks.add(sum);
    }
    while (weeks.length < 8) {
      weeks.insert(0, 0);
    }
    final last8 = weeks.length > 8 ? weeks.sublist(weeks.length - 8) : weeks;
    final max = last8.fold<int>(0, (a, b) => a > b ? a : b);
    if (max == 0) return _empty(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < last8.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    last8[i] == 0 ? '' : toFa(last8[i]),
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: (last8[i] / max * 90).clamp(4.0, 90.0),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.completed.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('week_n', [toFa(i + 1)]),
                    style: TextStyle(
                      fontSize: 9,
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

/// رکوردها.
class _Records extends ConsumerWidget {
  const _Records();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = Economy(Hive.box<String>(Boxes.meta));
    final days = ref.watch(heatmapProvider);
    final maxDay = days.fold<int>(0, (a, e) => e.count > a ? e.count : a);
    final items = ref.watch(myListFranchisesProvider);
    String? topTitle;
    int topScore = 0;
    for (final i in items) {
      final r = eco.fratingOf(i.franchise.id) ?? 0;
      if (r > topScore) {
        topScore = r;
        topTitle = i.franchise.titleFa;
      }
    }
    final records = [
      (tr('longest_streak'), toFa(eco.maxStreak()), Icons.local_fire_department_rounded),
      (
        tr('most_episodes_in_a_day'),
        toFa(maxDay),
        Icons.bolt_rounded,
      ),
      (
        tr('highest_rated'),
        topTitle == null ? '—' : '$topTitle (${toFa(topScore)}/10)',
        Icons.star_rounded,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < records.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    records[i].$3,
                    color: AppColors.starTextOf(context),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      records[i].$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      records[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            if (i < records.length - 1)
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
}

Widget _empty(BuildContext context) {
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
            value: toFa(LibraryStats.formatMinutes(stats.totalWatchedMinutes)),
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
        border: Border.all(color: AppColors.onHold.withValues(alpha: 0.4)),
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
      onTap: () =>
          context.push(franchiseRouteFor(stat.anilistId, stat.franchiseId)),
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
                    tr('episodes_2', [
                      toFa(stat.watchedEpisodes),
                      toFa(LibraryStats.formatMinutes(stat.watchedMinutes)),
                    ]),
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

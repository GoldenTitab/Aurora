import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/home_items.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../core/i18n/lang.dart';

class WeeklyCalendarScreen extends ConsumerStatefulWidget {
  const WeeklyCalendarScreen({super.key});

  @override
  ConsumerState<WeeklyCalendarScreen> createState() =>
      _WeeklyCalendarScreenState();
}

class _WeeklyCalendarScreenState extends ConsumerState<WeeklyCalendarScreen> {
  bool _onlyMine = false;
  final _scroll = ScrollController();
  final _dayKeys = <int, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToDay(int weekday) {
    final key = _dayKeys[weekday];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(weeklyAiringProvider);
    final inList = {
      for (final i in ref.watch(myListFranchisesProvider))
        i.franchise.anilistId,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('weekly_airing_calendar')),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('only_my_list'),
                style: const TextStyle(fontSize: 12),
              ),
              Switch(
                value: _onlyMine,
                onChanged: (v) => setState(() => _onlyMine = v),
              ),
            ],
          ),
        ],
      ),
      body: async.when(
        loading: () => LoadingView(message: tr('loading_calendar')),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(weeklyAiringProvider),
        ),
        data: (days) {
          final shown = _onlyMine
              ? [
                  for (final d in days)
                    AiringDay(
                      weekday: d.weekday,
                      items: d.items
                          .where((e) => inList.contains(e.franchiseAnilistId))
                          .toList(),
                    ),
                ]
              : days;
          final total = shown.fold<int>(0, (s, d) => s + d.items.length);
          if (total == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      _onlyMine
                          ? tr('no_episodes_from_your_list')
                          : tr('no_episodes_today'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              _DayStrip(
                days: shown,
                onTap: _jumpToDay,
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final d = shown[i];
                    if (d.items.isEmpty) return const SizedBox.shrink();
                    _dayKeys[d.weekday] ??= GlobalKey();
                    return _DaySection(
                      key: _dayKeys[d.weekday],
                      day: d,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// نوار روزها با تعداد قسمت هر روز.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days, required this.onTap});
  final List<AiringDay> days;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderOf(context)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final isToday = d.weekday == today;
          return InkWell(
            onTap: () => onTap(d.weekday),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday
                      ? AppColors.primary
                      : AppColors.borderOf(context),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AiringDay.weekdayFa[d.weekday],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isToday
                          ? AppColors.primaryTextOf(context)
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    toFa(d.items.length),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isToday
                          ? AppColors.primaryTextOf(context)
                          : AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({super.key, required this.day});
  final AiringDay day;

  bool get _isToday => DateTime.now().weekday == day.weekday;

  @override
  Widget build(BuildContext context) {
    final items = [...day.items]
      ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(
                AiringDay.weekdayFa[day.weekday],
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _isToday
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : AppColors.surfaceHighOf(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isToday ? tr('today') : toFa(items.length),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _isToday
                        ? AppColors.primaryTextOf(context)
                        : AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final e in items) _AiringRow(entry: e, isToday: _isToday),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AiringRow extends ConsumerWidget {
  const _AiringRow({required this.entry, required this.isToday});
  final AiringEntry entry;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.airingAt * 1000);
    final time =
        '${toFa(dt.hour.toString().padLeft(2, '0'))}:${toFa(dt.minute.toString().padLeft(2, '0'))}';
    final countdown = isToday ? _countdown(entry.airingAt) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/franchise/${entry.franchiseAnilistId}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 62,
                    child: CoverImage(url: entry.cover, cacheWidth: 140),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.franchiseTitleFa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: dirFor(entry.franchiseTitleFa),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tr('episode', [toFa(entry.episode)]),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryTextOf(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (countdown != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          countdown,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.completed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _countdown(int airingAtSec) {
    final diff = DateTime.fromMillisecondsSinceEpoch(
      airingAtSec * 1000,
    ).difference(DateTime.now());
    if (diff.isNegative) return tr('aired');
    if (diff.inHours < 1) {
      return tr('in_minutes', [toFa(diff.inMinutes.clamp(1, 59))]);
    }
    if (diff.inHours < 24) return tr('in_hours', [toFa(diff.inHours)]);
    return tr('in_days', [toFa(diff.inDays)]);
  }
}

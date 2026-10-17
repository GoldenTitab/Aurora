import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/route_utils.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/home_items.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../core/i18n/lang.dart';

/// صفحه تقویم پخش هفتگی.
class WeeklyCalendarScreen extends ConsumerWidget {
  const WeeklyCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyAiringProvider);

    return Scaffold(
      appBar: AppBar(
        title:  Text(tr('weekly_airing_calendar')),
        actions: [
          IconButton(
            tooltip: tr('refresh'),
            onPressed: () => ref.invalidate(weeklyAiringProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () =>  LoadingView(
          message: tr('fetching_airing_schedule'),
        ),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(weeklyAiringProvider),
        ),
        data: (days) => days.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('no_new_episodes_to_show') +
                    tr('open_airing_anime_to_add_them_to_the_calendar'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      height: 1.8,
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: days.length,
                itemBuilder: (context, i) => _DaySection(day: days[i]),
              ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});
  final AiringDay day;

  @override
  Widget build(BuildContext context) {
    final isToday = day.weekday == DateTime.now().weekday;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Text(
                  day.labelFa,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isToday
                        ? AppColors.primaryTextOf(context)
                        : AppColors.textPrimaryOf(context),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tr('today'),
                      style: TextStyle(
                        color: AppColors.primaryTextOf(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: isToday
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    )
                  : null,
            ),
            child: Column(
              children: [
                for (var i = 0; i < day.items.length; i++) ...[
                  _AiringRow(entry: day.items[i]),
                  if (i < day.items.length - 1)
                    Divider(height: 1, color: AppColors.borderOf(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiringRow extends StatelessWidget {
  const _AiringRow({required this.entry});
  final AiringEntry entry;

  String get _timeFa {
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.airingAt * 1000);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return toFa('$hh:$mm');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        franchiseRouteFor(entry.franchiseAnilistId, entry.entryId),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 64,
                child: CoverImage(url: entry.cover, cacheWidth: 140),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.entryTitle,
                    textDirection: dirFor(entry.entryTitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.franchiseTitleFa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tr('episode', [toFa(entry.episode)]),
                          style: TextStyle(
                            color: AppColors.primaryTextOf(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeFa,
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

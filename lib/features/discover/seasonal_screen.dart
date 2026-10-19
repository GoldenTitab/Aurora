import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import 'filter_screen.dart' show formatOptions;
import '../../core/i18n/lang.dart';

class SeasonalScreen extends ConsumerStatefulWidget {
  const SeasonalScreen({super.key});

  @override
  ConsumerState<SeasonalScreen> createState() => _SeasonalScreenState();
}

class _SeasonalScreenState extends ConsumerState<SeasonalScreen> {
  String _format = '';
  String _sort = 'POPULARITY_DESC';
  bool _hideWatched = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('seasonal_chart')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('current_season')),
              Tab(text: tr('next_season')),
              Tab(text: tr('last_season')),
            ],
          ),
        ),
        body: Column(
          children: [
            _FilterBar(
              format: _format,
              sort: _sort,
              hideWatched: _hideWatched,
              onFormat: (v) => setState(() => _format = v),
              onSort: (v) => setState(() => _sort = v),
              onHideWatched: (v) => setState(() => _hideWatched = v),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SeasonGrid(provider: seasonalAllProvider),
                  _SeasonGrid(
                    provider: seasonalNextProvider,
                    showCountdown: true,
                  ),
                  _SeasonGrid(provider: seasonalPrevProvider),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AnimeCardData> _applyFilters(
    List<AnimeCardData> items,
    Set<int> inList,
  ) {
    var out = items;
    if (_format.isNotEmpty) {
      out = out.where((d) => d.format == _format).toList();
    }
    if (_hideWatched) {
      out = out.where((d) => !inList.contains(d.anilistId)).toList();
    }
    switch (_sort) {
      case 'SCORE_DESC':
        out = [...out]..sort((a, b) => b.score.compareTo(a.score));
      case 'START_DATE_DESC':
        out = [...out]..sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
    }
    return out;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.format,
    required this.sort,
    required this.hideWatched,
    required this.onFormat,
    required this.onSort,
    required this.onHideWatched,
  });

  final String format;
  final String sort;
  final bool hideWatched;
  final ValueChanged<String> onFormat;
  final ValueChanged<String> onSort;
  final ValueChanged<bool> onHideWatched;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderOf(context)),
        ),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kv in formatOptions.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(kv.value),
                      selected: format == kv.key,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onFormat(kv.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${tr('sort_by')}:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: sort,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryTextOf(context),
                  fontWeight: FontWeight.w700,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'POPULARITY_DESC',
                    child: Text(tr('sort_popularity')),
                  ),
                  DropdownMenuItem(
                    value: 'SCORE_DESC',
                    child: Text(tr('sort_score')),
                  ),
                  DropdownMenuItem(
                    value: 'START_DATE_DESC',
                    child: Text(tr('sort_year')),
                  ),
                ],
                onChanged: (v) => onSort(v ?? 'POPULARITY_DESC'),
              ),
              const Spacer(),
              InkWell(
                onTap: () => onHideWatched(!hideWatched),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: hideWatched,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => onHideWatched(v ?? false),
                    ),
                    Text(
                      tr('hide_watched'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeasonGrid extends ConsumerWidget {
  const _SeasonGrid({required this.provider, this.showCountdown = false});

  final FutureProvider<List<AnimeCardData>> provider;
  final bool showCountdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final state = context.findAncestorStateOfType<_SeasonalScreenState>();
    final inList = {
      for (final i in ref.watch(myListFranchisesProvider))
        i.franchise.anilistId,
    };

    return async.when(
      loading: () => LoadingView(message: tr('loading_seasonal_chart')),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (items) {
        final list = state?._applyFilters(items, inList) ?? items;
        return CustomScrollView(
          slivers: [
            if (showCountdown)
              const SliverToBoxAdapter(child: _NextSeasonCountdown()),
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      tr('no_results_match_these_filters'),
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.62,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                      ),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final d = list[i];
                    final owned = inList.contains(d.anilistId);
                    return Stack(
                      children: [
                        AnimeCard(
                          data: d,
                          onTap: () =>
                              context.push('/franchise/${d.anilistId}'),
                        ),
                        if (owned)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tr('in_your_list'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }, childCount: list.length),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NextSeasonCountdown extends StatelessWidget {
  const _NextSeasonCountdown();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = nextSeasonStart(now);
    final days = start.difference(now).inDays;
    if (days <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: AppColors.primaryTextOf(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr('days_until_next_season', [toFa(days)]),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryTextOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

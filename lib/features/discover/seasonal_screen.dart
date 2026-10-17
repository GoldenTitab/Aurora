import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../core/i18n/lang.dart';

/// چارت فصلی: تب فصل جاری و فصل بعد.
class SeasonalScreen extends ConsumerWidget {
  const SeasonalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title:  Text(tr('seasonal_chart')),
          bottom:  TabBar(
            tabs: [
              Tab(text: tr('this_season')),
              Tab(text: tr('next_season_2')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SeasonGrid(kind: _SeasonKind.current),
            _SeasonGrid(kind: _SeasonKind.next),
          ],
        ),
      ),
    );
  }
}

enum _SeasonKind { current, next }

class _SeasonGrid extends ConsumerWidget {
  const _SeasonGrid({required this.kind});
  final _SeasonKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = kind == _SeasonKind.current
        ? ref.watch(discoverSectionProvider(DiscoverSection.seasonal))
            .whenData((d) => d.items)
        : ref.watch(seasonalNextProvider);

    return async.when(
      loading: () => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const AnimeCardSkeleton(),
      ),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () => kind == _SeasonKind.current
            ? ref.invalidate(
                discoverSectionProvider(DiscoverSection.seasonal))
            : ref.invalidate(seasonalNextProvider),
      ),
      data: (items) => _grid(context, ref, items),
    );
  }

  Widget _grid(BuildContext context, WidgetRef ref, List<AnimeCardData> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          tr('no_results_found'),
          style: TextStyle(color: AppColors.textSecondaryOf(context)),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        if (kind == _SeasonKind.current) {
          await ref
              .read(discoverSectionProvider(DiscoverSection.seasonal).notifier)
              .refresh();
        } else {
          ref.invalidate(seasonalNextProvider);
        }
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => AnimeCard(
          data: items[i],
          onTap: () => context.push('/franchise/${items[i].anilistId}'),
        ),
      ),
    );
  }
}

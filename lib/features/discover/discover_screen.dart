import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/section_title.dart';
import '../../data/homewidget/home_widget_service.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import 'widgets/continue_watching.dart';
import 'widgets/new_episodes_banner.dart';
import '../../core/i18n/lang.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('discover')),
        actions: [
          IconButton(
            tooltip: tr('seasonal_chart'),
            onPressed: () => context.push('/seasonal'),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: 4 + DiscoverSection.values.length,
              itemBuilder: (context, i) {
                if (i == 0) return const _HomeWidgetSync();
                if (i == 1) return const ContinueWatching();
                if (i == 2) return const NewEpisodesBanner();
                if (i == 3) return const _RecommendationsRow();
                return _DiscoverBlock(section: DiscoverSection.values[i - 4]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsRow extends ConsumerWidget {
  const _RecommendationsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recommendationsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return _Row(
          title: tr('if_you_liked_this'),
          items: items,
          rankDelta: const {},
        );
      },
    );
  }
}

class _DiscoverBlock extends ConsumerWidget {
  const _DiscoverBlock({required this.section});
  final DiscoverSection section;

  static const double _rowHeight = 236;
  static const double _cardWidth = 138;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(discoverSectionProvider(section));

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: SectionTitle(section.titleFa)),
                TextButton(
                  onPressed: () => context.push('/discover/${section.name}'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTextOf(context),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('more'),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _rowHeight,
            child: async.when(
              loading: () => ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => const SizedBox(
                  width: _cardWidth,
                  child: AnimeCardSkeleton(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(discoverSectionProvider(section)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(friendlyError(e)),
                  ),
                ),
              ),
              data: (data) =>
                  _Row(title: '', items: data.items, rankDelta: data.rankDelta),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.items,
    required this.rankDelta,
  });

  final String title;
  final List<AnimeCardData> items;
  final Map<int, int> rankDelta;

  static const double _cardWidth = 138;

  @override
  Widget build(BuildContext context) {
    if (title.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SectionTitle(title),
          ),
          const SizedBox(height: 12),
          _cards(context),
        ],
      );
    }
    return _cards(context);
  }

  Widget _cards(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          tr('no_results_found'),
          style: TextStyle(color: AppColors.textSecondaryOf(context)),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final d = items[i];
        final delta = rankDelta[d.anilistId];
        return SizedBox(
          width: _cardWidth,
          child: Stack(
            children: [
              AnimeCard(
                data: d,
                onTap: () => context.push('/franchise/${d.anilistId}'),
              ),
              if (delta != null && delta != 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: delta > 0
                          ? AppColors.completed
                          : AppColors.dropped,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${delta > 0 ? '↑' : '↓'}${toFa(delta.abs())}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeWidgetSync extends ConsumerStatefulWidget {
  const _HomeWidgetSync();

  @override
  ConsumerState<_HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<_HomeWidgetSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshHomeWidget(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(continueWatchingProvider, (_, _) => refreshHomeWidget(ref));
    ref.listen(weeklyAiringProvider, (_, _) => refreshHomeWidget(ref));
    return const SizedBox.shrink();
  }
}

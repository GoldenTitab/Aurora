import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../discover/filter_screen.dart';
import '../../core/i18n/lang.dart';

Future<void> openAnimeCard(
  BuildContext context,
  WidgetRef ref,
  AnimeCardData d,
) async {
  if (d.resolvable) {
    context.push('/franchise/${d.anilistId}');
    return;
  }
  if (d.malId <= 0) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text(tr('fetching_full_details'))));
  try {
    final f = await ref
        .read(franchiseRepositoryProvider)
        .getFranchiseByMal(d.malId);
    messenger.hideCurrentSnackBar();
    if (context.mounted) {
      if (f.anilistId > 0) {
        context.push('/franchise/${f.anilistId}');
      } else {
        context.push('/franchise/mal-${f.malId}');
      }
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = value.trim();
      setState(() => _query = q);
      if (q.length >= 2) {
        ref.read(searchHistoryProvider.notifier).push(q);
      }
    });
  }

  void _pick(String text) {
    _controller.text = text;
    _debounce?.cancel();
    setState(() => _query = text);
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() => _query = '');
  }

  Widget _body() {
    if (_query.length < 2) return _SearchHint(onPick: _pick);

    final async = ref.watch(searchResultsProvider(_query));
    return async.when(
      loading: () => LoadingView(message: tr('searching')),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(searchResultsProvider(_query)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                tr('no_results_on_anilist_mal_or_jikan_persian_searc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  height: 1.8,
                ),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final d = items[i];
            return AnimeCard(
              data: d,
              onTap: () => openAnimeCard(context, ref, d),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: tr('search_a_persian_or_english_title'),
                        hintStyle: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: tr('clear'),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                onPressed: _clear,
                              ),
                        filled: true,
                        fillColor: AppColors.surfaceOf(context),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(query: _query),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_query.length < 2 ? 'hint' : _query),
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends ConsumerWidget {
  const _FilterButton({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = ref.watch(activeFilterProvider)?.activeCount ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: tr('advanced_filters'),
            onPressed: () {
              final saved = ref.read(activeFilterProvider);
              context.push(
                '/filter',
                extra: saved ?? (query.isEmpty ? null : query),
              );
            },
            icon: Icon(
              Icons.tune_rounded,
              color: AppColors.primaryTextOf(context),
            ),
          ),
          if (activeCount > 0)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  toFa(activeCount),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchHint extends ConsumerWidget {
  const _SearchHint({required this.onPick});
  final ValueChanged<String> onPick;

  static const _genreShortlist = [
    'Action',
    'Comedy',
    'Drama',
    'Fantasy',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Thriller',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final popular = ref.watch(seasonalAllProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('recent_searches'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).clear(),
                child: Text(tr('clear_search_history')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in history)
                ActionChip(
                  label: Text(h),
                  backgroundColor: AppColors.surfaceOf(context),
                  side: BorderSide(color: AppColors.borderOf(context)),
                  avatar: Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  onPressed: () => onPick(h),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Text(
          tr('browse_by_genre'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in _genreShortlist)
              ActionChip(
                label: Text(g, textDirection: TextDirection.ltr),
                backgroundColor: AppColors.surfaceOf(context),
                side: BorderSide(color: AppColors.borderOf(context)),
                onPressed: () => context.push(
                  '/filter',
                  extra: FilterState(genresInclude: {g}),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          tr('popular_this_season'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        popular.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            final top = items.take(8).toList();
            if (top.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: top.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final d = top[i];
                  return SizedBox(
                    width: 132,
                    child: AnimeCard(
                      data: d,
                      onTap: () => openAnimeCard(context, ref, d),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

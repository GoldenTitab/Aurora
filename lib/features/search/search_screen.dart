import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../core/i18n/lang.dart';

/// باز کردن صفحه فرنچایز برای یک کارت؛ اگر کارت فقط MAL/Jikan باشد
/// اول به AniList نگاشت می‌شود وگرنه فرنچایز تک‌عضوی ساخته می‌شود.
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
  messenger.showSnackBar(
     SnackBar(content: Text(tr('fetching_full_details'))),
  );
  try {
    final f = await ref
        .read(franchiseRepositoryProvider)
        .getFranchiseByMal(d.malId);
    messenger.hideCurrentSnackBar();
    if (context.mounted) {
      if (f.anilistId > 0) {
        context.push('/franchise/${f.anilistId}');
      } else {
        // فرنچایز تک‌عضوی MAL — با شناسه منفی مال به صفحه می‌رویم
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
      if (mounted) setState(() => _query = value.trim());
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
      loading: () =>  LoadingView(message: tr('searching')),
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
                style: TextStyle(color: AppColors.textSecondaryOf(context), height: 1.8),
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
            // وقتی آفلاین هستیم بالای فیلد جست‌وجو بنر نشان داده می‌شود.
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
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      tooltip: tr('advanced_filters'),
                      onPressed: () => context.push('/filter'),
                      icon: Icon(
                        Icons.tune_rounded,
                        color: AppColors.primaryTextOf(context),
                      ),
                    ),
                  ),
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

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.onPick});
  final ValueChanged<String> onPick;

  static const _suggestions = [
    'Frieren',
    'Jujutsu Kaisen',
    'Demon Slayer',
    'Spy x Family',
    'Attack on Titan',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 56,
              color: AppColors.primaryTextOf(context),
            ),
            const SizedBox(height: 12),
             Text(
              tr('type_an_anime_title'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              tr('anilist_is_searched_first_if_nothing_is_found_ma'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context), height: 1.7),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    backgroundColor: AppColors.surfaceOf(context),
                    side: BorderSide(color: AppColors.borderOf(context)),
                    onPressed: () => onPick(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../core/i18n/lang.dart';

const List<String> anilistGenres = [
  'Action',
  'Adventure',
  'Comedy',
  'Drama',
  'Fantasy',
  'Horror',
  'Mahou Shoujo',
  'Mecha',
  'Music',
  'Mystery',
  'Psychological',
  'Romance',
  'Sci-Fi',
  'Slice of Life',
  'Sports',
  'Supernatural',
  'Thriller',
  'Avant Garde',
  'Award Winning',
  'Gourmet',
  'Suspense',
];

/// گزینه‌های فرمت (کلید → برچسب نمایشی به زبان فعلی).
Map<String, String> get formatOptions => {
  '': tr('all'),
  'TV': tr('tv_series'),
  'MOVIE': tr('movie'),
  'OVA': 'OVA',
  'ONA': 'ONA',
  'SPECIAL': tr('special'),
};

/// فیلتر ترکیبی پیشرفته: ژانر + امتیاز + سال + قسمت + فرمت + استودیو.
class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  final _genres = <String>{};
  RangeValues _score = const RangeValues(0, 10);
  RangeValues _year = RangeValues(1980, DateTime.now().year.toDouble());
  RangeValues _episodes = const RangeValues(1, 50);
  String _format = '';
  final _studioCtrl = TextEditingController();

  bool _searched = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _page = 0;
  String? _error;
  final _items = <AnimeCardData>[];
  final _seen = <int>{};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.pixels >= p.maxScrollExtent - 600) _loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _studioCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searched = true;
      _loading = true;
      _error = null;
      _items.clear();
      _seen.clear();
      _page = 0;
      _hasNext = true;
    });
    await _loadMore();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (!_searched || _loadingMore || !_hasNext) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final r = await ref.read(anilistClientProvider).advancedBrowse(
            page: _page + 1,
            genres: _genres.isEmpty ? null : _genres.toList(),
            scoreMin: _score.start.round() <= 0
                ? null
                : _score.start.round() * 10,
            scoreMax: _score.end.round() >= 10
                ? null
                : _score.end.round() * 10,
            yearMin: _year.start.round(),
            yearMax: _year.end.round() >= DateTime.now().year ? null : _year.end.round(),
            epMin: _episodes.start.round() <= 1 ? null : _episodes.start.round(),
            epMax: _episodes.end.round() >= 50 ? null : _episodes.end.round(),
            format: _format.isEmpty ? null : _format,
          );
      if (!mounted) return;
      final studio = _studioCtrl.text.trim().toLowerCase();
      final rawCards = cardsFromRaw(r.items);
      // فیلتر استودیو سمت کاربر (از روی فیلد studios پاسخ API)
      final filtered = <AnimeCardData>[];
      for (var i = 0; i < rawCards.length; i++) {
        final raw = r.items[i];
        if (studio.isNotEmpty) {
          final nodes =
              ((raw['studios'] as Map?)?['nodes'] as List?) ?? const [];
          final names = nodes.map(
            (e) => ((e as Map)['name'] as String? ?? '').toLowerCase(),
          );
          if (!names.any((n) => n.contains(studio))) continue;
        }
        filtered.add(rawCards[i]);
      }
      setState(() {
        _page += 1;
        _hasNext = r.hasNext;
        for (final c in filtered) {
          if (_seen.add(c.anilistId)) _items.add(c);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text(tr('advanced_filters'))),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _filters()),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null && _items.isEmpty)
            SliverToBoxAdapter(
              child: ErrorView(message: _error!, onRetry: _search),
            )
          else if (_searched && _items.isEmpty && !_loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    tr('no_results_match_these_filters'),
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                ),
              ),
            )
          else if (_items.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final d = _items[i];
                  return AnimeCard(
                    data: d,
                    onTap: () =>
                        context.push('/franchise/${d.anilistId}'),
                  );
                }, childCount: _items.length),
              ),
            ),
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           SectionTitle(tr('genres')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in anilistGenres)
                FilterChip(
                  label: Text(g, textDirection: TextDirection.ltr),
                  selected: _genres.contains(g),
                  onSelected: (s) => setState(() {
                    if (s) {
                      _genres.add(g);
                    } else {
                      _genres.remove(g);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SectionTitle(
              tr('score_to', [toFa(_score.start.round()), toFa(_score.end.round())])),
          RangeSlider(
            values: _score,
            min: 0,
            max: 10,
            divisions: 20,
            labels: RangeLabels(
              toFa(_score.start.toStringAsFixed(1)),
              toFa(_score.end.toStringAsFixed(1)),
            ),
            onChanged: (v) => setState(() => _score = v),
          ),
          SectionTitle(
              tr('release_year_to', [toFa(_year.start.round()), toFa(_year.end.round())])),
          RangeSlider(
            values: _year,
            min: 1970,
            max: DateTime.now().year.toDouble(),
            divisions: DateTime.now().year - 1970,
            labels: RangeLabels(
              toFa(_year.start.round()),
              toFa(_year.end.round()),
            ),
            onChanged: (v) => setState(() => _year = v),
          ),
          SectionTitle(
              tr('episodes_to', [toFa(_episodes.start.round()), toFa(_episodes.end.round())])),
          RangeSlider(
            values: _episodes,
            min: 1,
            max: 50,
            divisions: 49,
            labels: RangeLabels(
              toFa(_episodes.start.round()),
              toFa(_episodes.end.round()),
            ),
            onChanged: (v) => setState(() => _episodes = v),
          ),
          const SizedBox(height: 8),
           SectionTitle(tr('title_type')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kv in formatOptions.entries)
                ChoiceChip(
                  label: Text(kv.value),
                  selected: _format == kv.key,
                  onSelected: (_) => setState(() => _format = kv.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
           SectionTitle(tr('studio_optional')),
          const SizedBox(height: 10),
          TextField(
            controller: _studioCtrl,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: tr('e_g_mappa'),
              hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
              filled: true,
              fillColor: AppColors.surfaceOf(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search_rounded),
              label:  Text(tr('search_with_these_filters')),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

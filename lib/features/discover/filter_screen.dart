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

Map<String, String> get formatOptions => {
  '': tr('all'),
  'TV': tr('tv_series'),
  'MOVIE': tr('movie'),
  'OVA': 'OVA',
  'ONA': 'ONA',
  'SPECIAL': tr('special'),
};

Map<String, String> get sortOptions => {
  'POPULARITY_DESC': tr('sort_popularity'),
  'SCORE_DESC': tr('sort_score'),
  'START_DATE_DESC': tr('sort_year'),
  'TITLE_ROMAJI': tr('sort_az'),
};

Map<String, String> get statusOptions => {
  '': tr('all'),
  'RELEASING': tr('currently_airing'),
  'FINISHED': tr('status_finished'),
  'NOT_YET_RELEASED': tr('coming_soon'),
};

Map<String, String> get seasonOptions => {
  '': tr('all'),
  'WINTER': tr('winter'),
  'SPRING': tr('spring'),
  'SUMMER': tr('summer'),
  'FALL': tr('fall'),
};

/// وضعیت فیلترهای پیشرفته — بین صفحه‌ی جست‌وجو و فیلتر به اشتراک گذاشته می‌شود.
class FilterState {
  final String query;
  final Set<String> genresInclude;
  final Set<String> genresExclude;
  final double scoreMin;
  final double scoreMax;
  final double yearMin;
  final double yearMax;
  final int seasonYear;
  final String season;
  final String status;
  final double epMin;
  final double epMax;
  final String format;
  final String studio;
  final String sort;

  const FilterState({
    this.query = '',
    this.genresInclude = const {},
    this.genresExclude = const {},
    this.scoreMin = 0,
    this.scoreMax = 10,
    this.yearMin = 1970,
    double? yearMax,
    int? seasonYear,
    this.season = '',
    this.status = '',
    this.epMin = 1,
    this.epMax = 50,
    this.format = '',
    this.studio = '',
    this.sort = 'POPULARITY_DESC',
  }) : yearMax = yearMax ?? 0,
       seasonYear = seasonYear ?? 0;

  int get activeCount {
    var n = 0;
    if (query.trim().isNotEmpty) n++;
    n += genresInclude.length + genresExclude.length;
    if (scoreMin > 0 || scoreMax < 10) n++;
    if (season.isNotEmpty) {
      n++;
    } else if (yearMin > 1970 ||
        (yearMax > 0 && yearMax < DateTime.now().year)) {
      n++;
    }
    if (status.isNotEmpty) n++;
    if (epMin > 1 || epMax < 50) n++;
    if (format.isNotEmpty) n++;
    if (studio.trim().isNotEmpty) n++;
    if (sort != 'POPULARITY_DESC') n++;
    return n;
  }

  FilterState copyWith({
    String? query,
    Set<String>? genresInclude,
    Set<String>? genresExclude,
    double? scoreMin,
    double? scoreMax,
    double? yearMin,
    double? yearMax,
    int? seasonYear,
    String? season,
    String? status,
    double? epMin,
    double? epMax,
    String? format,
    String? studio,
    String? sort,
  }) {
    return FilterState(
      query: query ?? this.query,
      genresInclude: genresInclude ?? this.genresInclude,
      genresExclude: genresExclude ?? this.genresExclude,
      scoreMin: scoreMin ?? this.scoreMin,
      scoreMax: scoreMax ?? this.scoreMax,
      yearMin: yearMin ?? this.yearMin,
      yearMax: yearMax ?? this.yearMax,
      seasonYear: seasonYear ?? this.seasonYear,
      season: season ?? this.season,
      status: status ?? this.status,
      epMin: epMin ?? this.epMin,
      epMax: epMax ?? this.epMax,
      format: format ?? this.format,
      studio: studio ?? this.studio,
      sort: sort ?? this.sort,
    );
  }
}

final activeFilterProvider = StateProvider<FilterState?>((ref) => null);

class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key, this.initialQuery, this.initialFilter});

  /// متن جستجویی که از صفحه‌ی جستجو آمده؛ با فیلترها ترکیب می‌شود.
  final String? initialQuery;

  /// فیلترهای قبلی (برای حفظ وضعیت بین بازدیدها).
  final FilterState? initialFilter;

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  final _genresInclude = <String>{};
  final _genresExclude = <String>{};
  RangeValues _score = const RangeValues(0, 10);
  RangeValues _year = RangeValues(1970, DateTime.now().year.toDouble());
  RangeValues _episodes = const RangeValues(1, 50);
  String _format = '';
  String _season = '';
  int _seasonYear = DateTime.now().year;
  String _status = '';
  String _sort = 'POPULARITY_DESC';
  final _studioCtrl = TextEditingController();
  late final TextEditingController _queryCtrl;

  bool _searched = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _page = 0;
  String? _error;
  final _items = <AnimeCardData>[];
  final _seen = <int>{};
  final _scroll = ScrollController();
  int _searchGen = 0;

  @override
  void initState() {
    super.initState();
    final init = widget.initialFilter;
    if (init != null) {
      _genresInclude.addAll(init.genresInclude);
      _genresExclude.addAll(init.genresExclude);
      _score = RangeValues(init.scoreMin, init.scoreMax);
      _year = RangeValues(
        init.yearMin,
        init.yearMax > 0 ? init.yearMax : DateTime.now().year.toDouble(),
      );
      _episodes = RangeValues(init.epMin, init.epMax);
      _format = init.format;
      _season = init.season;
      _seasonYear = init.seasonYear > 0 ? init.seasonYear : DateTime.now().year;
      _status = init.status;
      _sort = init.sort;
      _studioCtrl.text = init.studio;
      _queryCtrl = TextEditingController(
        text: widget.initialQuery ?? init.query,
      );
    } else {
      _queryCtrl = TextEditingController(text: widget.initialQuery ?? '');
    }
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
    _queryCtrl.dispose();
    super.dispose();
  }

  FilterState _currentState() => FilterState(
    query: _queryCtrl.text.trim(),
    genresInclude: Set.of(_genresInclude),
    genresExclude: Set.of(_genresExclude),
    scoreMin: _score.start,
    scoreMax: _score.end,
    yearMin: _year.start,
    yearMax: _year.end,
    seasonYear: _seasonYear,
    season: _season,
    status: _status,
    epMin: _episodes.start,
    epMax: _episodes.end,
    format: _format,
    studio: _studioCtrl.text.trim(),
    sort: _sort,
  );

  void _clearAll() {
    setState(() {
      _genresInclude.clear();
      _genresExclude.clear();
      _score = const RangeValues(0, 10);
      _year = RangeValues(1970, DateTime.now().year.toDouble());
      _episodes = const RangeValues(1, 50);
      _format = '';
      _season = '';
      _seasonYear = DateTime.now().year;
      _status = '';
      _sort = 'POPULARITY_DESC';
      _studioCtrl.clear();
      _queryCtrl.clear();
    });
    ref.read(activeFilterProvider.notifier).state = null;
  }

  Future<void> _search() async {
    ref.read(activeFilterProvider.notifier).state = _currentState();
    _searchGen++;
    final gen = _searchGen;
    setState(() {
      _searched = true;
      _loading = true;
      _loadingMore = false;
      _error = null;
      _items.clear();
      _seen.clear();
      _page = 0;
      _hasNext = true;
    });
    await _loadMore();
    if (mounted && gen == _searchGen) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_searched || _loadingMore || !_hasNext) {
      return;
    }
    final gen = _searchGen;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final useSeason = _season.isNotEmpty;
      final r = await ref
          .read(anilistClientProvider)
          .advancedBrowse(
            page: _page + 1,
            query: _queryCtrl.text.trim().isEmpty
                ? null
                : _queryCtrl.text.trim(),
            genres: _genresInclude.isEmpty ? null : _genresInclude.toList(),
            genresExclude: _genresExclude.isEmpty
                ? null
                : _genresExclude.toList(),
            scoreMin: (_score.start * 10).round() <= 0
                ? null
                : (_score.start * 10).round(),
            scoreMax: (_score.end * 10).round() >= 100
                ? null
                : (_score.end * 10).round(),
            yearMin: useSeason || _year.start.round() <= 1970
                ? null
                : _year.start.round(),
            yearMax: useSeason || _year.end.round() >= DateTime.now().year
                ? null
                : _year.end.round(),
            seasonYear: useSeason ? _seasonYear : null,
            season: useSeason ? _season : null,
            status: _status.isEmpty ? null : _status,
            epMin: _episodes.start.round() <= 1
                ? null
                : _episodes.start.round(),
            epMax: _episodes.end.round() >= 50 ? null : _episodes.end.round(),
            format: _format.isEmpty ? null : _format,
            sort: _sort,
          );
      if (!mounted || gen != _searchGen) {
        return;
      }
      final studio = _studioCtrl.text.trim().toLowerCase();
      final filtered = <AnimeCardData>[];
      for (final raw in r.items) {
        final converted = cardsFromRaw([raw]);
        if (converted.isEmpty) {
          continue;
        }
        if (studio.isNotEmpty) {
          final nodes =
              ((raw['studios'] as Map?)?['nodes'] as List?) ?? const [];
          final names = nodes.map(
            (e) => ((e as Map)['name'] as String? ?? '').toLowerCase(),
          );
          if (!names.any((n) => n.contains(studio))) {
            continue;
          }
        }
        filtered.add(converted.first);
      }
      setState(() {
        _page += 1;
        _hasNext = r.hasNext;
        for (final c in filtered) {
          if (_seen.add(c.anilistId)) {
            _items.add(c);
          }
        }
      });
    } catch (e) {
      if (mounted && gen == _searchGen) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted && gen == _searchGen) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('advanced_filters')),
        actions: [
          TextButton(onPressed: _clearAll, child: Text(tr('clear_all'))),
        ],
      ),
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
                padding: const EdgeInsets.symmetric(vertical: 48),
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
                    onTap: () => context.push('/franchise/${d.anilistId}'),
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
          SectionTitle(tr('search_2')),
          const SizedBox(height: 10),
          TextField(
            controller: _queryCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: tr('search_a_persian_or_english_title'),
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
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 8),
          _collapse(
            title: tr('genres_include'),
            initiallyOpen: _genresInclude.isNotEmpty,
            child: _genreChips(_genresInclude),
          ),
          _collapse(
            title: tr('genres_exclude'),
            initiallyOpen: _genresExclude.isNotEmpty,
            child: _genreChips(_genresExclude, exclude: true),
          ),
          _collapse(
            title: tr('year_season'),
            initiallyOpen: _season.isNotEmpty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kv in seasonOptions.entries)
                      ChoiceChip(
                        label: Text(kv.value),
                        selected: _season == kv.key,
                        onSelected: (_) => setState(() => _season = kv.key),
                      ),
                  ],
                ),
                if (_season.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        tr('season_year'),
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _seasonYear,
                        items: [
                          for (var y = DateTime.now().year; y >= 1970; y--)
                            DropdownMenuItem(value: y, child: Text(toFa(y))),
                        ],
                        onChanged: (v) =>
                            setState(() => _seasonYear = v ?? _seasonYear),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  SectionTitle(
                    tr('release_year_to', [
                      toFa(_year.start.round()),
                      toFa(_year.end.round()),
                    ]),
                  ),
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
                ],
              ],
            ),
          ),
          _collapse(
            title: tr('title_type'),
            initiallyOpen: _format.isNotEmpty,
            child: Wrap(
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
          ),
          _collapse(
            title: tr('airing_status'),
            initiallyOpen: _status.isNotEmpty,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kv in statusOptions.entries)
                  ChoiceChip(
                    label: Text(kv.value),
                    selected: _status == kv.key,
                    onSelected: (_) => setState(() => _status = kv.key),
                  ),
              ],
            ),
          ),
          _collapse(
            title: tr('sort_by'),
            initiallyOpen: _sort != 'POPULARITY_DESC',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kv in sortOptions.entries)
                  ChoiceChip(
                    label: Text(kv.value),
                    selected: _sort == kv.key,
                    onSelected: (_) => setState(() => _sort = kv.key),
                  ),
              ],
            ),
          ),
          _collapse(
            title: tr('score_to', [
              toFa(_score.start.round()),
              toFa(_score.end.round()),
            ]),
            child: RangeSlider(
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
          ),
          _collapse(
            title: tr('episodes_to', [
              toFa(_episodes.start.round()),
              toFa(_episodes.end.round()),
            ]),
            child: RangeSlider(
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
          ),
          _collapse(
            title: tr('studio_optional'),
            child: TextField(
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
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearAll,
                  child: Text(tr('clear_all')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(tr('apply_filters')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _collapse({
    required String title,
    required Widget child,
    bool initiallyOpen = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: initiallyOpen,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ],
      ),
    );
  }

  Widget _genreChips(Set<String> selected, {bool exclude = false}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in anilistGenres)
          FilterChip(
            label: Text(g, textDirection: TextDirection.ltr),
            selected: selected.contains(g),
            selectedColor: exclude
                ? AppColors.dropped.withValues(alpha: 0.25)
                : null,
            onSelected: (s) => setState(() {
              if (s) {
                selected.add(g);
                // یه ژانر نمی‌تونه هم شامل باشه هم حذف
                (exclude ? _genresInclude : _genresExclude).remove(g);
              } else {
                selected.remove(g);
              }
            }),
          ),
      ],
    );
  }
}

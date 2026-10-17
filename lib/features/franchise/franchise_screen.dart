import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/entry.dart';
import '../../data/models/franchise.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import 'widgets/entry_tile.dart';
import 'widgets/franchise_rating.dart';
import 'widgets/franchise_tree_view.dart';
import 'widgets/manual_add_sheet.dart';
import 'widgets/note_editor.dart';
import 'widgets/watch_order_view.dart';
import '../../core/i18n/lang.dart';

class FranchiseScreen extends ConsumerWidget {
  const FranchiseScreen.anilist({super.key, required this.anilistId})
    : malId = null;

  const FranchiseScreen.mal({super.key, required this.malId}) : anilistId = 0;

  final int anilistId;

  final int? malId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/discover');
    }
  }

  void _retry(WidgetRef ref) {
    if (malId != null) {
      ref.invalidate(franchiseByMalProvider(malId!));
    } else {
      ref.invalidate(franchiseProvider(anilistId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = malId != null
        ? ref.watch(franchiseByMalProvider(malId!))
        : ref.watch(franchiseProvider(anilistId));

    return Scaffold(
      body: async.when(
        loading: () => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: tr('back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _back(context),
            ),
          ),
          body: LoadingView(
            message: tr('loading_franchise_info_it_may_take_a_few_seconds'),
          ),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: tr('back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _back(context),
            ),
          ),
          body: ErrorView(
            message: friendlyError(e),
            onRetry: () => _retry(ref),
          ),
        ),
        data: (f) => _FranchiseBody(
          franchise: f,
          requestedId: anilistId,
          malId: malId,
          onBack: () => _back(context),
        ),
      ),
    );
  }
}

class _FranchiseBody extends ConsumerStatefulWidget {
  const _FranchiseBody({
    required this.franchise,
    required this.requestedId,
    this.malId,
    required this.onBack,
  });

  final Franchise franchise;
  final int requestedId;
  final int? malId;
  final VoidCallback onBack;

  @override
  ConsumerState<_FranchiseBody> createState() => _FranchiseBodyState();
}

class _FranchiseBodyState extends ConsumerState<_FranchiseBody> {
  String _view = 'list';

  Future<void> _reloadAfterManual() async {
    final malId = widget.malId;
    try {
      final repo = ref.read(franchiseRepositoryProvider);
      if (malId != null) {
        await repo.getFranchiseByMal(malId);
        ref.invalidate(franchiseByMalProvider(malId));
      } else {
        await repo.getFranchise(widget.requestedId);
        ref.invalidate(franchiseProvider(widget.requestedId));
      }
    } catch (_) {}
  }

  void _openManualAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ManualAddSheet(
        franchise: widget.franchise,
        onAdded: _reloadAfterManual,
      ),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final malId = widget.malId;
    try {
      final repo = ref.read(franchiseRepositoryProvider);
      if (malId != null) {
        await repo.getFranchiseByMal(malId, forceRefresh: true);
        ref.invalidate(franchiseByMalProvider(malId));
      } else {
        await repo.getFranchise(widget.requestedId, forceRefresh: true);
        ref.invalidate(franchiseProvider(widget.requestedId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  List<Widget> _entryTypeGroup(Franchise f, EntryType type) {
    final list = f.entries.where((e) => e.type == type).toList();
    if (list.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SectionTitle(_typeTitle(type), count: toFa(list.length)),
      ),
      for (final e in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EntryTile(
            entry: e,
            franchiseId: widget.franchise.id,
            onManualRemoved: _reloadAfterManual,
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  String _typeTitle(EntryType type) {
    switch (type) {
      case EntryType.series:
        return tr('tv_series_2');
      case EntryType.movie:
        return tr('movies_2');
      case EntryType.ova:
        return 'OVA';
      case EntryType.special:
        return tr('special');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final f = widget.franchise;
    final t = Theme.of(context).textTheme;
    final statuses = ref.watch(watchStatusProvider);
    final episodes = ref.watch(episodeProgressProvider);
    final progress = progressOf(f, statuses, episodes);
    final spoilerFree = ref.watch(userExtrasProvider).spoilerFree();
    final main = f.mainEntries;
    final related = f.relatedEntries;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _refresh(context, ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: AppColors.backgroundOf(context),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: tr('back'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onBack,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: tr('add_anime_manually'),
                onPressed: () => _openManualAdd(),
              ),
            ],
            title: Text(
              f.titleFa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: dirFor(f.titleFa),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(url: f.banner ?? f.cover, cacheWidth: 1080),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          AppColors.backgroundOf(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 104,
                      height: 150,
                      child: CoverImage(url: f.cover, cacheWidth: 320),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.titleFa,
                          maxLines: 3,
                          textDirection: dirFor(f.titleFa),
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (f.titleEn != f.titleFa)
                          Text(
                            f.titleEn,
                            maxLines: 2,
                            textDirection: TextDirection.ltr,
                            style: t.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              icon: Icons.calendar_today_rounded,
                              text: f.year == 0 ? '—' : toFa(f.year),
                            ),
                            _InfoChip(
                              icon: Icons.star_rounded,
                              iconColor: AppColors.starTextOf(context),
                              text: f.score <= 0
                                  ? 'AniList —'
                                  : 'AniList ${toFa(f.score.toStringAsFixed(1))}',
                            ),
                            if (f.malScore != null)
                              _InfoChip(
                                icon: Icons.star_rounded,
                                iconColor: AppColors.starTextOf(context),
                                text:
                                    'MAL ${toFa(f.malScore!.toStringAsFixed(1))}',
                              ),
                            _InfoChip(
                              icon: Icons.video_library_outlined,
                              text: tr('episodes', [toFa(f.totalEpisodes)]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (f.genres.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  textDirection: TextDirection.rtl,
                  children: [
                    for (final g in f.genres)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x268B5CF6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x4D8B5CF6)),
                        ),
                        child: Text(
                          g,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryTextOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(tr('synopsis')),
                  const SizedBox(height: 10),
                  _SpoilerSynopsis(
                    synopsis: f.synopsis,
                    blurred: spoilerFree && progress.done == 0,
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: NoteEditor(franchiseId: f.id),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FranchiseRating(franchiseId: f.id),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _ProgressCard(progress: progress),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.backgroundOf(context),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => SizedBox(
                      height: MediaQuery.of(context).size.height * 0.85,
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.borderOf(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(child: WatchOrderView(franchise: f)),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.reorder_rounded),
                label: Text(tr('watch_order_suggested_custom')),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Center(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'list',
                      icon: Icon(Icons.list_rounded),
                      label: Text(tr('list')),
                    ),
                    ButtonSegment<String>(
                      value: 'tree',
                      icon: Icon(Icons.account_tree_rounded),
                      label: Text(tr('tree')),
                    ),
                    ButtonSegment<String>(
                      value: 'type',
                      icon: Icon(Icons.category_rounded),
                      label: Text(tr('categories')),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) => setState(() => _view = s.first),
                ),
              ),
            ),
          ),
          if (_view == 'tree')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FranchiseTreeView(franchise: f),
              ),
            )
          else if (_view == 'type')
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final t = EntryType.values[i];
                  final items = _entryTypeGroup(f, t);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: items,
                  );
                }, childCount: EntryType.values.length),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SectionTitle(tr('main_story'), count: toFa(main.length)),
              ),
            ),
            if (main.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    tr('no_sections_to_display'),
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntryTile(
                        entry: main[i],
                        franchiseId: widget.franchise.id,
                        onManualRemoved: _reloadAfterManual,
                      ),
                    ),
                    childCount: main.length,
                  ),
                ),
              ),

            if (related.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: SectionTitle(
                    tr('related_content'),
                    count: toFa(related.length),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EntryTile(
                        entry: related[i],
                        franchiseId: widget.franchise.id,
                        onManualRemoved: _reloadAfterManual,
                      ),
                    ),
                    childCount: related.length,
                  ),
                ),
              ),
            ],
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, this.iconColor});
  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: iconColor ?? AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final FranchiseProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr('your_progress'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Spacer(),
              Text(
                tr('str', [toFa(progress.percent)]),
                style: TextStyle(
                  color: AppColors.primaryTextOf(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.ratio),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.surfaceHighOf(context),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr('of_main_story_episodes_watched', [
              toFa(progress.done),
              toFa(progress.total),
            ]),
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _SpoilerSynopsis extends StatefulWidget {
  const _SpoilerSynopsis({required this.synopsis, required this.blurred});
  final String synopsis;
  final bool blurred;

  @override
  State<_SpoilerSynopsis> createState() => _SpoilerSynopsisState();
}

class _SpoilerSynopsisState extends State<_SpoilerSynopsis> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.blurred || _revealed) {
      return _ExpandableText(text: widget.synopsis);
    }
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: _ExpandableText(text: widget.synopsis),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _revealed = true),
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        size: 18,
                        color: AppColors.textSecondaryOf(context),
                      ),
                      SizedBox(width: 8),
                      Text(
                        tr('show_summary'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.isEmpty ? tr('no_summary_available') : widget.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: Text(
            text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            textDirection: dirFor(text),
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              height: 1.8,
              fontSize: 14,
            ),
          ),
        ),
        if (text.length > 220)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? tr('less') : tr('read_more')),
          ),
      ],
    );
  }
}

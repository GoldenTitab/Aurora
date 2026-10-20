import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../core/utils/relation_labels.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/anime_card_data.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/franchise.dart';
import '../../../data/providers.dart';
import '../../../data/remote/api_exception.dart';
import '../../../core/i18n/lang.dart';

class ManualAddSheet extends ConsumerStatefulWidget {
  const ManualAddSheet({
    super.key,
    required this.franchise,
    required this.onAdded,
  });

  final Franchise franchise;
  final VoidCallback onAdded;

  @override
  ConsumerState<ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends ConsumerState<ManualAddSheet> {
  final _ctrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _searching = false;
  String? _error;
  List<AnimeCardData>? _results;
  final _adding = <String>{};
  final _added = <String>{};

  AnimeCardData? _picked;
  Entry? _pickedEntry;
  bool _resolving = false;
  String? _afterId;
  String? _relation;
  int _searchGen = 0;
  int _pickGen = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _keyOf(AnimeCardData d) => '${d.anilistId}:${d.malId}';

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      return;
    }
    final gen = ++_searchGen;
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
      _picked = null;
    });
    try {
      final repo = ref.read(franchiseRepositoryProvider);
      final res = await repo.searchRemote(q);
      final inFranchise = widget.franchise.entries
          .map((e) => '${e.anilistId}:${e.malId ?? 0}')
          .toSet();
      final filtered = res.where((d) {
        if (inFranchise.contains(_keyOf(d))) {
          return false;
        }
        if (d.anilistId > 0 && inFranchise.contains('${d.anilistId}:0')) {
          return false;
        }
        return true;
      }).toList();
      if (mounted && gen == _searchGen) {
        setState(() => _results = filtered);
      }
    } catch (e) {
      if (mounted && gen == _searchGen) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted && gen == _searchGen) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _pick(AnimeCardData d) async {
    final gen = ++_pickGen;
    setState(() {
      _picked = d;
      _pickedEntry = null;
      _resolving = true;
      _afterId = null;
      _relation = null;
      _noteCtrl.clear();
    });
    try {
      final entry = await ref
          .read(franchiseRepositoryProvider)
          .resolveManualEntry(d);
      if (mounted && gen == _pickGen) {
        setState(() {
          _pickedEntry = entry;
          _resolving = false;
        });
        if (entry == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('full_data_for_this_anime_wasn_t_found_try_anothe'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && gen == _pickGen) {
        setState(() => _resolving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _confirmAdd() async {
    var entry = _pickedEntry;
    if (entry == null) return;
    final key = _keyOf(_picked!);
    // هشدار تکراری
    final dup = widget.franchise.entries.any(
      (e) => e.anilistId == entry!.anilistId && entry.anilistId > 0,
    );
    if (dup && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('already_in_franchise'))));
      return;
    }
    setState(() => _adding.add(key));
    try {
      if (_relation != null) {
        entry = entry.copyWith(relationType: _relation);
      }
      final repo = ref.read(franchiseRepositoryProvider);
      await repo.addManualEntry(
        widget.franchise.id,
        entry,
        insertAfterId: _afterId,
        note: _noteCtrl.text,
      );
      widget.onAdded();
      if (mounted) {
        setState(() {
          _added.add(key);
          _picked = null;
          _pickedEntry = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('was_added_to_the_franchise', [entry.title])),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('add_anime_manually'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('done')),
                ),
              ],
            ),
            Text(
              tr('if_an_anime_from_this_franchise_is_missing_searc'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_picked == null) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: tr('anime_name'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _searching ? null : _search,
                    child: Text(tr('search_2')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      )
                    : _results == null
                    ? Center(
                        child: Text(
                          tr('no_search_performed_yet'),
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      )
                    : _results!.isEmpty
                    ? Center(child: Text(tr('nothing_found')))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final d = _results![i];
                          return _ResultRow(
                            data: d,
                            adding: _adding.contains(_keyOf(d)),
                            added: _added.contains(_keyOf(d)),
                            onAdd: () => _pick(d),
                          );
                        },
                      ),
              ),
            ] else
              _ConfigStep(
                data: _picked!,
                entry: _pickedEntry,
                resolving: _resolving,
                afterId: _afterId,
                onAfterId: (v) => setState(() => _afterId = v),
                relation: _relation,
                onRelation: (v) => setState(() => _relation = v),
                noteCtrl: _noteCtrl,
                entries: widget.franchise.entries,
                onBack: () => setState(() {
                  _pickGen++;
                  _picked = null;
                  _pickedEntry = null;
                  _resolving = false;
                }),
                onConfirm: _confirmAdd,
                confirming: _adding.contains(_keyOf(_picked!)),
              ),
          ],
        ),
      ),
    );
  }
}

/// قدم دوم: جایگاه، نسبت، یادداشت، پیش‌نمایش و تأیید.
class _ConfigStep extends StatelessWidget {
  const _ConfigStep({
    required this.data,
    required this.entry,
    required this.resolving,
    required this.afterId,
    required this.onAfterId,
    required this.relation,
    required this.onRelation,
    required this.noteCtrl,
    required this.entries,
    required this.onBack,
    required this.onConfirm,
    required this.confirming,
  });

  final AnimeCardData data;
  final Entry? entry;
  final bool resolving;
  final String? afterId;
  final ValueChanged<String?> onAfterId;
  final String? relation;
  final ValueChanged<String?> onRelation;
  final TextEditingController noteCtrl;
  final List<Entry> entries;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final bool confirming;

  static const _relations = ['SEQUEL', 'PREQUEL', 'SIDE_STORY', 'SPIN_OFF'];

  @override
  Widget build(BuildContext context) {
    final resolved = entry;
    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: tr('back'),
                ),
                Expanded(
                  child: Text(
                    tr('preview'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (resolving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (resolved == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    tr('full_data_for_this_anime_wasn_t_found_try_anothe'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              // پیش‌نمایش با بج «دستی»
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 64,
                        height: 92,
                        child: CoverImage(
                          url: resolved.cover ?? data.cover,
                          cacheWidth: 200,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolved.title,
                            textDirection: dirFor(resolved.title),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (resolved.year != null)
                            Text(
                              toFa(resolved.year!),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tr('manual_badge'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryTextOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('where_in_order')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(tr('at_the_end')),
                    selected: afterId == null,
                    onSelected: (_) => onAfterId(null),
                  ),
                  for (final e in entries)
                    ChoiceChip(
                      label: Text(
                        tr('after_x', [e.title]),
                        textDirection: dirFor(e.title),
                      ),
                      selected: afterId == e.id,
                      onSelected: (_) => onAfterId(e.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('relation')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(tr('unspecified')),
                    selected: relation == null,
                    onSelected: (_) => onRelation(null),
                  ),
                  for (final r in _relations)
                    ChoiceChip(
                      label: Text(relationLabelFa(r)),
                      selected: relation == r,
                      onSelected: (_) => onRelation(r),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('why_add')),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: tr('why_add'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: confirming ? null : onConfirm,
                  icon: confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(tr('confirm_add')),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.data,
    required this.adding,
    required this.added,
    required this.onAdd,
  });

  final AnimeCardData data;
  final bool adding;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 64,
              child: CoverImage(url: d.cover, cacheWidth: 140),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.titleFa,
                  textDirection: dirFor(d.titleFa),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (d.year != null) toFa(d.year!),
                    d.source.labelFa,
                  ].join(' • '),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (added)
            const Icon(Icons.check_circle_rounded, color: Colors.green)
          else if (adding)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            OutlinedButton(onPressed: onAdd, child: Text(tr('select'))),
        ],
      ),
    );
  }
}

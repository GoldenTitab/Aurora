import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../data/models/anime_card_data.dart';
import '../../../data/models/franchise.dart';
import '../../../data/providers.dart';
import '../../../data/remote/api_exception.dart';
import '../../../core/i18n/lang.dart';

/// شیت «افزودن دستی انیمه»: وقتی API یک انیمه را در فرنچایز جا انداخته،
/// کاربر این‌جا سرچش می‌کند و دستی به فرنچایز اضافه‌اش می‌کند.
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
  bool _searching = false;
  String? _error;
  List<AnimeCardData>? _results;
  final _adding = <String>{};
  final _added = <String>{};

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _keyOf(AnimeCardData d) => '${d.anilistId}:${d.malId}';

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    try {
      final repo = ref.read(franchiseRepositoryProvider);
      final res = await repo.searchRemote(q);
      // آن‌هایی که همین حالا در فرنچایز هستند را کنار بگذار.
      final inFranchise = widget.franchise.entries
          .map((e) => '${e.anilistId}:${e.malId ?? 0}')
          .toSet();
      final filtered = res.where((d) {
        if (inFranchise.contains(_keyOf(d))) return false;
        if (d.anilistId > 0 && inFranchise.contains('${d.anilistId}:0')) {
          return false;
        }
        return true;
      }).toList();
      if (mounted) setState(() => _results = filtered);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(AnimeCardData d) async {
    final key = _keyOf(d);
    setState(() => _adding.add(key));
    try {
      final repo = ref.read(franchiseRepositoryProvider);
      final entry = await repo.resolveManualEntry(d);
      if (entry == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text(tr('full_data_for_this_anime_wasn_t_found_try_anothe')),
            ),
          );
        }
        return;
      }
      await repo.addManualEntry(widget.franchise.id, entry);
      widget.onAdded();
      if (mounted) {
        setState(() => _added.add(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('was_added_to_the_franchise', [entry.title]))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child:  Text(tr('done')),
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
                  child:  Text(tr('search_2')),
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
                                  color:
                                      AppColors.textSecondaryOf(context),
                                ),
                              ),
                            )
                          : _results!.isEmpty
                              ?  Center(
                                  child: Text(tr('nothing_found')),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _results!.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final d = _results![i];
                                    return _ResultRow(
                                      data: d,
                                      adding: _adding.contains(_keyOf(d)),
                                      added: _added.contains(_keyOf(d)),
                                      onAdd: () => _add(d),
                                    );
                                  },
                                ),
            ),
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
            OutlinedButton(
              onPressed: onAdd,
              child:  Text(tr('add')),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../core/utils/relation_labels.dart';
import '../../../core/utils/text_utils.dart';
import '../../../data/models/franchise.dart';
import '../../../data/providers.dart';
import '../../../data/services/watch_order_service.dart';
import '../../../core/i18n/lang.dart';

class WatchOrderView extends ConsumerStatefulWidget {
  const WatchOrderView({super.key, required this.franchise});
  final Franchise franchise;

  @override
  ConsumerState<WatchOrderView> createState() => _WatchOrderViewState();
}

class _WatchOrderViewState extends ConsumerState<WatchOrderView> {
  bool _showOptional = true;
  List<WatchOrderItem>? _localOrder;
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final storage = ref.read(watchOrderStorageProvider);
    final custom = storage.customOrderOf(widget.franchise.id);
    final service = const WatchOrderService();
    final items = service.compute(widget.franchise, customOrder: custom);
    setState(() {
      _localOrder = items;
      _isCustom = custom != null && custom.isNotEmpty;
    });
  }

  Future<void> _persistOrder(List<WatchOrderItem> merged) async {
    setState(() {
      _localOrder = merged;
      _isCustom = true;
    });
    final ids = merged.map((e) => e.entry.id).toList();
    await ref
        .read(watchOrderStorageProvider)
        .saveCustomOrder(widget.franchise.id, ids);
  }

  Future<void> _onReorderVisible(
    List<WatchOrderItem> full,
    List<WatchOrderItem> visible,
    int oldIndex,
    int newIndex,
  ) async {
    final vis = visible.toList();
    final moved = vis.removeAt(oldIndex);
    vis.insert(newIndex, moved);
    final visIds = vis.map((e) => e.entry.id).toSet();
    final it = vis.iterator;
    final merged = <WatchOrderItem>[];
    for (final e in full) {
      if (visIds.contains(e.entry.id)) {
        it.moveNext();
        merged.add(it.current);
      } else {
        merged.add(e);
      }
    }
    await _persistOrder(merged);
  }

  Future<void> _reset() async {
    await ref
        .read(watchOrderStorageProvider)
        .clearCustomOrder(widget.franchise.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _localOrder;
    if (items == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    final visible = _showOptional
        ? items
        : items.where((i) => i.isEssential).toList();

    final epProgress = ref.watch(episodeProgressProvider);
    // «اینجایی»: اولین ورودی‌ای که هنوز کامل دیده نشده
    bool doneOf(WatchOrderItem it) {
      final w = epProgress[it.entry.id] ?? {};
      return it.entry.episodes > 0 && w.length >= it.entry.episodes;
    }

    final hereIndex = visible.indexWhere((it) => !doneOf(it));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                _isCustom ? tr('your_custom_order') : tr('suggested_order'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (_isCustom)
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(tr('back_to_suggested')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTextOf(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            tr('drag_the_handle_on_the_left_of_each_row_to_reord'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryOf(context).withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(tr('all')),
                selected: _showOptional,
                onSelected: (_) => setState(() => _showOptional = true),
              ),
              ChoiceChip(
                label: Text(
                  tr('essentials_only', [
                    toFa(items.where((i) => i.isEssential).length),
                  ]),
                ),
                selected: !_showOptional,
                onSelected: (_) => setState(() => _showOptional = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: visible.length,
            onReorderItem: (oldI, newI) =>
                _onReorderVisible(items, visible, oldI, newI),
            itemBuilder: (context, index) {
              final item = visible[index];
              final e = item.entry;
              final isHere = index == hereIndex;
              final done = doneOf(item);
              final watched = epProgress[e.id] ?? {};
              final pct = e.episodes > 0
                  ? (watched.length / e.episodes).clamp(0.0, 1.0)
                  : 0.0;
              return Card(
                key: ValueKey(e.id),
                margin: const EdgeInsets.only(bottom: 8),
                color: isHere
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.surfaceOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isHere
                        ? AppColors.primary
                        : AppColors.borderOf(context),
                    width: isHere ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: Text(
                          toFa(index + 1),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppColors.primaryTextOf(context),
                          ),
                        ),
                      ),
                      title: Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: dirFor(e.title),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _chip(
                              item.isEssential
                                  ? tr('essential')
                                  : tr('optional'),
                              item.isEssential
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFF59E0B),
                            ),
                            if (item.relationNote != null &&
                                item.relationNote!.isNotEmpty)
                              _chip(
                                relationLabelFa(item.relationNote),
                                AppColors.primaryTextOf(context),
                              ),
                            if (e.episodes > 0)
                              _chip(
                                tr('episodes', [toFa(e.episodes)]),
                                AppColors.textSecondaryOf(context),
                              ),
                            if (isHere)
                              _chip(tr('you_are_here'), AppColors.primary),
                            if (done)
                              _chip(
                                tr('watched'),
                                const Color(0xFF22C55E),
                              ),
                          ],
                        ),
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                    if (e.episodes > 0 && pct > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor: AppColors.borderOf(
                              context,
                            ).withValues(alpha: 0.4),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

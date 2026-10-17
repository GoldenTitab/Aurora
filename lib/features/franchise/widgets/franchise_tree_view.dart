import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/relation_labels.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/franchise.dart';
import '../../../data/models/watch_status.dart';
import '../../../data/providers.dart';
import '../../../core/i18n/lang.dart';

class FranchiseTreeView extends ConsumerWidget {
  const FranchiseTreeView({super.key, required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = franchise.entries;
    final byId = <String, Entry>{for (final e in entries) e.id: e};
    final childrenOf = <String, List<Entry>>{};
    final roots = <Entry>[];

    for (final e in entries) {
      final parentId = e.parentEntryId;
      if (parentId == null || !byId.containsKey(parentId)) {
        roots.add(e);
      } else {
        childrenOf.putIfAbsent(parentId, () => []).add(e);
      }
    }

    if (roots.isEmpty) {
      return Text(
        tr('no_tree_structure_for_this_franchise'),
        style: TextStyle(color: AppColors.textSecondaryOf(context)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final root in roots)
          _TreeNode(
            entry: root,
            childrenOf: childrenOf,
            depth: 0,
            visited: const <String>{},
          ),
      ],
    );
  }
}

class _TreeNode extends ConsumerWidget {
  const _TreeNode({
    required this.entry,
    required this.childrenOf,
    required this.depth,
    required this.visited,
  });

  final Entry entry;
  final Map<String, List<Entry>> childrenOf;
  final int depth;
  final Set<String> visited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(watchStatusProvider.select((m) => m[entry.id]));
    final relation = relationLabelFa(entry.relationType);
    final nextVisited = <String>{...visited, entry.id};
    final kids = (childrenOf[entry.id] ?? const <Entry>[])
        .where((e) => !visited.contains(e.id))
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(right: depth * 20.0, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: AppColors.borderOf(context),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 40,
                    height: 56,
                    child: CoverImage(url: entry.cover, cacheWidth: 140),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  status?.color ?? AppColors.borderOf(context),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textDirection: dirFor(entry.title),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (relation.isNotEmpty) _MiniChip(relation),
                          _MiniChip(entry.type.labelFa),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final kid in kids)
            _TreeNode(
              entry: kid,
              childrenOf: childrenOf,
              depth: depth + 1,
              visited: nextVisited,
            ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryOf(context),
        ),
      ),
    );
  }
}

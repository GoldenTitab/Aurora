import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/route_utils.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/offline_banner.dart';
import '../../data/models/entry.dart';
import '../../data/models/home_items.dart';
import '../../data/models/watch_status.dart';
import '../../data/providers.dart';
import '../../data/storage/economy.dart';
import '../../data/storage/migrations.dart';
import '../../core/i18n/lang.dart';

class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key});

  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen> {
  static const _sortKey = 'mylist_sort';
  static const _typeKey = 'mylist_type';
  static const _hideDoneKey = 'mylist_hide_done';

  static final _sortLabels = <String, String>{
    'status': tr('default_group_by_status'),
    'rating': tr('my_score'),
    'progress': tr('progress'),
    'title': tr('title_a_z'),
    'airing': tr('airing_first'),
  };

  String _sort = 'status';
  EntryType? _type;
  bool _hideDone = false;

  bool _selecting = false;
  final _selected = <String>{};

  /// گروه‌های جمع‌شده (نام WatchStatus)؛ watching باز، بقیه پیش‌فرض بسته.
  final _collapsed = <String>{};
  static const _collapsedKey = 'mylist_collapsed';

  String _textQuery = '';
  final _textCtrl = TextEditingController();

  Box<String> get _meta => Hive.box<String>(Boxes.meta);

  @override
  void initState() {
    super.initState();
    final rawSort = _meta.get(_sortKey);
    if (rawSort != null && _sortLabels.containsKey(rawSort)) {
      _sort = rawSort;
    }
    _type = _parseType(_meta.get(_typeKey));
    _hideDone = _meta.get(_hideDoneKey) == '1';
    final rawCollapsed = _meta.get(_collapsedKey);
    if (rawCollapsed == null) {
      // پیش‌فرض: completed و dropped بسته
      _collapsed.addAll([
        WatchStatus.completed.name,
        WatchStatus.dropped.name,
      ]);
    } else if (rawCollapsed.isNotEmpty) {
      _collapsed.addAll(rawCollapsed.split(','));
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleCollapsed(WatchStatus s) async {
    setState(() {
      if (_collapsed.contains(s.name)) {
        _collapsed.remove(s.name);
      } else {
        _collapsed.add(s.name);
      }
    });
    await _meta.put(_collapsedKey, _collapsed.join(','));
  }

  static EntryType? _parseType(String? raw) {
    if (raw == null || raw == 'all') return null;
    for (final t in EntryType.values) {
      if (t.name == raw) return t;
    }
    return null;
  }

  bool _passes(MyListFranchise item) {
    if (_hideDone && item.status == WatchStatus.completed) return false;
    if (_type != null && !item.franchise.entries.any((e) => e.type == _type)) {
      return false;
    }
    final q = _textQuery.trim();
    if (q.isNotEmpty) {
      final f = item.franchise;
      final hay = '${f.titleFa} ${f.titleEn}'.toLowerCase();
      if (!hay.contains(q.toLowerCase())) return false;
    }
    return true;
  }

  int _compare(
    MyListFranchise a,
    MyListFranchise b,
    Map<String, int?> ratings,
  ) {
    switch (_sort) {
      case 'rating':
        return (ratings[b.franchise.id] ?? -1).compareTo(
          ratings[a.franchise.id] ?? -1,
        );
      case 'progress':
        return b.progress.ratio.compareTo(a.progress.ratio);
      case 'title':
        return a.franchise.titleFa.compareTo(b.franchise.titleFa);
      case 'airing':
        final ha = a.franchise.entries.any(
          (e) => e.releaseState == ReleaseState.airing,
        );
        final hb = b.franchise.entries.any(
          (e) => e.releaseState == ReleaseState.airing,
        );
        return (hb ? 1 : 0).compareTo(ha ? 1 : 0);
      default:
        return 0;
    }
  }

  Widget _typeChip(EntryType? value, String label) {
    final selected = _type == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) async {
        await _meta.put(_typeKey, value?.name ?? 'all');
        if (mounted) setState(() => _type = value);
      },
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _typeChip(null, tr('all')),
          const SizedBox(width: 8),
          for (final t in EntryType.values) ...[
            _typeChip(t, t.labelFa),
            const SizedBox(width: 8),
          ],
          FilterChip(
            label: Text(tr('hide_completed')),
            selected: _hideDone,
            onSelected: (v) async {
              await _meta.put(_hideDoneKey, v ? '1' : '0');
              if (mounted) setState(() => _hideDone = v);
            },
          ),
        ],
      ),
    );
  }

  void _toggleSelect(String franchiseId) {
    setState(() {
      if (_selected.contains(franchiseId)) {
        _selected.remove(franchiseId);
      } else {
        _selected.add(franchiseId);
      }
    });
  }

  Future<void> _deleteSelected(List<MyListFranchise> items) async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_selected')),
        content: Text(tr('delete_n_franchises', [toFa(_selected.length)])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ids = _selected.toList();
    final byId = {for (final i in items) i.franchise.id: i};
    final statusN = ref.read(watchStatusProvider.notifier);
    final epN = ref.read(episodeProgressProvider.notifier);
    final extras = ref.read(userExtrasProvider);
    final eco = Economy(_meta);
    for (final fid in ids) {
      final item = byId[fid];
      if (item == null) continue;
      final entryIds = item.franchise.entries.map((e) => e.id).toList();
      for (final e in item.franchise.entries) {
        await statusN.setStatus(e.id, null);
        await epN.clear(e.id, e.episodes);
      }
      await extras.clearFranchise(fid, entryIds);
      await eco.deleteFranchiseRating(fid);
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('franchises_removed', [toFa(ids.length)]))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(myListFranchisesProvider);
    final eco = Economy(_meta);
    final ratings = <String, int?>{
      for (final i in items) i.franchise.id: eco.fratingOf(i.franchise.id),
    };

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('my_list'))),
        body: const _EmptyList(),
      );
    }

    final visible = items.where(_passes).toList();

    // نزدیک‌ترین قسمت آینده برای هر فرنچایز (فقط watching)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nextAir = <int, AiringEntry>{};
    final days = ref.watch(weeklyAiringProvider).valueOrNull ?? const [];
    for (final d in days) {
      for (final e in d.items) {
        if (e.airingAt * 1000 <= nowMs) continue;
        final cur = nextAir[e.franchiseAnilistId];
        if (cur == null || e.airingAt < cur.airingAt) {
          nextAir[e.franchiseAnilistId] = e;
        }
      }
    }

    final rows = <Object>[];
    for (final s in WatchStatus.values) {
      final list = visible.where((i) => i.status == s).toList()
        ..sort((a, b) => _compare(a, b, ratings));
      if (list.isEmpty) continue;
      rows.add(_HeaderRow(s, list.length));
      if (!_collapsed.contains(s.name)) rows.addAll(list);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selecting
              ? tr('selected_count', [toFa(_selected.length)])
              : tr('my_list'),
        ),
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: tr('cancel_selection'),
                onPressed: () => setState(() {
                  _selecting = false;
                  _selected.clear();
                }),
              )
            : null,
        actions: _selecting
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  tooltip: tr('delete_selected'),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _deleteSelected(items),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: tr('select'),
                  onPressed: () => setState(() => _selecting = true),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: tr('sort', [_sortLabels[_sort]]),
                  initialValue: _sort,
                  onSelected: (v) async {
                    await _meta.put(_sortKey, v);
                    if (mounted) setState(() => _sort = v);
                  },
                  itemBuilder: (ctx) => [
                    for (final e in _sortLabels.entries)
                      CheckedPopupMenuItem<String>(
                        value: e.key,
                        checked: _sort == e.key,
                        child: Text(e.value),
                      ),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          _StatsStrip(items: items),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _textCtrl,
              onChanged: (v) => setState(() => _textQuery = v),
              decoration: InputDecoration(
                hintText: tr('search_2'),
                hintStyle: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                ),
                filled: true,
                fillColor: AppColors.surfaceOf(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _textQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => setState(() {
                          _textCtrl.clear();
                          _textQuery = '';
                        }),
                      ),
              ),
            ),
          ),
          _filterChips(),
          Expanded(
            child: visible.isEmpty
                ? const _EmptyFilter()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      if (r is _HeaderRow) {
                        return _GroupHeader(
                          status: r.status,
                          count: r.count,
                          collapsed: _collapsed.contains(r.status.name),
                          onToggle: () => _toggleCollapsed(r.status),
                        );
                      }
                      final item = r as MyListFranchise;
                      final fid = item.franchise.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FranchiseTile(
                          item: item,
                          selecting: _selecting,
                          selected: _selected.contains(fid),
                          onToggle: () => _toggleSelect(fid),
                          nextAiring: nextAir[item.franchise.anilistId],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow {
  const _HeaderRow(this.status, this.count);
  final WatchStatus status;
  final int count;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.status,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });
  final WatchStatus status;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(status.icon, color: status.color, size: 22),
            const SizedBox(width: 8),
            Text(
              status.labelFa,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighOf(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                toFa(count),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            const Spacer(),
            Icon(
              collapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              color: AppColors.textSecondaryOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// نوار آمار یک‌خطی بالای لیست.
class _StatsStrip extends ConsumerWidget {
  const _StatsStrip({required this.items});
  final List<MyListFranchise> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watching = items
        .where((i) => i.status == WatchStatus.watching)
        .length;
    final heat = ref.watch(heatmapProvider);
    final weekEps = heat.length <= 7
        ? heat.fold<int>(0, (s, e) => s + e.count)
        : heat.sublist(heat.length - 7).fold<int>(0, (s, e) => s + e.count);
    if (watching == 0 && weekEps == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.insights_rounded,
            size: 16,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${tr('watching_count', [toFa(watching)])} • ${tr('episodes_this_week', [toFa(weekEps)])}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FranchiseTile extends StatelessWidget {
  const _FranchiseTile({
    required this.item,
    this.selecting = false,
    this.selected = false,
    this.onToggle,
    this.nextAiring,
  });
  final MyListFranchise item;

  final bool selecting;
  final bool selected;
  final VoidCallback? onToggle;

  /// نزدیک‌ترین قسمت آینده (فقط برای watching نمایش داده می‌شود).
  final AiringEntry? nextAiring;

  @override
  Widget build(BuildContext context) {
    final f = item.franchise;
    final p = item.progress;
    return Material(
      color: selected
          ? AppColors.primaryTextOf(context).withValues(alpha: 0.10)
          : AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selecting
            ? onToggle
            : () => context.push(franchiseRouteFor(f.anilistId, f.id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (selecting) ...[
                Checkbox(value: selected, onChanged: (_) => onToggle?.call()),
                const SizedBox(width: 4),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: CoverImage(url: f.cover, cacheWidth: 160),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.titleFa,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: dirFor(f.titleFa),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      f.titleEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: p.ratio,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceHighOf(context),
                        valueColor: AlwaysStoppedAnimation(item.status.color),
                      ),
                    ),
                    if (item.status == WatchStatus.watching &&
                        nextAiring != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${tr('next_episode', [toFa(nextAiring!.episode)])} • ${_countdown(nextAiring!.airingAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.completed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      tr('of_episodes', [
                        toFa(p.done),
                        toFa(p.total),
                        toFa(p.percent),
                      ]),
                      style: TextStyle(
                        fontSize: 11,
                        color: item.status.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _countdown(int airingAtSec) {
  final diff = DateTime.fromMillisecondsSinceEpoch(
    airingAtSec * 1000,
  ).difference(DateTime.now());
  if (diff.inHours < 1) {
    final m = diff.inMinutes.clamp(1, 59);
    return tr('in_minutes', [toFa(m)]);
  }
  if (diff.inHours < 24) return tr('in_hours', [toFa(diff.inHours)]);
  return tr('in_days', [toFa(diff.inDays)]);
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmarks_outlined,
              size: 56,
              color: AppColors.primaryTextOf(context),
            ),
            SizedBox(height: 12),
            Text(
              tr('nothing_logged_yet'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              tr('open_a_franchise_page_and_set_a_status_for_each_'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 56,
              color: AppColors.primaryTextOf(context),
            ),
            SizedBox(height: 12),
            Text(
              tr('no_results_with_these_filters'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              tr('try_changing_the_media_type_filter_or_hide_compl'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

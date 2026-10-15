import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/route_utils.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../data/models/entry.dart';
import '../../data/models/watch_status.dart';
import '../../data/providers.dart';
import '../../data/storage/economy.dart';
import '../../data/storage/migrations.dart';

/// «لیست من»: گروه‌بندی بر اساس وضعیت، با مرتب‌سازی و فیلتر نوع.
///
/// انتخاب‌های مرتب‌سازی/فیلتر در meta box ذخیره می‌شوند:
/// `mylist_sort`، `mylist_type`، `mylist_hide_done`.
class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key});

  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen> {
  static const _sortKey = 'mylist_sort';
  static const _typeKey = 'mylist_type';
  static const _hideDoneKey = 'mylist_hide_done';

  static const _sortLabels = <String, String>{
    'status': 'پیش‌فرض (گروه‌بندی وضعیت)',
    'rating': 'امتیاز من',
    'progress': 'درصد پیشرفت',
    'title': 'عنوان (الفبا)',
    'airing': 'در حال پخش اول',
  };

  String _sort = 'status';
  EntryType? _type;
  bool _hideDone = false;

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
    if (_type != null &&
        !item.franchise.entries.any((e) => e.type == _type)) {
      return false;
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
        // امتیاز من (۱ تا ۱۰) نزولی؛ بدون امتیاز آخر.
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
        // 'status': همان ترتیب پیش‌فرض (گروه‌بندی وضعیت).
        return 0;
    }
  }

  List<Widget> _group(
    WatchStatus status,
    List<MyListFranchise> group,
    Map<String, int?> ratings,
  ) {
    final list = group.where(_passes).toList()
      ..sort((a, b) => _compare(a, b, ratings));
    if (list.isEmpty) return const [];
    return [
      _GroupHeader(status: status, count: list.length),
      for (final item in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FranchiseTile(item: item),
        ),
      const SizedBox(height: 12),
    ];
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
          _typeChip(null, 'همه'),
          const SizedBox(width: 8),
          for (final t in EntryType.values) ...[
            _typeChip(t, t.labelFa),
            const SizedBox(width: 8),
          ],
          FilterChip(
            label: const Text('مخفی کردن تکمیل‌شده‌ها'),
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

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(myListFranchisesProvider);
    final eco = Economy(_meta);
    final ratings = <String, int?>{
      for (final i in items) i.franchise.id: eco.fratingOf(i.franchise.id),
    };

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('لیست من')),
        body: const _EmptyList(),
      );
    }

    final visible = items.where(_passes).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لیست من'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'مرتب‌سازی (${_sortLabels[_sort]})',
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
          _filterChips(),
          Expanded(
            child: visible.isEmpty
                ? const _EmptyFilter()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final s in WatchStatus.values)
                        ..._group(
                          s,
                          items.where((i) => i.status == s).toList(),
                          ratings,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.status, required this.count});
  final WatchStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
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
        ],
      ),
    );
  }
}

class _FranchiseTile extends StatelessWidget {
  const _FranchiseTile({required this.item});
  final MyListFranchise item;

  @override
  Widget build(BuildContext context) {
    final f = item.franchise;
    final p = item.progress;
    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(franchiseRouteFor(f.anilistId, f.id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: CoverImage(url: f.cover),
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
                    const SizedBox(height: 6),
                    Text(
                      '${toFa(p.done)} از ${toFa(p.total)} قسمت · ${toFa(p.percent)}٪',
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
              'هنوز چیزی ثبت نکرده‌ای',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'وارد صفحه یک مجموعه شو و وضعیت هر فصل یا فیلم را انتخاب کن تا اینجا ببینی.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context), height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// وقتی فیلترها هیچ نتیجه‌ای ندارند (نه وقتی لیست کلاً خالی است).
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
              'با این فیلترها چیزی پیدا نشد',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'فیلتر نوع اثر یا «مخفی کردن تکمیل‌شده‌ها» را تغییر بده.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context), height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

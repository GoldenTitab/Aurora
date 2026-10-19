import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/lang.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/section_title.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/models/franchise.dart';
import '../../data/models/watch_status.dart';
import '../../data/providers.dart';
import '../../data/services/bulk_import_parser.dart';

enum _Phase { input, resolving, review, applying, done }

enum _BulkStatus { matched, ambiguous, notFound }

class _BulkItem {
  final String query;
  _BulkStatus status;
  Franchise? franchise;
  AnimeCardData? picked;
  List<AnimeCardData> candidates;
  bool included;
  bool duplicate;
  bool alreadyDone;

  _BulkItem({
    required this.query,
    required this.status,
    this.franchise,
    this.picked,
    this.candidates = const [],
    this.included = true,
    this.duplicate = false,
    this.alreadyDone = false,
  });
}

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  final _pasteCtrl = TextEditingController();
  _Phase _phase = _Phase.input;
  List<_BulkItem> _items = [];
  int _done = 0;
  int _total = 0;
  int _applied = 0;
  int _applyTotal = 0;
  int _addedCount = 0;
  int _skippedCount = 0;
  String? _fileName;
  bool _cancel = false;

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv', 'json'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    try {
      final bytes = f.bytes;
      if (bytes == null) return;
      var content = utf8.decode(bytes, allowMalformed: true);
      if (content.startsWith('\uFEFF')) content = content.substring(1);
      final titles = BulkImportParser.parse(content, f.extension ?? 'txt');
      if (titles.isEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('bulk_no_titles'))));
        return;
      }
      setState(() => _fileName = f.name);
      _pasteCtrl.clear();
      await _resolve(titles);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('bulk_no_titles'))));
      }
    }
  }

  void _usePasted() {
    final titles = BulkImportParser.parse(_pasteCtrl.text, 'txt');
    if (titles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('bulk_no_titles'))));
      return;
    }
    setState(() => _fileName = null);
    _resolve(titles);
  }

  Future<Franchise?> _franchiseOf(AnimeCardData d) async {
    final repo = ref.read(franchiseRepositoryProvider);
    try {
      if (d.anilistId > 0) return await repo.getFranchise(d.anilistId);
      if (d.malId > 0) return await repo.getFranchiseByMal(d.malId);
    } catch (_) {}
    return null;
  }

  Future<void> _resolve(List<String> titles) async {
    _cancel = false;
    setState(() {
      _phase = _Phase.resolving;
      _items = [];
      _done = 0;
      _total = titles.length;
    });
    final repo = ref.read(franchiseRepositoryProvider);
    final seenFr = <String>{};
    final statuses = ref.read(watchStatusProvider);

    for (final q in titles) {
      if (_cancel) break;
      try {
        final results = await repo.searchRemote(q);
        if (results.isEmpty) {
          _items.add(_BulkItem(query: q, status: _BulkStatus.notFound));
        } else {
          final top = results.first;
          if (BulkImportParser.confident(q, top.titleEn, top.titleFa)) {
            final fr = await _franchiseOf(top);
            if (fr == null) {
              _items.add(_BulkItem(query: q, status: _BulkStatus.notFound));
            } else if (!seenFr.add(fr.id)) {
              _items.add(
                _BulkItem(
                  query: q,
                  status: _BulkStatus.matched,
                  franchise: fr,
                  picked: top,
                  included: false,
                  duplicate: true,
                ),
              );
            } else {
              final done = fr.entries.every(
                (e) => statuses[e.id] == WatchStatus.completed,
              );
              _items.add(
                _BulkItem(
                  query: q,
                  status: _BulkStatus.matched,
                  franchise: fr,
                  picked: top,
                  included: !done,
                  alreadyDone: done,
                ),
              );
            }
          } else {
            _items.add(
              _BulkItem(
                query: q,
                status: _BulkStatus.ambiguous,
                candidates: results.take(5).toList(),
                included: false,
              ),
            );
          }
        }
      } catch (_) {
        _items.add(_BulkItem(query: q, status: _BulkStatus.notFound));
      }
      if (mounted) setState(() => _done++);
    }
    if (mounted) setState(() => _phase = _Phase.review);
  }

  Future<void> _pickCandidate(
    BuildContext sheetCtx,
    _BulkItem item,
    AnimeCardData d,
  ) async {
    Navigator.of(sheetCtx).pop();
    final fr = await _franchiseOf(d);
    if (fr == null || !mounted) return;
    final statuses = ref.read(watchStatusProvider);
    // تکراری؟
    final dup = _items.any(
      (i) =>
          i != item &&
          i.status == _BulkStatus.matched &&
          i.franchise?.id == fr.id,
    );
    final done = fr.entries.every(
      (e) => statuses[e.id] == WatchStatus.completed,
    );
    setState(() {
      item.status = _BulkStatus.matched;
      item.franchise = fr;
      item.picked = d;
      item.candidates = const [];
      item.duplicate = dup;
      item.alreadyDone = done;
      item.included = !dup && !done;
    });
  }

  void _showCandidates(_BulkItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderOf(ctx),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tr('choose_correct'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: item.candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (c, i) {
                  final d = item.candidates[i];
                  final title = d.titleFa.isNotEmpty ? d.titleFa : d.titleEn;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 64,
                        child: CoverImage(url: d.cover, cacheWidth: 140),
                      ),
                    ),
                    title: Text(
                      title,
                      textDirection: dirFor(title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: d.year != null ? Text(toFa(d.year!)) : null,
                    onTap: () => _pickCandidate(ctx, item, d),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.borderOf(c)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apply() async {
    _cancel = false;
    final list = _items
        .where(
          (i) =>
              i.status == _BulkStatus.matched &&
              i.included &&
              !i.duplicate &&
              !i.alreadyDone,
        )
        .toList();
    setState(() {
      _phase = _Phase.applying;
      _applied = 0;
      _applyTotal = list.length;
      _addedCount = 0;
      _skippedCount = 0;
    });
    final statusN = ref.read(watchStatusProvider.notifier);
    final epN = ref.read(episodeProgressProvider.notifier);

    for (final item in list) {
      if (_cancel) break;
      final fr = item.franchise!;
      try {
        for (final e in fr.entries) {
          await statusN.setStatus(e.id, WatchStatus.completed);
          if (e.episodes > 0) await epN.markAll(e.id, e.episodes);
        }
        _addedCount++;
      } catch (_) {
        _skippedCount++;
      }
      if (mounted) setState(() => _applied++);
    }
    // ارزیابی اچیومنت‌ها یک‌بار در انتها
    try {
      await ref.read(achievementsProvider.notifier).evaluate();
    } catch (_) {}
    if (mounted) setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('bulk_import')),
        actions: [
          if (_phase == _Phase.resolving || _phase == _Phase.applying)
            TextButton(
              onPressed: () => setState(() => _cancel = true),
              child: Text(tr('cancel')),
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.input => _inputView(),
        _Phase.resolving => _progressView(tr('resolving_progress')),
        _Phase.review => _reviewView(),
        _Phase.applying => _progressView(tr('resolving_progress')),
        _Phase.done => _doneView(),
      },
    );
  }

  Widget _inputView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          tr('bulk_import_desc'),
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('bulk_how'),
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('mark_whole_franchise_completed'),
          style: TextStyle(
            color: AppColors.primaryTextOf(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(tr('pick_file')),
        ),
        if (_fileName != null) ...[
          const SizedBox(height: 8),
          Text(
            tr('bulk_file_chosen', [_fileName!]),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionTitle(tr('or_paste')),
        const SizedBox(height: 8),
        TextField(
          controller: _pasteCtrl,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: tr('paste_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _usePasted,
          icon: const Icon(Icons.playlist_add_rounded),
          label: Text(tr('start_resolving')),
        ),
      ],
    );
  }

  Widget _progressView(String labelKey) {
    final pct = _total == 0
        ? 0.0
        : (_phase == _Phase.applying
              ? (_applyTotal == 0 ? 0.0 : _applied / _applyTotal)
              : _done / _total);
    final cur = _phase == _Phase.applying ? _applied : _done;
    final tot = _phase == _Phase.applying ? _applyTotal : _total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.borderOf(
                  context,
                ).withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(labelKey, [toFa(cur), toFa(tot)]),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewView() {
    final matched = _items
        .where((i) => i.status == _BulkStatus.matched)
        .toList();
    final amb = _items.where((i) => i.status == _BulkStatus.ambiguous).toList();
    final notFound = _items
        .where((i) => i.status == _BulkStatus.notFound)
        .toList();
    final toAdd = matched
        .where((i) => i.included && !i.duplicate && !i.alreadyDone)
        .length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                tr('matched', [toFa(matched.length)]),
                const Color(0xFF22C55E),
              ),
              _chip(
                tr('ambiguous', [toFa(amb.length)]),
                const Color(0xFFF59E0B),
              ),
              _chip(
                tr('not_found', [toFa(notFound.length)]),
                const Color(0xFFEF4444),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _items.length,
            itemBuilder: (context, i) => _row(_items[i]),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: toAdd == 0 ? null : _apply,
                icon: const Icon(Icons.check_rounded),
                label: Text(tr('confirm_and_add', [toFa(toAdd)])),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _row(_BulkItem item) {
    final fr = item.franchise;
    Color border = AppColors.borderOf(context);
    IconData icon = Icons.help_outline_rounded;
    Color iconColor = AppColors.textSecondaryOf(context);
    String statusText = '';
    if (item.status == _BulkStatus.matched) {
      if (item.duplicate) {
        icon = Icons.copy_rounded;
        statusText = tr('duplicate_entry');
      } else if (item.alreadyDone) {
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF22C55E);
        statusText = tr('already_completed');
      } else {
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF22C55E);
        border = const Color(0xFF22C55E).withValues(alpha: 0.4);
      }
    } else if (item.status == _BulkStatus.ambiguous) {
      icon = Icons.help_outline_rounded;
      iconColor = const Color(0xFFF59E0B);
      border = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      statusText = tr('tap_to_choose');
    } else {
      icon = Icons.error_outline_rounded;
      iconColor = const Color(0xFFEF4444);
      statusText = tr('not_found');
    }

    final title = fr != null ? fr.titleFa : item.query;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: ListTile(
        leading:
            item.status == _BulkStatus.matched &&
                !item.duplicate &&
                !item.alreadyDone
            ? Checkbox(
                value: item.included,
                onChanged: (v) => setState(() => item.included = v ?? true),
              )
            : Icon(icon, color: iconColor),
        title: Text(
          title,
          textDirection: dirFor(title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fr != null && title != item.query)
              Text(
                item.query,
                textDirection: dirFor(item.query),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (fr != null)
                  Text(
                    tr('entries_count', [toFa(fr.entries.length)]),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                if (statusText.isNotEmpty) ...[
                  if (fr != null) const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 11, color: iconColor),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: item.status == _BulkStatus.ambiguous
            ? () => _showCandidates(item)
            : null,
      ),
    );
  }

  Widget _doneView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Color(0xFF22C55E),
            ),
            const SizedBox(height: 16),
            Text(
              tr('bulk_done', [toFa(_addedCount)]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (_skippedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                tr('failed_count', [toFa(_skippedCount)]),
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('done')),
            ),
          ],
        ),
      ),
    );
  }
}

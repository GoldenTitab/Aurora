import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../data/models/entry.dart';
import '../../../data/models/watch_status.dart';
import '../../../data/providers.dart';
import 'status_dropdown.dart';
import 'user_score_picker.dart';
import '../../../core/i18n/lang.dart';

class EntryTile extends ConsumerStatefulWidget {
  const EntryTile({
    super.key,
    required this.entry,
    this.franchiseId,
    this.onManualRemoved,
  });
  final Entry entry;

  /// شناسه فرنچایز (برای حذف ورودی دستی)؛ null یعنی حذف پشتیبانی نمی‌شود.
  final String? franchiseId;

  /// بعد از حذف ورودی دستی صدا زده می‌شود (بازخوانی صفحه).
  final VoidCallback? onManualRemoved;

  @override
  ConsumerState<EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends ConsumerState<EntryTile> {
  bool _open = false;

  Future<void> _confirmDeleteManual() async {
    final fid = widget.franchiseId;
    if (fid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:  Text(tr('remove_manual_entry')),
        content: Text(
          tr('remove_from_this_franchise', [widget.entry.title]),
          textDirection: dirFor(widget.entry.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:  Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:  Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(franchiseRepositoryProvider)
        .removeManualEntry(fid, widget.entry.id);
    widget.onManualRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final status = ref.watch(watchStatusProvider.select((m) => m[entry.id]));
    final watched =
        ref.watch(episodeProgressProvider.select((m) => m[entry.id])) ??
        const <int>{};
    final hasEpisodes = entry.episodes > 1;
    // حالت بدون اسپویل: کاور اثری که هنوز هیچ قسمتی از آن دیده نشده
    // و وضعیتی هم برایش ثبت نشده، تار نشان داده می‌شود.
    final spoilerBlur =
        ref.watch(userExtrasProvider).spoilerFree() &&
        watched.isEmpty &&
        status == null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status?.color ?? AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: spoilerBlur
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: SizedBox(
                          width: 56,
                          height: 80,
                          child: CoverImage(url: entry.cover, cacheWidth: 160),
                        ),
                      )
                    : SizedBox(
                        width: 56,
                        height: 80,
                        child: CoverImage(url: entry.cover, cacheWidth: 160),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: dirFor(entry.title),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TypePill(entry.type.labelFa),
                        if (entry.manual) const _ManualPill(),
                        _Meta(
                          icon: Icons.tv_rounded,
                          text: entry.episodes == 0
                              ? tr('unknown_count')
                              : tr('episodes', [toFa(entry.episodes)]),
                        ),
                        if (entry.year != null)
                          _Meta(
                            icon: Icons.calendar_today_rounded,
                            text: toFa(entry.year!),
                          ),
                        _Meta(
                          icon: Icons.star_rounded,
                          iconColor: AppColors.starTextOf(context),
                          text: entry.score <= 0
                              ? '—'
                              : toFa(entry.score.toStringAsFixed(1)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (entry.manual && widget.franchiseId != null)
                IconButton(
                  tooltip: tr('remove_manual_entry'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  onPressed: _confirmDeleteManual,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (entry.releaseState == ReleaseState.announced ||
              entry.releaseState == ReleaseState.airing)
            _ReleaseBadge(state: entry.releaseState),
          UserScorePicker(entryId: entry.id),
          if (watched.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                tr('last_watched_episode', [toFa(watched.reduce((a, b) => a > b ? a : b))]),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          StatusDropdown(
            value: status,
            onChanged: (s) async {
              final notifier = ref.read(watchStatusProvider.notifier);
              await notifier.setStatus(entry.id, s);
              if (s == WatchStatus.completed && entry.episodes > 0) {
                await ref
                    .read(episodeProgressProvider.notifier)
                    .markAll(entry.id, entry.episodes);
              }
            },
          ),
          if (hasEpisodes) ...[
            const SizedBox(height: 8),
            _EpisodesHeader(
              watched: watched.length,
              total: entry.episodes,
              open: _open,
              onTap: () => setState(() => _open = !_open),
            ),
            if (_open) _EpisodesGrid(entry: entry, watched: watched),
          ],
        ],
      ),
    );
  }
}

class _EpisodesHeader extends StatelessWidget {
  const _EpisodesHeader({
    required this.watched,
    required this.total,
    required this.open,
    required this.onTap,
  });
  final int watched;
  final int total;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 18,
              color: AppColors.primaryTextOf(context),
            ),
            const SizedBox(width: 8),
             Text(
              tr('episodes_3'),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Text(
              tr('of_2', [toFa(watched), toFa(total)]),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: watched >= total
                    ? AppColors.completed
                    : AppColors.textSecondaryOf(context),
              ),
            ),
            const Spacer(),
            Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: AppColors.textSecondaryOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// گرید قسمت‌ها با یادداشت شخصی هر قسمت.
///
/// با دو بار ضربه زدن روی یک قسمت، دیالوگ یادداشت باز می‌شود؛
/// چیپ‌هایی که یادداشت دارند یک نقطه‌ی کهربایی نشان می‌دهند.
class _EpisodesGrid extends ConsumerStatefulWidget {
  const _EpisodesGrid({required this.entry, required this.watched});
  final Entry entry;
  final Set<int> watched;

  @override
  ConsumerState<_EpisodesGrid> createState() => _EpisodesGridState();
}

enum _NoteAction { save, delete, cancel }

class _EpisodesGridState extends ConsumerState<_EpisodesGrid> {
  Future<void> _editNote(int ep) async {
    final extras = ref.read(userExtrasProvider);
    final existing = extras.episodeNoteOf(widget.entry.id, ep);
    final controller = TextEditingController(text: existing ?? '');

    final action = await showDialog<_NoteAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('note_for_episode', [toFa(ep)])),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(
            hintText: tr('your_thoughts_on_this_episode'),
            hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
          ),
        ),
        actions: [
          if (existing != null && existing.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, _NoteAction.delete),
              child:  Text(
                tr('delete'),
                style: TextStyle(color: AppColors.dropped),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _NoteAction.cancel),
            child:  Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _NoteAction.save),
            child:  Text(tr('save')),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (!mounted) return;
    if (action == _NoteAction.save) {
      await extras.saveEpisodeNote(widget.entry.id, ep, text);
      if (mounted) setState(() {});
    } else if (action == _NoteAction.delete) {
      await extras.saveEpisodeNote(widget.entry.id, ep, '');
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final watched = widget.watched;
    final notifier = ref.read(episodeProgressProvider.notifier);
    final extras = ref.read(userExtrasProvider);
    final total = entry.episodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = 1; n <= total; n++)
              _EpisodeChip(
                number: n,
                watched: watched.contains(n),
                hasNote:
                    (extras.episodeNoteOf(entry.id, n)?.isNotEmpty ?? false),
                onTap: () => notifier.toggle(entry.id, n, total),
                onDoubleTap: () => _editNote(n),
                onLongPress: () => notifier.markUpTo(entry.id, n, total),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr('long_press_an_episode_to_mark_all_episodes_up_to') +
          tr('double_tap_any_episode_to_add_a_note'),
          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton(
              onPressed: () => notifier.markAll(entry.id, total),
              child:  Text(tr('mark_all_as_watched')),
            ),
            TextButton(
              onPressed: () => notifier.clear(entry.id, total),
              child: Text(
                tr('clear_all'),
                style: TextStyle(color: AppColors.textSecondaryOf(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EpisodeChip extends StatelessWidget {
  const _EpisodeChip({
    required this.number,
    required this.watched,
    required this.hasNote,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });
  final int number;
  final bool watched;
  final bool hasNote;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: 48,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: watched
                  ? AppColors.completed.withValues(alpha: 0.22)
                  : AppColors.surfaceHighOf(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: watched ? AppColors.completed : AppColors.borderOf(context),
              ),
            ),
            child: watched
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: AppColors.completed,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        toFa(number),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.completed,
                        ),
                      ),
                    ],
                  )
                : Text(
                    toFa(number),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
          ),
          if (hasNote)
            const Positioned(
              top: 4,
              right: 4,
              child: _NoteDot(),
            ),
        ],
      ),
    );
  }
}

/// نقطه‌ی کهربایی روی چیپ قسمت‌هایی که یادداشت دارند.
class _NoteDot extends StatelessWidget {
  const _NoteDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: AppColors.star,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x338B5CF6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextOf(context),
        ),
      ),
    );
  }
}

/// بج «دستی» برای ورودی‌هایی که کاربر خودش به فرنچایز اضافه کرده.
class _ManualPill extends StatelessWidget {
  const _ManualPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x3322C55E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tr('manual'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextOf(context),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.iconColor});
  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor ?? AppColors.textSecondaryOf(context)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context)),
        ),
      ],
    );
  }
}

/// نشان وضعیت انتشار: «به‌زودی» برای آثار اعلام‌شده و
/// «در حال پخش» برای آثار در حال پخش.
class _ReleaseBadge extends StatelessWidget {
  const _ReleaseBadge({required this.state});
  final ReleaseState state;

  @override
  Widget build(BuildContext context) {
    final airing = state == ReleaseState.airing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: airing
                ? AppColors.watching.withValues(alpha: 0.15)
                : AppColors.surfaceHighOf(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: airing ? AppColors.watching : AppColors.borderOf(context),
            ),
          ),
          child: Text(
            airing ? tr('airing') : tr('coming_soon'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: airing ? AppColors.watching : AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

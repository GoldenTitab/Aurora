import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/route_utils.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/watch_status.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../data/services/suggestion_engine.dart';
import '../../core/i18n/lang.dart';

enum _PickMode { taste, random, tonight, mood }

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  _PickMode _mode = _PickMode.taste;
  int _minutes = 120;
  String _mood = 'Action';
  Suggestion? _current;
  bool _loading = false;
  String? _error;
  bool _offline = false;

  static const _moods = [
    'Action',
    'Comedy',
    'Drama',
    'Fantasy',
    'Mystery',
    'Romance',
  ];
  static const _times = [30, 60, 120, 180];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  String _moodKey(String m) => 'mood_${m.toLowerCase()}';

  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
      _offline = false;
    });
    try {
      final svc = ref.read(suggestionServiceProvider);
      final s = switch (_mode) {
        _PickMode.taste => await svc.pick(),
        _PickMode.random => await svc.pickRandom(),
        _PickMode.tonight => await svc.pickTonight(_minutes),
        _PickMode.mood => await svc.pickMood(_mood),
      };
      if (!mounted) return;
      setState(() {
        _current = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // آفلاین: آخرین پیشنهاد کش‌شده
      final cached = SuggestionService.lastCached();
      setState(() {
        _loading = false;
        if (cached != null) {
          _current = cached;
          _offline = true;
          _error = null;
        } else {
          _error = friendlyError(e);
        }
      });
    }
  }

  Future<void> _addToList() async {
    final s = _current;
    if (s == null || s.data.anilistId <= 0) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(tr('fetching_full_details'))));
    try {
      final f = await ref
          .read(franchiseRepositoryProvider)
          .getFranchise(s.data.anilistId);
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      final picked = await showModalBottomSheet<WatchStatus>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr('add_to_my_list'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              for (final st in WatchStatus.values)
                ListTile(
                  leading: Icon(st.icon, color: st.color),
                  title: Text(st.labelFa),
                  onTap: () => Navigator.pop(ctx, st),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      final notifier = ref.read(watchStatusProvider.notifier);
      for (final e in f.entries) {
        await notifier.setStatus(e.id, picked);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(tr('added_to_list', [f.titleFa]))),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('pick_an_anime_for_me')),
        actions: [
          IconButton(
            tooltip: tr('clear_suggestion_history'),
            onPressed: () async {
              await ref.read(watchOrderStorageProvider).clearHistory();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('suggestion_history_cleared'))),
              );
              setState(() {});
            },
            icon: const Icon(Icons.history_toggle_off_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ModeBar(
            mode: _mode,
            onMode: (m) {
              setState(() => _mode = m);
              _pick();
            },
          ),
          if (_mode == _PickMode.tonight) ...[
            const SizedBox(height: 10),
            Text(
              tr('pick_time'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _times)
                  ChoiceChip(
                    label: Text(tr('min', [toFa(t)])),
                    selected: _minutes == t,
                    onSelected: (_) {
                      setState(() => _minutes = t);
                      _pick();
                    },
                  ),
              ],
            ),
          ],
          if (_mode == _PickMode.mood) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _moods)
                  ChoiceChip(
                    label: Text(tr(_moodKey(m))),
                    selected: _mood == m,
                    onSelected: (_) {
                      setState(() => _mood = m);
                      _pick();
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _body(),
          const SizedBox(height: 20),
          _HistorySection(onOpen: _openHistory),
        ],
      ),
    );
  }

  void _openHistory(Map<String, dynamic> card) {
    final al = (card['al'] as num?)?.toInt() ?? 0;
    final mal = (card['mal'] as num?)?.toInt() ?? 0;
    if (al > 0) {
      context.push('/franchise/$al');
    } else if (mal > 0) {
      context.push('/franchise/mal-$mal');
    }
  }

  Widget _body() {
    if (_loading) {
      return SizedBox(
        height: 420,
        child: LoadingView(message: tr('picking')),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 420,
        child: ErrorView(message: _error!, onRetry: _pick),
      );
    }
    final s = _current;
    if (s == null) {
      return SizedBox(
        height: 420,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr('no_suggestion_found_to_get_one_you_need_to_be_on') +
                  tr('and_there_must_be_an_anime_outside_your_list_in_'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                height: 1.8,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_offline)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.onHold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.onHold.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 16,
                  color: AppColors.onHold,
                ),
                const SizedBox(width: 6),
                Text(
                  tr('cached_suggestion'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onHold,
                  ),
                ),
              ],
            ),
          ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 200,
              height: 290,
              child: CoverImage(url: s.data.cover, cacheWidth: 460),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.data.titleFa,
          textAlign: TextAlign.center,
          textDirection: dirFor(s.data.titleFa),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.data.titleEn,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 13,
          ),
        ),
        if (s.reasonFa.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('why_this'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.reasonFa,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryTextOf(context),
                    fontWeight: FontWeight.w700,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('another_one')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push(
                  franchiseRouteFor(s.data.anilistId, s.historyId),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(tr('go_to_page')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _offline ? null : _addToList,
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(tr('add_to_my_list')),
          ),
        ),
      ],
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.mode, required this.onMode});
  final _PickMode mode;
  final ValueChanged<_PickMode> onMode;

  @override
  Widget build(BuildContext context) {
    final modes = [
      (_PickMode.taste, tr('mode_taste'), Icons.psychology_rounded),
      (_PickMode.random, tr('mode_random'), Icons.casino_rounded),
      (_PickMode.tonight, tr('mode_tonight'), Icons.nightlight_rounded),
      (_PickMode.mood, tr('mode_mood'), Icons.mood_rounded),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final m in modes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      m.$3,
                      size: 16,
                      color: mode == m.$1
                          ? Colors.white
                          : AppColors.primaryTextOf(context),
                    ),
                    const SizedBox(width: 6),
                    Text(m.$2),
                  ],
                ),
                selected: mode == m.$1,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: mode == m.$1
                      ? Colors.white
                      : AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => onMode(m.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.onOpen});
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final cards = SuggestionService.cachedCards();
    if (cards.isEmpty) return const SizedBox.shrink();
    final list = cards.entries.toList().reversed.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('suggestion_history')),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final card = list[i].value;
              final title = (card['fa'] as String?) ?? '';
              return InkWell(
                onTap: () => onOpen(card),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 96,
                            child: CoverImage(
                              url: card['cover'] as String?,
                              cacheWidth: 240,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title.isEmpty ? '—' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: dirFor(title),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

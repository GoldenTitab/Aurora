import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/anime_card_data.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';

/// لیست کامل یک بخش از «کشف» با اسکرول بی‌نهایت.
class DiscoverListScreen extends ConsumerStatefulWidget {
  const DiscoverListScreen({super.key, required this.section});
  final DiscoverSection section;

  @override
  ConsumerState<DiscoverListScreen> createState() =>
      _DiscoverListScreenState();
}

class _DiscoverListScreenState extends ConsumerState<DiscoverListScreen> {
  final _controller = ScrollController();
  final _items = <AnimeCardData>[];
  final _seen = <int>{};

  int _page = 0;
  bool _loading = false;
  bool _hasNext = true;
  String? _error;

  String get _args => discoverArgs(widget.section);
  int get _perPage => discoverPerPage(widget.section);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(anilistClientProvider).browsePage(
            'discover_${widget.section.name}_list',
            _args,
            page: _page + 1,
            perPage: _perPage,
          );
      if (!mounted) return;
      final cards = cardsFromRaw(r.items);
      // برای تاپ ۱۰ هفتگی: تغییر رتبه نسبت به اسنپ‌شات
      setState(() {
        _page += 1;
        _hasNext = r.hasNext;
        for (final c in cards) {
          if (_seen.add(c.anilistId)) _items.add(c);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _seen.clear();
      _page = 0;
      _hasNext = true;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.section.titleFa)),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items.isEmpty) {
      if (_error != null) {
        return ErrorView(message: _error!, onRetry: _load);
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const AnimeCardSkeleton(),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final d = _items[i];
                final delta = widget.section == DiscoverSection.weeklyTop
                    ? ref
                        .watch(discoverSectionProvider(
                            DiscoverSection.weeklyTop))
                        .maybeWhen(
                          data: (dd) => dd.rankDelta[d.anilistId],
                          orElse: () => null,
                        )
                    : null;
                return Stack(
                  children: [
                    AnimeCard(
                      data: d,
                      onTap: () =>
                          context.push('/franchise/${d.anilistId}'),
                    ),
                    if (delta != null && delta != 0)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: delta > 0
                                ? AppColors.completed
                                : AppColors.dropped,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${delta > 0 ? '↑' : '↓'}${toFa(delta.abs())}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }, childCount: _items.length),
            ),
          ),
          SliverToBoxAdapter(child: _footer()),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (!_hasNext) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'به انتهای لیست رسیدی',
            style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox(height: 32);
  }
}

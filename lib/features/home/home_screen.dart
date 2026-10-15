import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/widgets/anime_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/homewidget/home_widget_service.dart';
import '../../data/models/achievement.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../data/storage/economy.dart';
import 'widgets/continue_watching.dart';
import 'widgets/new_episodes_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            final messenger = ScaffoldMessenger.of(context);
            final results = await Future.wait(
              HomeSection.values.map(
                (s) => ref
                    .read(homeSectionProvider(s).notifier)
                    .refresh()
                    .then((_) => true)
                    .catchError((_) => false),
              ),
            );
            if (results.contains(false)) {
              if (!context.mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'به‌روزرسانی بعضی بخش‌ها ناموفق بود. داده‌های قبلی نمایش داده می‌شوند.',
                  ),
                ),
              );
            }
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const _Header(),
              const _EventListeners(),
              const _HomeWidgetSync(),
              const _EconomyStrip(),
              const NewEpisodesBanner(),
              const ContinueWatching(),
              for (final s in HomeSection.values) _SectionBlock(section: s),
            ],
          ),
        ),
      ),
    );
  }
}

/// نوار اقتصاد: لول، XP و سکه شفق — با لمس به صفحه جوایز می‌رود.
class _EconomyStrip extends ConsumerWidget {
  const _EconomyStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eco = ref.watch(economyProvider);
    final level = eco.level;
    final cur = Economy.levelThresholds[level];
    final next = level + 1 < Economy.levelThresholds.length
        ? Economy.levelThresholds[level + 1]
        : null;
    final ratio = next == null
        ? 1.0
        : ((eco.xp - cur) / (next - cur)).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: InkWell(
        onTap: () => context.push('/rewards'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  Economy.levelNames[level],
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.primaryTextOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHighOf(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.monetization_on_rounded,
                size: 16,
                color: AppColors.starTextOf(context),
              ),
              const SizedBox(width: 4),
              Text(
                toFa(eco.coins),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.starTextOf(context),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: AppColors.textSecondaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شنونده رویدادهای لول‌آپ و اچیومنت برای نمایش جشن درون‌برنامه‌ای.
class _EventListeners extends ConsumerWidget {
  const _EventListeners();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int?>(levelUpEventProvider, (prev, next) {
      if (next == null || next < 0 || next >= Economy.levelNames.length) {
        return;
      }
      if (!context.mounted) return;
      ref.read(levelUpEventProvider.notifier).state = null;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.military_tech_rounded,
                color: AppColors.starTextOf(context),
              ),
              SizedBox(width: 8),
              Text('لول آپ!'),
            ],
          ),
          content: Text(
            'به لول ${Economy.levelNames[next]} رسیدی! همین‌طور ادامه بده.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('عالیه!'),
            ),
          ],
        ),
      );
    });

    ref.listen<List<AchievementDef>>(achievementEventProvider, (prev, next) {
      if (next.isEmpty) return;
      if (!context.mounted) return;
      ref.read(achievementEventProvider.notifier).state = const [];
      final messenger = ScaffoldMessenger.of(context);
      for (final a in next) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '🏆 اچیومنت «${a.titleFa}» باز شد! (+${toFa(a.xp)} XP)',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    return const SizedBox.shrink();
  }
}

class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({required this.section});
  final HomeSection section;

  static const double _rowHeight = 236;
  static const double _cardWidth = 138;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeSectionProvider(section));

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: SectionTitle(section.titleFa)),
                TextButton(
                  onPressed: () => context.push('/section/${section.name}'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTextOf(context),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'بیشتر',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _rowHeight,
            child: async.when(
              loading: () => ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) => const SizedBox(
                  width: _cardWidth,
                  child: AnimeCardSkeleton(),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RowError(
                  message: friendlyError(e),
                  onRetry: () => ref.invalidate(homeSectionProvider(section)),
                ),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'موردی پیدا نشد.',
                        style: TextStyle(color: AppColors.textSecondaryOf(context)),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => SizedBox(
                        width: _cardWidth,
                        child: AnimeCard(
                          data: items[i],
                          onTap: () =>
                              context.push('/franchise/${items[i].anilistId}'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowError extends StatelessWidget {
  const _RowError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onRetry,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(height: 8),
                Text(
                  '$message\nلمس کن تا دوباره تلاش شود',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFFF472B6)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [AppColors.primaryLight, Color(0xFFF472B6)],
                ).createShader(rect),
                child: const Text(
                  'Aurora',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              Text(
                'هر انیمه، یک صفحه',
                style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'بیشتر',
            onSelected: (v) {
              if (v == 'suggest') context.push('/suggestions');
              if (v == 'plan') context.push('/plan');
              if (v == 'calendar') context.push('/calendar');
              if (v == 'stats') context.push('/stats');
              if (v == 'rewards') context.push('/rewards');
              if (v == 'import') context.push('/import');
              if (v == 'settings') context.push('/settings');
            },
            color: AppColors.surfaceOf(context),
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'suggest',
                child: Row(
                  children: [
                    Icon(Icons.casino_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('یه انیمه انتخاب کن'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'plan',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add_check_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('برنامه‌ریزی تماشا'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'calendar',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('تقویم پخش هفتگی'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('آمار تماشا'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rewards',
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('جوایز و کلکسیون'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('ایمپورت لیست'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('تنظیمات'),
                  ],
                ),
              ),
            ],
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// همگام‌سازی هوم‌ویجت با «ادامه تماشا» و پخش امروز.
class _HomeWidgetSync extends ConsumerStatefulWidget {
  const _HomeWidgetSync();

  @override
  ConsumerState<_HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<_HomeWidgetSync> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      refreshHomeWidget(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(continueWatchingProvider, (_, _) => refreshHomeWidget(ref));
    ref.listen(weeklyAiringProvider, (_, _) => refreshHomeWidget(ref));
    return const SizedBox.shrink();
  }
}

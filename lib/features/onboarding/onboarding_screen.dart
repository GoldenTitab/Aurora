import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/storage/migrations.dart';
import '../settings/whats_new_screen.dart';
import '../../core/i18n/lang.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static List<_PageData> get _pages => <_PageData>[
    _PageData(
      icon: Icons.auto_awesome_rounded,
      title: tr('welcome_to_aurora'),
      body:
          tr('aurora_is_an_anime_tracker_log_your_watch_status') +
          tr('mark_episodes_watched_score_franchises_and_write') +
          tr('notes_all_in_english_fully_offline_on_your_own_p'),
    ),
    _PageData(
      icon: Icons.account_tree_rounded,
      title: tr('the_franchise_concept'),
      body:
          tr('most_anime_aren_t_just_one_season_aurora_finds_r') +
          tr('ovas_and_spin_offs_and_groups_them_all_under_one') +
          tr('like_a_tree_whose_branches_are_each_a_title_with') +
          tr('progress_visible_in_one_place'),
    ),
    _PageData(
      icon: Icons.download_rounded,
      title: tr('bring_your_list'),
      body:
          tr('if_you_already_have_a_list_on_anilist_or_myanime') +
          tr('to_import_it_all_into_aurora_at_once_it_s_also_a') +
          tr('from_settings'),
    ),
    _PageData(
      icon: Icons.emoji_events_rounded,
      title: tr('gamified_like_a_game'),
      body:
          tr('earn_xp_by_watching_and_level_up_from_beginner_t') +
          tr('collect_shafaq_coins_and_spend_them_on_collectib') +
          tr('daily_weekly_missions_and_around_a_hundred_achie'),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    _finishing = true;
    await Hive.box<String>(Boxes.meta).put('onboarding_done', '1');
    if (!mounted) return;
    final showWhatsNew = await WhatsNew.consume();
    if (!mounted) return;
    if (showWhatsNew) {
      await showDialog<void>(
        context: context,
        builder: (_) => const WhatsNewDialog(),
      );
      if (!mounted) return;
    }
    context.go('/discover');
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _finish, child: Text(tr('skip'))),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.primary
                          : AppColors.textSecondaryOf(
                              context,
                            ).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? tr('start') : tr('next')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _PageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            style: TextStyle(
              fontSize: 15,
              height: 1.9,
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          if (data.icon == Icons.download_rounded) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push('/import'),
              icon: const Icon(Icons.download_rounded),
              label: Text(tr('import_from_anilist_mal')),
            ),
          ],
        ],
      ),
    );
  }
}

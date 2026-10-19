import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/discover/discover_list_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/discover/filter_screen.dart';
import '../../features/discover/seasonal_screen.dart';
import '../../features/franchise/franchise_screen.dart';
import '../../features/calendar/weekly_calendar_screen.dart';
import '../../features/import/bulk_import_screen.dart';
import '../../features/import/import_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/rewards/pack_opening_screen.dart';
import '../../features/rewards/rewards_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../data/providers.dart' show DiscoverSection;
import '../../data/storage/migrations.dart';
import '../../features/my_list/my_list_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/privacy_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/whats_new_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/suggestions/suggestions_screen.dart';
import '../../features/plan/watch_plan_screen.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/discover',
  redirect: (context, state) {
    final done = Hive.box<String>(Boxes.meta).get('onboarding_done') == '1';
    final loc = state.matchedLocation;
    final onOnboarding = loc == '/onboarding';
    if (!done && !onOnboarding && loc != '/import') return '/onboarding';
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/whats-new',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const WhatsNewScreen(),
    ),
    GoRoute(
      path: '/privacy',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const PrivacyScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/discover',
              builder: (context, state) => const DiscoverScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/list',
              builder: (context, state) => const MyListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/calendar',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const WeeklyCalendarScreen(),
    ),
    GoRoute(
      path: '/stats',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const StatsScreen(),
    ),
    GoRoute(
      path: '/rewards',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const RewardsScreen(),
    ),
    GoRoute(
      path: '/pack',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const PackOpeningScreen(),
    ),
    GoRoute(
      path: '/filter',
      parentNavigatorKey: _rootKey,
      builder: (context, state) {
        final extra = state.extra;
        return FilterScreen(
          initialQuery: extra is String ? extra : null,
          initialFilter: extra is FilterState ? extra : null,
        );
      },
    ),
    GoRoute(
      path: '/seasonal',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const SeasonalScreen(),
    ),
    GoRoute(
      path: '/import',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const ImportScreen(),
    ),
    GoRoute(
      path: '/bulk-import',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const BulkImportScreen(),
    ),
    GoRoute(
      path: '/discover/:name',
      parentNavigatorKey: _rootKey,
      builder: (context, state) {
        final name = state.pathParameters['name'];
        final section = DiscoverSection.values.firstWhere(
          (s) => s.name == name,
          orElse: () => DiscoverSection.airing,
        );
        return DiscoverListScreen(section: section);
      },
    ),

    GoRoute(
      path: '/franchise/:id',
      parentNavigatorKey: _rootKey,
      pageBuilder: (context, state) {
        final raw = state.pathParameters['id'] ?? '';
        final Widget child;
        if (raw.startsWith('mal-')) {
          child = FranchiseScreen.mal(
            malId: int.tryParse(raw.substring(4)) ?? 0,
          );
        } else {
          child = FranchiseScreen.anilist(anilistId: int.tryParse(raw) ?? 0);
        }
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          child: child,
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/suggestions',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const SuggestionsScreen(),
    ),
    GoRoute(
      path: '/plan',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const WatchPlanScreen(),
    ),
  ],
);

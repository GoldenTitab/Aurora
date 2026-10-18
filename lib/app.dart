import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/notifications/notification_service.dart';
import 'data/providers.dart';
import 'features/settings/whats_new_screen.dart';

class AuroraApp extends ConsumerWidget {
  const AuroraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final seed = ref.watch(seedColorProvider);
    final lang = ref.watch(langProvider);

    ref.listen<String>(langProvider, (prev, next) {
      if (prev == next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
      NotificationService().refreshChannel();
    });

    return MaterialApp.router(
      title: 'Aurora',
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      theme: AppTheme.build(brightness: Brightness.light, seed: seed),
      darkTheme: AppTheme.build(brightness: Brightness.dark, seed: seed),
      themeMode: mode,
      routerConfig: appRouter,
      builder: (context, child) => Directionality(
        textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: _WhatsNewGate(child: child!),
      ),
    );
  }
}

void _rebuildAll() {
  void rebuild(Element el) {
    el.markNeedsBuild();
    el.visitChildren(rebuild);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
}

class _WhatsNewGate extends StatefulWidget {
  const _WhatsNewGate({required this.child});

  final Widget child;

  @override
  State<_WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<_WhatsNewGate> {
  static bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final show = await WhatsNew.consume();
    if (!show || !mounted) return;
    final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    await showDialog<void>(
      context: navContext,
      builder: (_) => const WhatsNewDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

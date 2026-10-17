import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/lang.dart';
import 'core_providers.dart';

// ─── Step 10: تم (روشن/تیره/سیستمی) و رنگ اصلی ─────────────────────────────

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(userExtrasProvider).themeMode();

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(userExtrasProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// زبان اپ (fa/en) — با Lang.current همگام است تا tr() همه‌جا کار کند.
class LangNotifier extends Notifier<String> {
  @override
  String build() {
    final lang = ref.read(userExtrasProvider).language();
    Lang.current = lang;
    return lang;
  }

  Future<void> set(String lang) async {
    final v = lang == 'en' ? 'en' : 'fa';
    Lang.current = v;
    state = v;
    await ref.read(userExtrasProvider).setLanguage(v);
  }
}

final langProvider = NotifierProvider<LangNotifier, String>(LangNotifier.new);

class SeedColorNotifier extends Notifier<Color> {
  @override
  Color build() => ref.read(userExtrasProvider).seedColor();

  Future<void> set(Color color) async {
    state = color;
    await ref.read(userExtrasProvider).setSeedColor(color);
  }
}

final seedColorProvider = NotifierProvider<SeedColorNotifier, Color>(
  SeedColorNotifier.new,
);

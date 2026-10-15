import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// تم پویا بر اساس روشنایی و رنگ اصلی (seed). هر دو حالت روشن و تیره
  /// از ColorScheme.fromSeed ساخته می‌شوند تا خوانایی تضمین شود.
  static ThemeData build({
    required Brightness brightness,
    required Color seed,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );

    final textTheme = GoogleFonts.vazirmatnTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }

  /// برای سازگاری با کدهای قدیمی؛ معادل تم تیره با رنگ اصلی پیش‌فرض.
  static ThemeData get dark =>
      build(brightness: Brightness.dark, seed: AppColors.primary);
}

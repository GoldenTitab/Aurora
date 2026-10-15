import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF8B5CF6);
  static const primaryLight = Color(0xFFA78BFA);

  static const background = Color(0xFF0F0B1A);
  static const surface = Color(0xFF1A1530);
  static const surfaceHigh = Color(0xFF241D40);
  static const border = Color(0xFF2E2650);

  static const textPrimary = Color(0xFFF5F3FF);
  static const textSecondary = Color(0xFFA8A3C7);

  static const star = Color(0xFFFBBF24);

  static const watching = Color(0xFF38BDF8);
  static const completed = Color(0xFF22C55E);
  static const planToWatch = Color(0xFFA78BFA);
  static const onHold = Color(0xFFF59E0B);
  static const dropped = Color(0xFFEF4444);

  // ── نسخه‌های آگاه از تم ──────────────────────────────────────────
  // در تم تیره دقیقاً همان پالت کلاسیک بالا برمی‌گردد (بدون تغییر ظاهری)؛
  // در تم روشن معادل خوانا از colorScheme تا متن روی سطح‌ها خوانا بماند.
  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color surfaceOf(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return s.brightness == Brightness.dark ? surface : s.surfaceContainer;
  }

  static Color surfaceHighOf(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return s.brightness == Brightness.dark
        ? surfaceHigh
        : s.surfaceContainerHigh;
  }

  static Color borderOf(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return s.brightness == Brightness.dark ? border : s.outlineVariant;
  }

  static Color textPrimaryOf(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return s.brightness == Brightness.dark ? textPrimary : s.onSurface;
  }

  static Color textSecondaryOf(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return s.brightness == Brightness.dark ? textSecondary : s.onSurfaceVariant;
  }

  /// رنگ متن/آیکون تاکیدی: در تم تیره بنفش روشن، در تم روشن بنفش
  /// تیره‌تر برای خوانایی.
  static Color primaryTextOf(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return s.brightness == Brightness.dark ? primaryLight : primary;
  }

  /// رنگ متن/آیکون ستاره‌ای (امتیاز، سکه): در تم روشن کهربایی تیره.
  static Color starTextOf(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return s.brightness == Brightness.dark ? star : const Color(0xFFB45309);
  }
}

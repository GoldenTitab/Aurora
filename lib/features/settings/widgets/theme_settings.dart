import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../core/i18n/lang.dart';

/// بخش «ظاهر» در صفحه‌ی تنظیمات: انتخاب حالت روشن/تیره/سیستمی و رنگ اصلی.
class ThemeSettings extends ConsumerWidget {
  const ThemeSettings({super.key});

  static const _seeds = <Color>[
    Color(0xFF8B5CF6),
    Color(0xFF38BDF8),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFF472B6),
    Color(0xFF14B8A6),
    Color(0xFFA78BFA),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final seed = ref.watch(seedColorProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
          padding: EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            tr('appearance'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments:  [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text(tr('system')),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text(tr('light')),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text(tr('dark')),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                ref.read(themeModeProvider.notifier).set(selection.first),
          ),
        ),
         Padding(
          padding: EdgeInsets.only(top: 20, bottom: 12),
          child: Text(
            tr('primary_color'),
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final color in _seeds)
              _SeedDot(
                color: color,
                selected: seed == color,
                ringColor: scheme.primary,
                onTap: () => ref.read(seedColorProvider.notifier).set(color),
              ),
          ],
        ),
      ],
    );
  }
}

class _SeedDot extends StatelessWidget {
  const _SeedDot({
    required this.color,
    required this.selected,
    required this.ringColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: selected
              ? Border.all(color: ringColor, width: 3)
              : Border.all(color: color.withValues(alpha: 0.35), width: 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

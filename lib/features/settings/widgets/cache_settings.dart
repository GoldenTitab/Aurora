import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../data/remote/api_gateway.dart';
import '../../../data/storage/migrations.dart';

/// بخش «حافظه‌ی کش» در تنظیمات: نمایش حجم تقریبی هر بخش و پاک‌سازی جدا یا کلی.
///
/// فقط کش‌ها پاک می‌شوند؛ داده‌ی کاربر (لیست، وضعیت‌ها، قسمت‌های دیده‌شده،
/// اقتصاد و پشتیبان‌ها) دست‌نخورده می‌ماند.
class CacheSettings extends StatefulWidget {
  const CacheSettings({super.key});

  @override
  State<CacheSettings> createState() => _CacheSettingsState();
}

class _CacheSection {
  const _CacheSection({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _CacheSettingsState extends State<CacheSettings> {
  bool _loading = true;
  int _imageBytes = 0;
  final Map<String, int> _boxCounts = {};

  static const _cacheBoxes = <String>[
    Boxes.apiCache,
    Boxes.franchiseCache,
    'home_cache',
    'discover_cache',
    'card_cache',
  ];

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _measure() async {
    setState(() => _loading = true);
    var imageBytes = 0;
    try {
      final tmp = await getTemporaryDirectory();
      imageBytes = await _dirSize(tmp);
    } catch (_) {}
    // هرس خودکار ورودی‌های قدیمی کش API (بیش از ۱۴ روز یا بیش از ۴۰۰ ورودی).
    try {
      await ApiGateway.pruneCache(Hive.box<String>(Boxes.apiCache));
    } catch (_) {}
    final counts = <String, int>{};
    for (final name in _cacheBoxes) {
      try {
        counts[name] = Hive.box<String>(name).length;
      } catch (_) {
        counts[name] = 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _imageBytes = imageBytes;
      _boxCounts
        ..clear()
        ..addAll(counts);
      _loading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${toFa(bytes)} بایت';
    final kb = bytes / 1024;
    if (kb < 1024) return '${toFa(kb.toStringAsFixed(1))} کیلوبایت';
    final mb = kb / 1024;
    return '${toFa(mb.toStringAsFixed(1))} مگابایت';
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('پاک‌سازی'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearImages() async {
    if (!await _confirm(
      'پاک‌سازی کش تصاویر؟',
      'تصاویر ذخیره‌شده‌ی موقت پاک می‌شوند و در صورت نیاز دوباره دانلود '
      'می‌شوند. داده‌ی لیست و پیشرفت تو دست‌نخورده می‌ماند.',
    )) {
      return;
    }
    try {
      final tmp = await getTemporaryDirectory();
      await for (final entity in tmp.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کش تصاویر پاک شد.')),
    );
    await _measure();
  }

  Future<void> _clearBoxes(List<String> names, String doneText) async {
    if (!await _confirm(
      'پاک‌سازی کش؟',
      'این کش‌ها فقط برای سرعت‌اند و دوباره ساخته می‌شوند. داده‌ی لیست و '
      'پیشرفت تو دست‌نخورده می‌ماند.',
    )) {
      return;
    }
    for (final name in names) {
      try {
        await Hive.box<String>(name).clear();
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneText)));
    await _measure();
  }

  Future<void> _clearAll() async {
    if (!await _confirm(
      'پاک‌سازی همه‌ی کش‌ها؟',
      'همه‌ی کش‌های تصاویر و API پاک می‌شوند. داده‌ی لیست، وضعیت‌ها، '
      'قسمت‌های دیده‌شده و جوایزت دست‌نخورده می‌ماند.',
    )) {
      return;
    }
    try {
      final tmp = await getTemporaryDirectory();
      await for (final entity in tmp.list(followLinks: false)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
      }
    } catch (_) {}
    for (final name in _cacheBoxes) {
      try {
        await Hive.box<String>(name).clear();
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('همه‌ی کش‌ها پاک شدند.')),
    );
    await _measure();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final sections = <_CacheSection>[
      _CacheSection(
        title: 'کش تصاویر',
        subtitle: 'حجم تقریبی: ${_formatBytes(_imageBytes)}',
      ),
      _CacheSection(
        title: 'کش API',
        subtitle:
            'تعداد ورودی: ${toFa(_boxCounts[Boxes.apiCache] ?? 0)}',
      ),
      _CacheSection(
        title: 'کش فرنچایزها',
        subtitle:
            'تعداد ورودی: ${toFa(_boxCounts[Boxes.franchiseCache] ?? 0)}',
      ),
      _CacheSection(
        title: 'کش خانه / کشف / کارت‌ها',
        subtitle: 'تعداد ورودی: ${toFa(
          (_boxCounts['home_cache'] ?? 0) +
              (_boxCounts['discover_cache'] ?? 0) +
              (_boxCounts['card_cache'] ?? 0),
        )}',
      ),
    ];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _row(sections[0], () => _clearImages()),
              const Divider(height: 1, indent: 14, endIndent: 14),
              _row(sections[1], () => _clearBoxes([Boxes.apiCache], 'کش API پاک شد.')),
              const Divider(height: 1, indent: 14, endIndent: 14),
              _row(
                sections[2],
                () => _clearBoxes(
                  [Boxes.franchiseCache],
                  'کش فرنچایزها پاک شد.',
                ),
              ),
              const Divider(height: 1, indent: 14, endIndent: 14),
              _row(
                sections[3],
                () => _clearBoxes(
                  ['home_cache', 'discover_cache', 'card_cache'],
                  'کش خانه / کشف / کارت‌ها پاک شد.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded),
            label: const Text('پاک‌سازی همه‌ی کش‌ها'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'حجم‌ها تقریبی‌اند. پاک‌سازی کش هیچ داده‌ی شخصی را حذف نمی‌کند.',
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 12,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _row(_CacheSection section, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  section.subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('پاک‌سازی')),
        ],
      ),
    );
  }
}

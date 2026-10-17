import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../data/remote/api_gateway.dart';
import '../../../data/storage/migrations.dart';
import '../../../core/i18n/lang.dart';

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
    if (bytes < 1024) return tr('b', [toFa(bytes)]);
    final kb = bytes / 1024;
    if (kb < 1024) return tr('kb', [toFa(kb.toStringAsFixed(1))]);
    final mb = kb / 1024;
    return tr('mb', [toFa(mb.toStringAsFixed(1))]);
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
            child:  Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:  Text(tr('clear_2')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearImages() async {
    if (!await _confirm(
      tr('clear_image_cache'),
      tr('cached_images_will_be_deleted_and_re_downloaded_') +
      tr('your_list_data_and_progress_will_stay_untouched'),
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
       SnackBar(content: Text(tr('image_cache_cleared'))),
    );
    await _measure();
  }

  Future<void> _clearBoxes(List<String> names, String doneText) async {
    if (!await _confirm(
      tr('clear_cache'),
      tr('these_caches_only_speed_things_up_and_are_rebuil') +
      tr('progress_will_stay_untouched'),
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
      tr('clear_all_caches_2'),
      tr('all_image_and_api_caches_will_be_cleared_your_li') +
      tr('watched_episodes_and_rewards_will_stay_untouched'),
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
       SnackBar(content: Text(tr('all_caches_cleared'))),
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
        title: tr('image_cache'),
        subtitle: tr('approx_size', [_formatBytes(_imageBytes)]),
      ),
      _CacheSection(
        title: tr('api_cache'),
        subtitle:
            tr('entries', [toFa(_boxCounts[Boxes.apiCache] ?? 0)]),
      ),
      _CacheSection(
        title: tr('franchise_cache'),
        subtitle:
            tr('entries', [toFa(_boxCounts[Boxes.franchiseCache] ?? 0)]),
      ),
      _CacheSection(
        title: tr('home_discover_cards_cache'),
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
              _row(sections[1], () => _clearBoxes([Boxes.apiCache], tr('api_cache_cleared'))),
              const Divider(height: 1, indent: 14, endIndent: 14),
              _row(
                sections[2],
                () => _clearBoxes(
                  [Boxes.franchiseCache],
                  tr('franchise_cache_cleared'),
                ),
              ),
              const Divider(height: 1, indent: 14, endIndent: 14),
              _row(
                sections[3],
                () => _clearBoxes(
                  ['home_cache', 'discover_cache', 'card_cache'],
                  tr('home_discover_cards_cache_cleared'),
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
            label:  Text(tr('clear_all_caches')),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('sizes_are_approximate_clearing_cache_never_delet'),
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
          TextButton(onPressed: onClear, child:  Text(tr('clear_2'))),
        ],
      ),
    );
  }
}

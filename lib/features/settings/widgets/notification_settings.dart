import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../data/notifications/airing_check_task.dart';
import '../../../data/notifications/notification_content.dart';
import '../../../data/notifications/notification_service.dart';
import '../../../data/storage/migrations.dart';

/// بخش «اعلان‌ها» در تنظیمات:
/// سوییچ «اعلان قسمت‌های جدید»، انتخاب ساعت بررسی روزانه (۰ تا ۲۳)
/// و دکمه «ارسال اعلان آزمایشی».
class NotificationSettings extends ConsumerStatefulWidget {
  const NotificationSettings({super.key});

  @override
  ConsumerState<NotificationSettings> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<NotificationSettings> {
  Box<String> get _meta => Hive.box<String>(Boxes.meta);

  late bool _enabled;
  late int _hour;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enabled = NotificationPrefs.isEnabled(_meta);
    _hour = NotificationPrefs.hour(_meta);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setEnabled(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final granted = await NotificationService().requestPermissions();
        if (!granted) {
          _snack('دسترسی اعلان داده نشد؛ اول از تنظیمات گوشی فعالش کن.');
          return;
        }
        await NotificationPrefs.setEnabled(_meta, true);
        await scheduleDailyAiringCheck(_hour);
      } else {
        await cancelDailyAiringCheck();
        await NotificationPrefs.setEnabled(_meta, false);
      }
      if (mounted) setState(() => _enabled = value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setHour(int hour) async {
    await NotificationPrefs.setHour(_meta, hour);
    if (_enabled) {
      // بازثبت با initialDelay جدید تا نزدیک ساعت انتخابی اجرا شود.
      await scheduleDailyAiringCheck(hour);
    }
    if (mounted) setState(() => _hour = hour);
  }

  Future<void> _sendTest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await NotificationService().requestPermissions();
      await NotificationService().showNewEpisodes(const [
        NewEpisodeNotifItem(
          entryId: 'demo-1',
          titleFa: 'انیمه نمونه',
          newCount: 3,
          latestEpisode: 12,
        ),
        NewEpisodeNotifItem(
          entryId: 'demo-2',
          titleFa: 'انیمه نمونه ۲',
          newCount: 1,
          latestEpisode: 5,
        ),
      ]);
      _snack('اعلان آزمایشی ارسال شد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('اعلان قسمت‌های جدید'),
          subtitle: const Text(
            'بررسی روزانه قسمت‌های تازه پخش‌شده انیمه‌هایت',
          ),
          value: _enabled,
          onChanged: _busy ? null : _setEnabled,
        ),
        if (_enabled) ...[
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            key: ValueKey(_hour),
            initialValue: _hour,
            decoration: const InputDecoration(
              labelText: 'ساعت بررسی روزانه',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(
                  value: h,
                  child: Text('ساعت ${toFa(h)}'),
                ),
            ],
            onChanged: (h) {
              if (h != null) _setHour(h);
            },
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _sendTest,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('ارسال اعلان آزمایشی'),
        ),
        const SizedBox(height: 8),
        Text(
          'زمان‌بندی بررسی روزانه تقریبی است و سیستم‌عامل ممکن است آن را '
          'چند ساعت جابه‌جا کند. در iOS زمان اجرا کاملاً با سیستم است.',
          style: TextStyle(
            color: AppColors.textSecondaryOf(context),
            fontSize: 12,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

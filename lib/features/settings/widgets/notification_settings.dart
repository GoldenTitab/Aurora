import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../data/notifications/airing_check_task.dart';
import '../../../data/notifications/notification_content.dart';
import '../../../data/notifications/notification_service.dart';
import '../../../data/storage/migrations.dart';
import '../../../core/i18n/lang.dart';

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
          _snack(tr('notification_permission_not_granted_enable_it_in'));
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
      await scheduleDailyAiringCheck(hour);
    }
    if (mounted) setState(() => _hour = hour);
  }

  Future<void> _sendTest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await NotificationService().requestPermissions();
      await NotificationService().showNewEpisodes([
        NewEpisodeNotifItem(
          entryId: 'demo-1',
          titleFa: tr('sample_anime'),
          newCount: 3,
          latestEpisode: 12,
        ),
        NewEpisodeNotifItem(
          entryId: 'demo-2',
          titleFa: tr('sample_anime_2'),
          newCount: 1,
          latestEpisode: 5,
        ),
      ]);
      _snack(tr('test_notification_sent'));
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
          title: Text(tr('new_episode_notifications')),
          subtitle: Text(
            tr('daily_check_for_newly_aired_episodes_of_your_ani'),
          ),
          value: _enabled,
          onChanged: _busy ? null : _setEnabled,
        ),
        if (_enabled) ...[
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            key: ValueKey(_hour),
            initialValue: _hour,
            decoration: InputDecoration(
              labelText: tr('daily_check_time'),
              border: OutlineInputBorder(),
            ),
            items: [
              for (var h = 0; h < 24; h++)
                DropdownMenuItem(value: h, child: Text(tr('00', [toFa(h)]))),
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
          label: Text(tr('send_test_notification')),
        ),
        const SizedBox(height: 8),
        Text(
          tr('the_daily_check_schedule_is_approximate_and_the_') +
              tr('by_a_few_hours_on_ios_timing_is_entirely_up_to_t'),
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

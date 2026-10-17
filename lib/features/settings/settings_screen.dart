import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/providers.dart';
import '../../data/storage/data_export.dart';
import '../../data/storage/migrations.dart';
import 'widgets/cache_settings.dart';
import 'widgets/notification_settings.dart';
import 'widgets/theme_settings.dart';
import '../../core/i18n/lang.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copyFull() async {
    try {
      await Clipboard.setData(ClipboardData(text: DataExport.buildFull()));
      _snack(tr('full_export_copied_save_it_in_a_text_file'));
    } catch (_) {
      _snack(tr('export_copy_failed'));
    }
  }

  Future<void> _restoreFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      _snack(tr('clipboard_is_empty'));
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('restore_from_clipboard_2')),
        content: Text(
          tr('current_data_statuses_notes_scores_coins_and_car') +
              tr('will_be_replaced_with_the_clipboard_content'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('restore_2')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await DataExport.importFull(text);
    if (result.ok && mounted) {
      ref.invalidate(watchStatusProvider);
      ref.invalidate(episodeProgressProvider);
      ref.invalidate(userExtrasProvider);
      ref.invalidate(economyProvider);
      ref.invalidate(missionsProvider);
      ref.invalidate(franchiseRepositoryProvider);
      ref.invalidate(myListFranchisesProvider);
      ref.invalidate(achievementsProvider);
      ref.invalidate(cardsProvider);
      setState(() {});
    }
    _snack(result.message);
  }

  Future<void> _restoreBackup() async {
    final backup = Migrations.latestBackup();
    if (backup == null) {
      _snack(tr('no_automatic_backup_exists'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('restore_the_automatic_backup')),
        content: Text(
          tr('statuses_and_watched_episodes_revert_to_the_last') +
              tr('later_changes_are_lost_before_restoring_a_backup') +
              tr('is_taken_as_well'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('restore')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await Migrations.restoreLatestBackup();
      if (!mounted) return;
      if (ok) {
        ref.invalidate(watchStatusProvider);
        ref.invalidate(episodeProgressProvider);
        setState(() {});
        _snack(tr('backup_restored'));
      } else {
        _snack(tr('no_automatic_backup_exists'));
      }
    } catch (_) {
      if (!mounted) return;
      _snack(tr('restore_failed_current_data_is_untouched'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = Hive.box<String>(Boxes.watchStatus).length;
    final episodes = Hive.box<String>(Boxes.episodeProgress).length;
    final backups = Migrations.backupCount();
    final version = Migrations.readVersion();

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _GroupTitle(tr('my_data')),
          _InfoCard(
            rows: [
              (tr('app_version'), toFa(kAppVersion)),
              (tr('entries_with_a_status'), toFa(statuses)),
              (tr('seasons_with_watched_episodes'), toFa(episodes)),
              (tr('data_structure_version'), toFa(version)),
              (tr('automatic_backups'), toFa(backups)),
            ],
          ),
          const SizedBox(height: 12),
          _GroupTitle(tr('backup_transfer')),
          FilledButton.icon(
            onPressed: _copyFull,
            icon: const Icon(Icons.copy_rounded),
            label: Text(tr('copy_full_export_json')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _restoreFromClipboard,
            icon: const Icon(Icons.paste_rounded),
            label: Text(tr('restore_from_clipboard')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: backups == 0 ? null : _restoreBackup,
            icon: const Icon(Icons.restore_rounded),
            label: Text(tr('restore_latest_automatic_backup')),
          ),
          const SizedBox(height: 8),
          Text(
            tr('the_full_export_includes_statuses_notes_scores_c') +
                tr('is_enough_to_move_to_another_phone_automatic_bac') +
                tr('and_are_deleted_when_the_app_is_removed'),
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          _GroupTitle(tr('appearance')),
          const ThemeSettings(),
          const SizedBox(height: 8),
          _GroupTitle(tr('language')),
          const _LanguageSettings(),
          const SizedBox(height: 8),
          _GroupTitle(tr('spoiler_free')),
          const _SpoilerFreeSwitch(),
          const SizedBox(height: 8),
          _GroupTitle(tr('notifications')),
          const NotificationSettings(),
          const SizedBox(height: 8),
          _GroupTitle(tr('cache')),
          const CacheSettings(),
          const SizedBox(height: 8),
          _GroupTitle(tr('help_info')),
          OutlinedButton.icon(
            onPressed: () => context.push('/onboarding'),
            icon: const Icon(Icons.school_rounded),
            label: Text(tr('replay_tutorial')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/whats-new'),
            icon: const Icon(Icons.new_releases_rounded),
            label: Text(tr('what_s_new')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/privacy'),
            icon: const Icon(Icons.privacy_tip_rounded),
            label: Text(tr('privacy')),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.$1,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                  Text(
                    r.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SpoilerFreeSwitch extends ConsumerWidget {
  const _SpoilerFreeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(userExtrasProvider);
    return SwitchListTile(
      title: Text(tr('spoiler_free_mode')),
      subtitle: Text(
        tr('story_summaries_of_franchises_you_haven_t_starte') +
            tr('unwatched_seasons_are_blurred_so_nothing_gets_sp'),
        style: TextStyle(fontSize: 12, height: 1.7),
      ),
      value: extras.spoilerFree(),
      onChanged: (v) async {
        await extras.setSpoilerFree(v);
        ref.invalidate(userExtrasProvider);
      },
    );
  }
}

class _LanguageSettings extends ConsumerWidget {
  const _LanguageSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: 'fa',
          label: Text('فارسی'),
          icon: Icon(Icons.language_rounded),
        ),
        ButtonSegment<String>(
          value: 'en',
          label: Text('English'),
          icon: Icon(Icons.language_rounded),
        ),
      ],
      selected: {lang},
      onSelectionChanged: (s) => ref.read(langProvider.notifier).set(s.first),
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.comfortable,
      ),
    );
  }
}

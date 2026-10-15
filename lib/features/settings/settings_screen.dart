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
import 'widgets/backup_settings.dart';
import 'widgets/cache_settings.dart';
import 'widgets/notification_settings.dart';
import 'widgets/theme_settings.dart';

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

  Future<void> _copyExport() async {
    try {
      await Clipboard.setData(ClipboardData(text: DataExport.build()));
      _snack('خروجی JSON کپی شد. آن را در یک فایل متنی (Notepad) ذخیره کن.');
    } catch (_) {
      _snack('کپی خروجی ناموفق بود.');
    }
  }

  Future<void> _restoreBackup() async {
    final backup = Migrations.latestBackup();
    if (backup == null) {
      _snack('پشتیبان خودکاری وجود ندارد.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازگردانی پشتیبان خودکار؟'),
        content: const Text(
          'وضعیت‌ها و قسمت‌های دیده‌شده به حالت آخرین پشتیبان برمی‌گردد و '
          'تغییرهای بعد از آن از بین می‌رود. قبل از بازگردانی، از وضعیت فعلی '
          'هم یک پشتیبان گرفته می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بازگردانی'),
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
        _snack('پشتیبان بازگردانی شد.');
      } else {
        _snack('پشتیبان خودکاری وجود ندارد.');
      }
    } catch (_) {
      if (!mounted) return;
      _snack('بازگردانی ناموفق بود؛ دیتای فعلی دست‌نخورده ماند.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = Hive.box<String>(Boxes.watchStatus).length;
    final episodes = Hive.box<String>(Boxes.episodeProgress).length;
    final backups = Migrations.backupCount();
    final version = Migrations.readVersion();

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _GroupTitle('دیتای من'),
          _InfoCard(
            rows: [
              ('نسخه‌ی اپ', toFa(kAppVersion)),
              ('اثرهای دارای وضعیت', toFa(statuses)),
              ('فصل‌های دارای قسمت دیده‌شده', toFa(episodes)),
              ('نسخه‌ی ساختار دیتا', toFa(version)),
              ('پشتیبان‌های خودکار', toFa(backups)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _copyExport,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('کپی خروجی دیتا (JSON)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: backups == 0 ? null : _restoreBackup,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('بازگردانی آخرین پشتیبان خودکار'),
          ),
          const SizedBox(height: 8),
          Text(
            'پشتیبان خودکار قبل از هر به‌روزرسانی ساختار دیتا گرفته می‌شود و '
            'فقط داخل خود اپ می‌ماند. با حذف اپ از گوشی از بین می‌رود، پس '
            'اگر می‌خواهی دیتایت بماند، خروجی JSON را جداگانه ذخیره کن.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          const _GroupTitle('ظاهر'),
          const ThemeSettings(),
          const SizedBox(height: 8),
          const _GroupTitle('بدون اسپویل'),
          const _SpoilerFreeSwitch(),
          const SizedBox(height: 8),
          const _GroupTitle('اعلان‌ها'),
          const NotificationSettings(),
          const SizedBox(height: 8),
          const _GroupTitle('ایمپورت'),
          OutlinedButton.icon(
            onPressed: () => context.push('/import'),
            icon: const Icon(Icons.download_rounded),
            label: const Text('ایمپورت لیست از AniList / MAL'),
          ),
          const SizedBox(height: 8),
          const _GroupTitle('پشتیبان‌گیری و انتقال'),
          const BackupSettings(),
          const SizedBox(height: 8),
          const _GroupTitle('حافظه‌ی کش'),
          const CacheSettings(),
          const SizedBox(height: 8),
          const _GroupTitle('راهنما و اطلاعات'),
          OutlinedButton.icon(
            onPressed: () => context.push('/onboarding'),
            icon: const Icon(Icons.school_rounded),
            label: const Text('پخش مجدد آموزش'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/whats-new'),
            icon: const Icon(Icons.new_releases_rounded),
            label: const Text('تازه‌های نسخه'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/privacy'),
            icon: const Icon(Icons.privacy_tip_rounded),
            label: const Text('حریم خصوصی'),
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
                      style: TextStyle(color: AppColors.textSecondaryOf(context)),
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

/// سوییچ «حالت بدون اسپویل»: خلاصه‌ی مجموعه‌های شروع‌نشده و کاور
/// فصل‌های دیده‌نشده تار می‌شوند تا داستان لو نرود.
class _SpoilerFreeSwitch extends ConsumerWidget {
  const _SpoilerFreeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(userExtrasProvider);
    return SwitchListTile(
      title: const Text('حالت بدون اسپویل'),
      subtitle: const Text(
        'خلاصه‌ی داستان مجموعه‌هایی که هنوز شروع نکرده‌ای و کاور '
        'فصل‌هایی که ندیده‌ای تار می‌شود تا چیزی لو نرود.',
        style: TextStyle(fontSize: 12, height: 1.7),
      ),
      value: extras.spoilerFree(),
      onChanged: (v) async {
        await extras.setSpoilerFree(v);
        // ignore: unused_result
        ref.invalidate(userExtrasProvider);
      },
    );
  }
}

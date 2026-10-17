import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/i18n/lang.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/storage/migrations.dart';

/// منطق «یک بار نمایش به‌ازای هر نسخه».
///
/// بعد از این‌که آنبوردینگ تمام شد، هر بار که نسخه‌ی اپ عوض شده باشد
/// (کلید `last_seen_version` در باکس meta)، دیالوگ/صفحه‌ی «تازه‌ها» یک بار
/// نشان داده می‌شود. در اولین اجرای تمیز، نسخه فقط ثبت می‌شود و چیزی
/// نشان داده نمی‌شود تا کاربر تازه‌کار با دیالوگ اضافه مواجه نشود.
class WhatsNew {
  WhatsNew._();

  static const versionKey = 'last_seen_version';

  /// نسخه‌ی فعلی را ثبت می‌کند و برمی‌گرداند که آیا باید «تازه‌ها»
  /// نمایش داده شود یا نه.
  static Future<bool> consume() async {
    final box = Hive.box<String>(Boxes.meta);
    final seen = box.get(versionKey);
    if (box.get('onboarding_done') != '1') {
      // نصب تازه: فقط نسخه ثبت شود تا بعداً «به‌روزرسانی» حساب نشود.
      if (seen == null) await box.put(versionKey, kAppVersion);
      return false;
    }
    await box.put(versionKey, kAppVersion);
    // کاربر قدیمی که کلید نسخه را ندارد (نسخه‌های قبل از ۱٫۱٫۰) هم
    // به‌روزرسانی محسوب می‌شود و «تازه‌ها» یک بار نمایش داده می‌شود.
    return seen == null || seen != kAppVersion;
  }
}

class _ChangeEntry {
  const _ChangeEntry(this.version, this.items);

  final String version;
  final List<String> items;
}

/// ورودی‌های تغییرات — فقط قابلیت‌هایی که واقعاً در کد هستند.
List<_ChangeEntry> get _changelog => <_ChangeEntry>[
  _ChangeEntry(tr('1_1_0'), [
    tr('4_page_onboarding_tutorial_to_get_started_with_t'),
    tr('the_what_s_new_screen_shown_after_every_update'),
    tr('privacy_policy_screen_and_cache_management_secti'),
    tr('custom_splash_screen_on_app_launch'),
  ]),
  _ChangeEntry(tr('1_0_0'), [
    tr('user_levels_from_beginner_to_expert_based_on_xp'),
    tr('shafaq_coins_and_the_character_collectible_card_'),
    tr('around_100_achievements_and_daily_weekly_mission'),
    tr('discover_tab_trends_top_100_series_and_movies_to'),
    tr('import_your_list_from_anilist_and_mal_1_10_score'),
  ]),
];

/// دیالوگ «تازه‌های نسخه» — قابل بستن با دکمه یا لمس بیرون.
class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('what_s_new_in', [toFa(kAppVersion)])),
      content: const SingleChildScrollView(child: _ChangelogBody()),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('ok')),
        ),
      ],
    );
  }
}

/// صفحه‌ی کامل «تازه‌های نسخه» (از تنظیمات هم قابل دسترسی است).
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('what_s_new'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            tr('current_version', [toFa(kAppVersion)]),
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const _ChangelogBody(),
        ],
      ),
    );
  }
}

class _ChangelogBody extends StatelessWidget {
  const _ChangelogBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in _changelog) ...[
          Text(
            tr('version', [entry.version]),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final item in entry.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(height: 1.8, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/i18n/lang.dart';
import '../../core/theme/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static List<(String, String)> get _sections => <(String, String)>[
    (
      tr('your_data_on_your_phone'),
      tr('all_aurora_data_your_watch_list_statuses_watched') +
          tr('scores_notes_xp_shafaq_coins_cards_missions_and') +
          tr('achievements_are_stored_only_in_this_phone_s_int') +
          tr('a_hive_database_no_server_of_ours_has_this_data_') +
          tr('nothing_leaves_your_phone_without_your_own_actio'),
    ),
    (
      tr('internet_access_is_only_for_public_content'),
      tr('the_app_connects_to_the_public') +
          tr('anilist_jikan_and_myanimelist_apis_to_fetch_anim') +
          tr('send_only_the_anime_id_no_personal_data_watch_li') +
          tr('user_id_is_sent_with_them'),
    ),
    (
      tr('no_account_needed'),
      tr('aurora_needs_no_account_sign_in_email_or_phone_n') +
          tr('online_profile_for_you_importing_from_anilist_ma') +
          tr('public_username_and_no_password_is_ever_asked_fo'),
    ),
    (
      tr('no_ads_no_tracking'),
      tr('there_are_no_ads_ad_trackers_user_behavior_analy') +
          tr('third_party_data_collection_sdks_in_the_app'),
    ),
    (
      tr('backup_and_data_deletion'),
      tr('automatic_backups_stay_inside_the_app_with_copy_') +
          tr('json_in_settings_you_can_take_a_manual_copy_and_') +
          tr('you_can_wipe_everything_from_the_phone_by_cleari') +
          tr('deleting_the_app_erases_all_data_permanently'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('privacy'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            tr('aurora_is_built_to_keep_your_data_with_you'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in _sections) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.$2,
                    style: TextStyle(
                      height: 1.9,
                      fontSize: 14,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            tr('publishing_note_to_publish_on_google_play_this_p') +
                tr('public_url_and_that_link_registered_on_the_app_s') +
                tr('play_store_page'),
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

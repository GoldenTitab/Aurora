import '../models/achievement.dart';
import '../../core/i18n/lang.dart';

List<AchievementDef> buildAchievements() {
  final list = <AchievementDef>[];

  void add(
    String id,
    String title,
    String desc,
    String cat,
    int xp,
    int coins,
    bool Function(AchCtx) test,
  ) {
    list.add(
      AchievementDef(
        id: id,
        titleFa: title,
        descFa: desc,
        categoryFa: cat,
        xp: xp,
        coins: coins,
        test: test,
      ),
    );
  }

  add(
    'first_ep',
    tr('first_step'),
    tr('you_logged_your_first_episode'),
    tr('firsts'),
    10,
    10,
    (c) => c.episodesWatched >= 1,
  );
  add(
    'first_rate',
    tr('rookie_critic'),
    tr('you_gave_your_first_score'),
    tr('firsts'),
    10,
    10,
    (c) => c.ratingsGiven >= 1,
  );
  add(
    'first_note',
    tr('memory_keeper'),
    tr('you_wrote_your_first_note'),
    tr('firsts'),
    10,
    10,
    (c) => c.notesWritten >= 1,
  );
  add(
    'first_card',
    tr('collector'),
    tr('you_got_your_first_card'),
    tr('firsts'),
    15,
    15,
    (c) => c.cardsOwned >= 1,
  );
  add(
    'first_pack',
    tr('first_draw'),
    tr('you_opened_your_first_card_pack'),
    tr('firsts'),
    15,
    15,
    (c) => c.packsOpened >= 1,
  );

  const epMiles = [10, 50, 100, 250, 500, 1000, 2500, 5000, 7500];
  final epTitles = [
    tr('10_club'),
    tr('50_club'),
    tr('100_club'),
    tr('250_club'),
    tr('500_club'),
    tr('1000_club'),
    tr('2500_club'),
    tr('5000_club'),
    tr('episode_titan'),
  ];
  for (var i = 0; i < epMiles.length; i++) {
    final n = epMiles[i];
    add(
      'ep_$n',
      epTitles[i],
      tr('episodes_watched', [n]),
      tr('watch'),
      20 + i * 15,
      20 + i * 10,
      (c) => c.episodesWatched >= n,
    );
  }

  for (final n in [1, 5, 10, 25, 50]) {
    add(
      'frdone_$n',
      tr('finisher', [n]),
      tr('you_completed_franchises', [n]),
      tr('franchise'),
      30 + n,
      20 + n * 2,
      (c) => c.franchisesCompleted >= n,
    );
  }

  for (final n in [1, 10, 25, 50, 100]) {
    add(
      'frstart_$n',
      tr('adventurer', [n]),
      tr('you_started_franchises', [n]),
      tr('franchise'),
      15 + n,
      10 + n,
      (c) => c.franchisesStarted >= n,
    );
  }

  for (final n in [3, 5, 10, 15, 20]) {
    add(
      'genre_$n',
      tr('genre_taste', [n]),
      tr('you_watched_anime_from_different_genres', [n]),
      tr('variety'),
      20 + n * 3,
      15 + n * 2,
      (c) => c.distinctGenres >= n,
    );
  }

  const streakMiles = [2, 3, 7, 14, 30, 60, 100];
  final streakTitles = [
    tr('2_day_streak'),
    tr('3_day_streak'),
    tr('weekly_streak'),
    tr('2_week_streak'),
    tr('monthly_streak'),
    tr('2_month_streak'),
    tr('100_day_streak'),
  ];
  for (var i = 0; i < streakMiles.length; i++) {
    final n = streakMiles[i];
    add(
      'streak_$n',
      tr('streak_2', [streakTitles[i]]),
      tr('days_watched_in_a_row', [n]),
      tr('streak'),
      25 + i * 20,
      20 + i * 15,
      (c) => c.streak >= n,
    );
  }

  for (final n in [1, 10, 25, 50, 100]) {
    add(
      'rate_$n',
      tr('judge', [n]),
      tr('you_scored_titles', [n]),
      tr('score'),
      15 + n,
      10 + n,
      (c) => c.ratingsGiven >= n,
    );
  }

  for (final n in [1, 5, 10, 25, 50]) {
    add(
      'note_$n',
      tr('writer', [n]),
      tr('you_wrote_notes', [n]),
      tr('note'),
      15 + n * 2,
      10 + n,
      (c) => c.notesWritten >= n,
    );
  }

  for (final n in [1, 10, 25]) {
    add(
      'frating_$n',
      tr('rater', [n]),
      tr('you_gave_1_10_scores_to_franchises', [n]),
      tr('score'),
      20 + n * 2,
      15 + n,
      (c) => c.franchiseRatings >= n,
    );
  }

  for (final n in [1, 10, 25, 50, 100]) {
    add(
      'cards_$n',
      tr('collection', [n]),
      tr('you_collected_cards', [n]),
      tr('card'),
      20 + n,
      15 + n,
      (c) => c.cardsOwned >= n,
    );
  }
  final rarities = [
    ('common', tr('common')),
    ('uncommon', tr('uncommon')),
    ('rare', tr('rare')),
    ('epic', tr('epic')),
    ('legendary', tr('legendary')),
    ('waifu', tr('waifu')),
    ('husbando', tr('husbando')),
  ];
  for (final r in rarities) {
    for (final n in [1, 5, 10]) {
      add(
        'card_${r.$1}_$n',
        '${r.$2} × $n',
        tr('you_own_cards', [n, r.$2]),
        tr('card'),
        25 + n * 3,
        20 + n * 2,
        (c) => (c.cardsPerRarity[r.$1] ?? 0) >= n,
      );
    }
  }

  for (final n in [1, 5, 10, 25]) {
    add(
      'pack_$n',
      tr('opener', [n]),
      tr('you_opened_card_packs', [n]),
      tr('card'),
      20 + n * 2,
      0,
      (c) => c.packsOpened >= n,
    );
  }

  for (final n in [100, 500, 1000, 2500, 5000]) {
    add(
      'coins_$n',
      tr('tycoon', [n]),
      tr('you_earned_a_total_of_shafaq', [n]),
      tr('coin'),
      15 + n ~/ 20,
      0,
      (c) => c.coinsEarned >= n,
    );
  }

  for (final n in [1, 10, 25, 50]) {
    add(
      'mission_$n',
      tr('mission_2', [n]),
      tr('you_completed_missions', [n]),
      tr('mission'),
      20 + n * 2,
      n,
      (c) => c.missionsDone >= n,
    );
  }

  const levelUps = [
    (1, 'Novice'),
    (2, 'Intermediate'),
    (3, 'Advanced'),
    (4, 'Expert'),
  ];
  for (final l in levelUps) {
    add(
      'level_${l.$1}',
      tr('level_2', [l.$2]),
      tr('you_reached_level', [l.$2]),
      tr('level'),
      50 + l.$1 * 50,
      50 + l.$1 * 25,
      (c) => c.level >= l.$1,
    );
  }

  const hourMiles = [10, 50, 100, 250, 500];
  for (final h in hourMiles) {
    add(
      'hours_$h',
      tr('h', [h]),
      tr('you_watched_hours_of_anime', [h]),
      tr('watch'),
      30 + h ~/ 2,
      20 + h ~/ 5,
      (c) => c.watchMinutes >= h * 60,
    );
  }

  add(
    'import_1',
    tr('the_importer'),
    tr('you_imported_your_list_from_mal_or_anilist'),
    tr('misc'),
    50,
    50,
    (c) => c.importDone,
  );

  for (final n in [7, 30, 100]) {
    add(
      'checkin_$n',
      tr('day_attendance', [n]),
      tr('you_opened_the_app_days', [n]),
      tr('attendance'),
      20 + n,
      15 + n ~/ 2,
      (c) => c.checkins >= n,
    );
  }

  for (final n in [100, 500, 1000, 2500, 5000, 10000]) {
    add(
      'xp_$n',
      '$n XP',
      tr('you_earned_xp', [n]),
      tr('level'),
      0,
      n ~/ 20,
      (c) => c.xpTotal >= n,
    );
  }

  add(
    'sp_legendary',
    tr('legendary_pull'),
    tr('you_pulled_a_legendary_card'),
    tr('special'),
    100,
    100,
    (c) => (c.cardsPerRarity['legendary'] ?? 0) >= 1,
  );
  add(
    'sp_waifu',
    tr('waifu_2'),
    tr('you_pulled_a_waifu_card'),
    tr('special'),
    150,
    150,
    (c) => (c.cardsPerRarity['waifu'] ?? 0) >= 1,
  );
  add(
    'sp_husbando',
    tr('husbando_2'),
    tr('you_pulled_a_husbando_card'),
    tr('special'),
    150,
    150,
    (c) => (c.cardsPerRarity['husbando'] ?? 0) >= 1,
  );
  add(
    'sp_3rarity',
    tr('trifecta'),
    tr('own_cards_of_3_different_rarities'),
    tr('special'),
    60,
    60,
    (c) => c.cardsPerRarity.keys.length >= 3,
  );
  add(
    'sp_alldaily',
    tr('a_full_day'),
    tr('you_completed_3_missions'),
    tr('special'),
    80,
    80,
    (c) => c.missionsDone >= 3,
  );

  return list;
}

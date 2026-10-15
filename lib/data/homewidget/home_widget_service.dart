import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/utils/persian_numbers.dart';
import '../models/home_items.dart';
import '../providers.dart';

/// به‌روزرسانی هوم‌ویجت اندروید/iOS با «ادامه تماشا» و تعداد پخش امروز.
///
/// از DiscoverScreen با ref.listen روی [continueWatchingProvider] و
/// [weeklyAiringProvider] صدا زده می‌شود (هوک در discover_screen.dart).
/// کلیدهای ذخیره‌شده باید با کلیدهایی که سمت نیتیو (Kotlin/Swift)
/// خوانده می‌شوند یکی باشند:
/// - `cw_title` / `cw_sub`: عنوان و زیرعنوان «ادامه تماشا»
/// - `airing_today`: تعداد آیتم‌های پخش امروز (int)
Future<void> refreshHomeWidget(WidgetRef ref) async {
  try {
    final cw = ref.read(continueWatchingProvider);
    final airing = ref.read(weeklyAiringProvider).valueOrNull ?? const [];

    final ContinueWatchItem? top = cw.isNotEmpty ? cw.first : null;

    var todayCount = 0;
    final today = DateTime.now().weekday;
    for (final d in airing) {
      if (d.weekday == today) {
        todayCount = d.items.length;
        break;
      }
    }

    final String title;
    final String sub;
    if (top == null) {
      title = 'ادامه تماشا';
      sub = 'هنوز قسمتی شروع نشده';
    } else {
      final nextEp = top.lastEpisode + 1;
      final total = top.totalEpisodes;
      title = top.franchiseTitleFa;
      sub = 'قسمت ${toFa(nextEp)}'
          '${total > 0 ? ' از ${toFa(total)}' : ''}'
          ' • ${top.entryTitle}';
    }

    await HomeWidget.saveWidgetData<String>('cw_title', title);
    await HomeWidget.saveWidgetData<String>('cw_sub', sub);
    await HomeWidget.saveWidgetData<int>('airing_today', todayCount);

    await HomeWidget.updateWidget(
      androidName: 'AuroraWidgetProvider',
      iOSName: 'AuroraWidget',
    );
  } catch (_) {}
}

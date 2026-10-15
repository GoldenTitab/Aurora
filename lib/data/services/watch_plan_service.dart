import '../models/franchise.dart';
import '../models/watch_plan.dart';
import '../models/watch_status.dart';
import 'watch_order_service.dart';

class WatchPlanService {
  WatchPlanService({
    required this.franchises,
    required this.statuses,
    required this.episodes,
    this.minutesPerEpisode = 24,
  });

  final List<Franchise> franchises;
  final Map<String, WatchStatus> statuses;
  final Map<String, Set<int>> episodes;
  final int minutesPerEpisode;

  final _order = const WatchOrderService();

  WatchPlan buildPlan({required int minutesAvailable}) {
    final budget = Duration(minutes: minutesAvailable);
    var remaining = budget;
    final items = <WatchPlanItem>[];

    // فقط انیمه‌هایی که «در حال تماشا» یا «متوقف‌شده» هستند؛
    // چیزی که اصلاً شروع نشده (بدون وضعیت / plan-to-watch) انتخاب نمی‌شود.
    final eligible = franchises.where(_isEligible).toList();
    // اولویت: watching → onHold
    eligible.sort((a, b) => _priority(b).compareTo(_priority(a)));

    for (final f in eligible) {
      if (remaining.inMinutes < 10) break;

      final order = _order.compute(f);
      for (final wo in order) {
        if (!wo.isEssential) continue; // فقط داستان اصلی
        final e = wo.entry;
        final st = statuses[e.id];
        // فقط ورودیِ در حال تماشا یا متوقف‌شده.
        if (st != WatchStatus.watching && st != WatchStatus.onHold) continue;

        final totalEps = e.episodes > 0 ? e.episodes : 1;
        final watched = episodes[e.id] ?? <int>{};
        var start = 1;
        for (var i = 1; i <= totalEps; i++) {
          if (!watched.contains(i)) {
            start = i;
            break;
          }
          if (i == totalEps) start = totalEps + 1;
        }
        if (start > totalEps) continue;

        final perEp = Duration(minutes: minutesPerEpisode);
        var end = start - 1;
        var used = Duration.zero;
        for (var ep = start; ep <= totalEps; ep++) {
          if (used + perEp > remaining) break;
          used += perEp;
          end = ep;
        }
        if (end < start) continue;

        items.add(
          WatchPlanItem(
            franchise: f,
            entry: e,
            startEpisode: start,
            endEpisode: end,
            estimatedDuration: used,
          ),
        );
        remaining -= used;
        if (remaining.inMinutes < 10) break;
      }
    }

    final total = budget - remaining;
    return WatchPlan(requested: budget, total: total, items: items);
  }

  /// فرنچایز واجد شرایط است اگر حداقل یک ورودی‌اش
  /// «در حال تماشا» یا «متوقف‌شده» باشد.
  bool _isEligible(Franchise f) {
    return f.entries.any((e) {
      final st = statuses[e.id];
      return st == WatchStatus.watching || st == WatchStatus.onHold;
    });
  }

  int _priority(Franchise f) {
    final list = f.entries
        .map((e) => statuses[e.id])
        .whereType<WatchStatus>()
        .toList();
    if (list.contains(WatchStatus.watching)) return 100;
    if (list.contains(WatchStatus.onHold)) return 50;
    return 0;
  }
}

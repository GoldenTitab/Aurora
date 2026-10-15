import 'entry.dart';
import 'franchise.dart';

class WatchPlanItem {
  final Franchise franchise;
  final Entry entry;
  final int startEpisode;
  final int endEpisode;
  final Duration estimatedDuration;

  const WatchPlanItem({
    required this.franchise,
    required this.entry,
    required this.startEpisode,
    required this.endEpisode,
    required this.estimatedDuration,
  });

  int get episodeCount => endEpisode - startEpisode + 1;
}

class WatchPlan {
  final Duration requested;
  final Duration total;
  final List<WatchPlanItem> items;

  const WatchPlan({
    required this.requested,
    required this.total,
    required this.items,
  });

  bool get isEmpty => items.isEmpty;
}

import '../models/entry.dart';
import '../models/franchise.dart';

class WatchOrderItem {
  final Entry entry;
  final bool isEssential;
  final String? relationNote;

  const WatchOrderItem({
    required this.entry,
    required this.isEssential,
    this.relationNote,
  });
}

class WatchOrderService {
  const WatchOrderService();

  List<WatchOrderItem> compute(Franchise f, {List<String>? customOrder}) {
    final map = {for (final e in f.entries) e.id: e};

    if (customOrder != null && customOrder.isNotEmpty) {
      final seen = <String>{};
      final result = <WatchOrderItem>[];
      for (final id in customOrder) {
        final e = map[id];
        if (e == null) continue;
        if (!seen.add(id)) continue;
        result.add(
          WatchOrderItem(
            entry: e,
            isEssential: e.isMainStory,
            relationNote: e.relationType,
          ),
        );
      }
      for (final e in f.entries) {
        if (!seen.add(e.id)) {
          continue;
        }
        result.add(
          WatchOrderItem(
            entry: e,
            isEssential: e.isMainStory,
            relationNote: e.relationType,
          ),
        );
      }
      return result;
    }

    final order = <String>[];
    final visited = <String>{};

    void visit(Entry e) {
      if (visited.contains(e.id)) return;
      visited.add(e.id);

      final parentId = e.parentEntryId;
      if (parentId != null && map.containsKey(parentId)) {
        visit(map[parentId]!);
      }
      if (!order.contains(e.id)) order.add(e.id);

      final children = f.entries.where((c) => c.parentEntryId == e.id).toList()
        ..sort((a, b) => _dateKey(a).compareTo(_dateKey(b)));
      for (final c in children) {
        visit(c);
      }
    }

    final roots = f.entries.where((e) => e.parentEntryId == null).toList()
      ..sort((a, b) => _dateKey(a).compareTo(_dateKey(b)));
    for (final r in roots) {
      visit(r);
    }
    for (final e in f.entries) {
      visit(e);
    }

    final result = <WatchOrderItem>[];
    for (final id in order) {
      final e = map[id]!;
      result.add(
        WatchOrderItem(
          entry: e,
          isEssential: e.isMainStory,
          relationNote: e.relationType,
        ),
      );
    }
    return result;
  }

  static int _dateKey(Entry e) {
    final sd = e.startDate;
    if (sd == null) return 99999999;
    final parts = sd.split('-');
    final y = int.tryParse(parts[0]) ?? 9999;
    final mo = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
    final d = parts.length > 2 ? (int.tryParse(parts[2]) ?? 1) : 1;
    return y * 10000 + mo * 100 + d;
  }

  ({List<WatchOrderItem> essential, List<WatchOrderItem> optional})
  splitByImportance(List<WatchOrderItem> items) {
    final essential = <WatchOrderItem>[];
    final optional = <WatchOrderItem>[];
    for (final item in items) {
      if (item.isEssential) {
        essential.add(item);
      } else {
        optional.add(item);
      }
    }
    return (essential: essential, optional: optional);
  }
}

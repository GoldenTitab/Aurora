import 'package:hive/hive.dart';
import '../models/watch_status.dart';

class WatchStorage {
  WatchStorage(this._box);
  final Box<String> _box;

  Map<String, WatchStatus> loadAll() {
    final result = <String, WatchStatus>{};
    for (final key in _box.keys) {
      final k = key.toString();
      final status = WatchStatusX.fromKey(_box.get(k));
      if (status != null) result[k] = status;
    }
    return result;
  }

  Future<void> set(String entryId, WatchStatus status) =>
      _box.put(entryId, status.storageKey);

  Future<void> remove(String entryId) => _box.delete(entryId);
}

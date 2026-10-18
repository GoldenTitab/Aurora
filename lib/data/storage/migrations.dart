import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../core/i18n/lang.dart';

class Boxes {
  static const watchStatus = 'watch_status';
  static const episodeProgress = 'episode_progress';
  static const franchiseCache = 'franchise_cache';
  static const meta = 'app_meta';
  static const backup = 'user_backup';
  static const apiCache = 'api_cache';
}

class MigrationReport {
  const MigrationReport({
    required this.fromVersion,
    required this.toVersion,
    required this.backupCreated,
    this.error,
  });

  final int fromVersion;
  final int toVersion;
  final bool backupCreated;
  final String? error;

  bool get ok => error == null;
}

class Migrations {
  static const int currentVersion = 1;
  static const int _maxBackups = 3;

  static Box<String> get _meta => Hive.box<String>(Boxes.meta);
  static Box<String> get _backups => Hive.box<String>(Boxes.backup);

  static int readVersion() =>
      int.tryParse(_meta.get('schema_version') ?? '') ?? 0;

  static Future<MigrationReport> run() async {
    final from = readVersion();
    if (from >= currentVersion) {
      return MigrationReport(
        fromVersion: from,
        toVersion: from,
        backupCreated: false,
      );
    }

    var backupCreated = false;
    try {
      backupCreated = await _backupUserData(reason: 'before_v$currentVersion');

      if (from < 1) await _v1();

      await _meta.put('schema_version', '$currentVersion');
      return MigrationReport(
        fromVersion: from,
        toVersion: currentVersion,
        backupCreated: backupCreated,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Migration failed: $e');
      return MigrationReport(
        fromVersion: from,
        toVersion: from,
        backupCreated: backupCreated,
        error: e.toString(),
      );
    }
  }

  static Future<void> _v1() async {
    final box = Hive.box<String>(Boxes.franchiseCache);
    for (final key in box.keys.toList()) {
      final k = key.toString();
      if (!k.startsWith('f:')) continue;
      try {
        final map = (jsonDecode(box.get(k)!) as Map).cast<String, dynamic>();
        map['ts'] = 0;
        await box.put(k, jsonEncode(map));
      } catch (_) {}
    }
  }

  static Map<String, dynamic> snapshot() {
    Map<String, String> dump(String name) {
      final box = Hive.box<String>(name);
      return {
        for (final k in box.keys)
          if (box.get(k) != null) k.toString(): box.get(k)!,
      };
    }

    return {
      'watch_status': dump(Boxes.watchStatus),
      'episode_progress': dump(Boxes.episodeProgress),
    };
  }

  static Map<String, dynamic> snapshotFull() {
    Map<String, String> dump(String name, {String? prefix}) {
      final box = Hive.box<String>(name);
      final out = <String, String>{};
      for (final k in box.keys) {
        final ks = k.toString();
        if (prefix != null && !ks.startsWith(prefix)) continue;
        final v = box.get(ks);
        if (v != null) out[ks] = v;
      }
      return out;
    }

    return {
      ...snapshot(),
      'meta_extras': dump(Boxes.meta),
      'franchises': dump(Boxes.franchiseCache, prefix: 'f:'),
      'aliases': dump(Boxes.franchiseCache, prefix: 'a:'),
    };
  }

  static Future<bool> restoreFull(Map<String, dynamic> m) async {
    try {
      Map<String, String> read(String key) {
        final raw = m[key];
        if (raw == null) return const {};
        if (raw is! Map) throw FormatException(tr('section_is_invalid', [key]));
        return raw.map((k, v) {
          if (v is! String) {
            throw FormatException(tr('section_is_invalid', [key]));
          }
          return MapEntry(k.toString(), v);
        });
      }

      final ws = read('watch_status');
      final ep = read('episode_progress');
      final extras = read('meta_extras');
      final franchises = read('franchises');
      final aliases = read('aliases');

      await _backupUserData(reason: 'before_restore_full');

      final wsBox = Hive.box<String>(Boxes.watchStatus);
      final epBox = Hive.box<String>(Boxes.episodeProgress);
      final metaBox = Hive.box<String>(Boxes.meta);
      final fBox = Hive.box<String>(Boxes.franchiseCache);

      await wsBox.clear();
      await wsBox.putAll(ws);
      await epBox.clear();
      await epBox.putAll(ep);
      if (extras.isNotEmpty) await metaBox.putAll(extras);
      for (final kv in franchises.entries) {
        try {
          final decoded = jsonDecode(kv.value);
          if (decoded is Map && decoded['data'] is Map) {
            await fBox.put(kv.key, kv.value);
          }
        } catch (_) {}
      }
      if (aliases.isNotEmpty) await fBox.putAll(aliases);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('restoreFull failed: $e');
      return false;
    }
  }

  static Future<bool> _backupUserData({required String reason}) async {
    final snap = snapshotFull();
    snap.remove('franchises');
    snap.remove('aliases');
    final empty =
        (snap['watch_status'] as Map).isEmpty &&
        (snap['episode_progress'] as Map).isEmpty;
    if (empty) return false;

    final created = DateTime.now().millisecondsSinceEpoch;
    await _backups.put(
      'b$created',
      jsonEncode({
        'v': 1,
        'created': created,
        'reason': reason,
        'schemaVersion': readVersion(),
        ...snap,
      }),
    );

    final keys = _backups.keys.map((e) => e.toString()).toList()..sort();
    if (keys.length > _maxBackups) {
      await _backups.deleteAll(keys.take(keys.length - _maxBackups));
    }
    return true;
  }

  static int backupCount() => _backups.length;

  static Map<String, dynamic>? latestBackup() {
    if (_backups.isEmpty) return null;
    final keys = _backups.keys.map((e) => e.toString()).toList()..sort();
    try {
      return (jsonDecode(_backups.get(keys.last)!) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> restoreLatestBackup() async {
    final b = latestBackup();
    if (b == null) return false;

    Map<String, String> read(String key) {
      final raw = b[key];
      if (raw is! Map) throw FormatException(tr('backup_is_invalid'));
      return raw.map((k, v) {
        if (v is! String) throw FormatException(tr('backup_is_invalid'));
        return MapEntry(k.toString(), v);
      });
    }

    final ws = read('watch_status');
    final ep = read('episode_progress');

    await _backupUserData(reason: 'before_restore');

    final wsBox = Hive.box<String>(Boxes.watchStatus);
    final epBox = Hive.box<String>(Boxes.episodeProgress);
    await wsBox.clear();
    await wsBox.putAll(ws);
    await epBox.clear();
    await epBox.putAll(ep);
    return true;
  }
}

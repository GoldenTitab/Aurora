import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final conn = Connectivity();

  bool offlineOf(List<ConnectivityResult> r) =>
      r.every((e) => e == ConnectivityResult.none);

  try {
    yield offlineOf(await conn.checkConnectivity());
  } catch (_) {
    yield false;
  }

  try {
    await for (final r in conn.onConnectivityChanged) {
      yield offlineOf(r);
    }
  } catch (_) {}
});

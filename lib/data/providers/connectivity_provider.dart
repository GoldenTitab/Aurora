import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// آیا دستگاه آفلاین است؟ (true = هیچ اتصال شبکه‌ای نیست)
///
/// از connectivity_plus نسخه‌ی ۶ استفاده می‌کند که
/// `onConnectivityChanged` از نوع `Stream<List<ConnectivityResult>>` است.
/// روی هر خطایی fail-open است: آفلاین فرض نمی‌شود تا UI بی‌دلیل
/// حالت آفلاین نشان ندهد.
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
  } catch (_) {
    // آخرین وضعیت حفظ می‌شود؛ خطا یعنی آنلاین فرضی.
  }
});

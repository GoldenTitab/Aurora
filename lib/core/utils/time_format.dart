import 'persian_numbers.dart';
import '../../core/i18n/lang.dart';

String formatDurationFa(Duration d) {
  final totalMin = d.inMinutes;
  if (totalMin < 60) return tr('min', [toFa(totalMin)]);
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (m == 0) return tr('h', [toFa(h)]);
  return tr('h_m', [toFa(h), toFa(m)]);
}

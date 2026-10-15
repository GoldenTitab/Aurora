import 'persian_numbers.dart';

String formatDurationFa(Duration d) {
  final totalMin = d.inMinutes;
  if (totalMin < 60) return '${toFa(totalMin)} دقیقه';
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (m == 0) return '${toFa(h)} ساعت';
  return '${toFa(h)} ساعت و ${toFa(m)} دقیقه';
}

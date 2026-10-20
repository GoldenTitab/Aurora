import '../i18n/lang.dart';

String toFa(Object value) {
  final s = value.toString();
  if (Lang.isEn) return s;
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var out = s;
  for (var i = 0; i < en.length; i++) {
    out = out.replaceAll(en[i], fa[i]);
  }
  if (RegExp(r'^-?\d+\.\d+$').hasMatch(s)) {
    return out.replaceAll('.', '٫');
  }
  return out;
}

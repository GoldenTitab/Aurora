String toFa(Object value) {
  const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var s = value.toString();
  for (var i = 0; i < en.length; i++) {
    s = s.replaceAll(en[i], fa[i]);
  }
  return s.replaceAll('.', '٫');
}

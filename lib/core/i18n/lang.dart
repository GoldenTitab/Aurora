import 'strings.dart';

///
class Lang {
  static String current = 'fa';

  static bool get isFa => current == 'fa';
  static bool get isEn => current == 'en';
}

String tr(String key, [List<Object?> args = const []]) {
  String s;
  if (Lang.isEn) {
    s = kEn[key] ?? kFa[key] ?? key;
  } else {
    s = kFa[key] ?? kEn[key] ?? key;
  }
  if (args.isEmpty) {
    return s;
  }
  return s.replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) {
    final i = int.parse(m.group(1)!);
    if (i >= args.length) {
      return m.group(0)!;
    }
    return '${args[i]}';
  });
}

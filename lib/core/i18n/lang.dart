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
  for (var i = 0; i < args.length; i++) {
    s = s.replaceFirst('{$i}', '${args[i]}');
  }
  return s;
}

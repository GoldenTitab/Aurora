import 'strings.dart';

/// زبان فعلی اپ: 'fa' یا 'en'.
///
/// به‌صورت static نگه داشته می‌شود تا تابع [tr] بدون نیاز به ref در
/// همه‌جا (ویجت‌ها، مدل‌ها، سرویس‌ها) کار کند. مقدار آن همیشه با
/// [langProvider] همگام است؛ تغییر زبان کل اپ را از ریشه بازسازی می‌کند.
class Lang {
  static String current = 'fa';

  static bool get isFa => current == 'fa';
  static bool get isEn => current == 'en';
}

/// ترجمه شناسه‌ی [key] به زبان فعلی.
///
/// [key] یک شناسه‌ی پایدار انگلیسی است (مثلاً 'discover')، نه متن فارسی؛
/// پس ویرایش متن‌ها ترجمه را گم نمی‌کند. ترتیب جست‌وجو: مپ زبان فعلی،
/// بعد مپ زبان دیگر، و در نهایت خودِ [key].
/// [args] جایگزین `{0}`، `{1}`، ... در قالب می‌شود.
///
/// مثال:
/// ```dart
/// Text(tr('discover')),
/// Text(tr('xp_shafaq', [toFa(10), toFa(5)])),
/// ```
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

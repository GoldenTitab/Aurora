# Aurora — نسخه تکمیل‌شده

اپ مدیریت فرنچایز انیمه (AniList + MAL/Jikan)، فارسی و راست‌چین.

## اجرای پروژه
```bash
flutter pub get
flutter run
```

## باگ‌های برطرف‌شده
1. **جست‌وجوی سراسری (fallback):** جست‌وجو حالا AniList و Jikan و MAL را به‌صورت
   موازی می‌گردد، تکراری‌ها را با `malId/anilistId` حذف می‌کند و منبع هر نتیجه
   (AniList/MAL/Jikan) را با بج نشان می‌دهد. نتایج فقط-MAL با لمس، به AniList
   نگاشت می‌شوند (`/franchise/mal-XXX`) و اگر نگاشتی نبود، فرنچایز تک‌عضوی
   ساخته می‌شود.
2. **گروه‌بندی فرنچایز:** مجموعه روابط از ۵ حالت به ۱۲ حالت گسترش یافت
   (`PARENT/CHILD/COMPILATION/CONTAINS/CHARACTER/OTHER/...`)، روابط گمشده از
   MAL و Jikan خوانده و با `idMal` به AniList نگاشت می‌شوند، و عنوان‌های
   خیلی مشابه به داستان اصلی ارتقا می‌یابند. برای هر عضو، `parentEntryId` و
   `relationType` ثبت می‌شود تا درخت فرنچایز ساخته شود.
3. **نوار پیشرفت:** آثار «اعلام‌شده» (هنوز پخش‌نشده) دیگر در محاسبه پیشرفت
   فرنچایز شمرده نمی‌شوند (`progressOf` + `ReleaseState.excludedFromProgress`).

## ممیزی نهایی (۱٫۱٫۰)
1. **جایزه XP قسمت‌ها فقط یک بار:** تاگِل مکرر on/off/on، پاک کردن و علامت‌گذاری
   دوباره، یا ایمپورت مجدد، دیگر XP/سکه تکراری نمی‌دهد (`Economy.markEpisodesAwarded`
   با کلید `xpep:<entryId>`). امتیاز دادن به اثر هم فقط برای اولین امتیاز هر اثر
   جایزه می‌دهد؛ جایزه تکمیل فرنچایز و باز شدن اچیومنت‌ها در برابر فراخوانی
   هم‌زمان محافظت شدند.
2. **«تازه‌های نسخه» برای به‌روزرسانی‌ها:** کاربری که از نسخه‌های قبل از ۱٫۱٫۰
   به‌روز می‌کند (کلید `last_seen_version` ندارد) هم یک بار دیالوگ تازه‌ها را
   می‌بیند؛ در اولین نصب تمیز چیزی نمایش داده نمی‌شود.
3. **مسیرهای آنبوردینگ:** دکمه ایمپورت داخل آنبوردینگ (`/import`) و «پخش مجدد
   آموزش» در تنظیمات (`/onboarding`) دیگر توسط redirect به خانه برنمی‌گردند.
4. **اعلان‌ها:** اگر کاربر دسترسی اعلان را ندهد، بررسی روزانه فعال و زمان‌بندی
   نمی‌شود (قبلاً با وجود رد دسترسی، تسک ثبت می‌شد).
5. **تم روشن:** رنگ‌های `AppColors.*` آگاه از تم شدند (`surfaceOf`،
   `textSecondaryOf`، `primaryTextOf`، `starTextOf`، ...)؛ در تم تیره دقیقاً همان
   پالت قبلی است و در تم روشن معادل‌های خوانا از `colorScheme` استفاده می‌شود.
   متن امتیاز روی بج همیشه-تیره، سفید شد.
6. **ترتیب تماشای دستی:** باگ off-by-one در جابه‌جایی (به‌ویژه در حالت فیلتر
   «فقط ضروری‌ها») اصلاح شد؛ آیتم‌های مخفی سر جای خود می‌مانند. متن راهنمای
   دستگیره هم به «سمت چپ» (درست در RTL) اصلاح شد.
7. **دسترس‌پذیری:** چیپ قسمت‌ها ۴۸×۴۰، نقطه‌های انتخاب رنگ تم ۴۸×۴۸، tooltip روی
   همه IconButtonها، و تاچ‌تارگت بزرگ‌تر برای ستاره‌های امتیاز.
8. **کش API:** در صفحه «تنظیمات کش» ورودی‌های قدیمی‌تر از ۱۴ روز یا بیش از ۴۰۰
   ورودی به‌صورت خودکار هرس می‌شوند (`ApiGateway.pruneCache`).
9. **کد مرده:** `myListItemsProvider`/`MyListItem`، `watchOrderRevisionProvider`،
   `dumpExtras`/`restoreExtras` و `openCardCacheBox` حذف شدند؛ فرنچایزهای
   فقط-MAL در لیست من، برنامه تماشا و پیشنهادها با `franchiseRouteFor`
   به مسیر `/franchise/mal-XXX` می‌روند.

## ویژگی‌های اضافه‌شده
- **ادامه تماشا:** آخرین قسمت دیده‌شده هر اثر + زمان آخرین فعالیت ذخیره می‌شود؛
  سکشن افقی در بالای خانه.
- **تقویم پخش هفتگی:** از `nextAiringAt` آثار کتابخانه، گروه‌بندی بر اساس روز
  هفته (شروع از شنبه) با هایلایت امروز. مسیر: منوی خانه ← تقویم پخش هفتگی.
- **اعلان قسمت جدید:** بنر درون‌برنامه‌ای برای قسمت‌های پخش‌شده‌ی دیده‌نشده
  (قابل بستن، سکوت ۲۴ ساعته).
- **ترتیب تماشا:** حالا روی گراف واقعی روابط (والد/فرزند) + تاریخ انتشار کار
  می‌کند؛ ترتیب شخصی با drag & drop ذخیره می‌شود (از قبل بود، حالا دقیق‌تر).
- **آمار تماشا:** داشبورد شروع‌شده/تکمیل‌شده/متوقف‌شده/رهاشده/می‌خوام‌ببینم،
  زمان کل تماشا و باقی‌مانده (بر اساس مدت هر قسمت)، پرتماشاترین فرنچایزها.
- **پشتیبان‌گیری و انتقال:** خروجی کامل JSON (وضعیت‌ها، قسمت‌ها، یادداشت‌ها،
  امتیازها، ترتیب شخصی، تنظیمات تم، کش فرنچایزها) + بازیابی از کلیپ‌بورد.
  برای انتقال به گوشی دیگر کافی است.
- **تم روشن و رنگ اصلی:** تم روشن/تیره/سیستمی + انتخاب رنگ اصلی (۸ رنگ) در
  تنظیمات ← ظاهر.
- **نمایش درختی فرنچایز:** سوییچ‌ویو لیست / درختی / دسته‌بندی نوع
  (سریال‌ها، فیلم‌ها، OVA، ویژه) در صفحه فرنچایز.
- **یادداشت و امتیاز من:** یادداشت برای هر فرنچایز + امتیاز ۵ ستاره برای هر اثر.
- **تشخیص تکراری‌ها:** ادغام بر اساس `malId/anilistId` در ساخت فرنچایز و جست‌وجو.
- **کش محلی:** کش gateway برای همه هاست‌ها + کش ۶ ساعته جزئیات مدیا + کش
  فرنچایز (۳ روز) + کش سکشن‌های خانه.
- **پولیش:** skeleton هنگام لود، تصویر جایگزین پوستر، بج وضعیت انتشار
  (به‌زودی/در حال پخش)، نمایش «آخرین قسمت دیده‌شده».

## نکته‌ها
- برای `flutter analyze` به Flutter SDK نیاز است (در این محیط نصب نبود؛
  بررسی ساختاری/ارجاعی دستی انجام شد).
- موارد آینده (پیاده‌نشده): ویجت صفحه اصلی گوشی (نیاز به کد native)،
  گزارش PDF، حالت آفلاین کامل.

---

## اقتصاد بازی‌وار (جدید)

### لول‌ها (۵ لول، نام انگلیسی)
| لول | آستانه XP |
|---|---|
| Beginner | ۰ |
| Novice | ۵۰۰ |
| Intermediate | ۱۵۰۰ |
| Advanced | ۳۰۰۰ |
| Expert | ۵۰۰۰ |

### جایزه XP
- هر قسمت دیده‌شده: ۱۰
- امتیاز دادن: ۵
- نوشتن یادداشت: ۵
- تکمیل فرنچایز: ۵۰
- سر زدن روزانه: ۵

### سکه «شفق»
- هر قسمت دیده‌شده: ۵ شفق
- سر زدن روزانه: ۲۰ شفق
- تکمیل مأموریت: ۳۰ شفق

### کارت‌های کلکسیونی
- کمیابی‌ها: عادی، کمیاب، فوق کمیاب، حماسی، افسانه‌ای
- شانس: ۵۰٪ / ۲۶٪ / ۱۴٪ / ۷٪ / ۳٪
- هر بسته: ۳ کارت، قیمت ۱۰۰ شفق
- کارت تکراری به سکه تبدیل می‌شود: ۵ / ۱۰ / ۲۰ / ۴۰ / ۸۰
- استخر نامحدود از شخصیت‌های انیمه‌های کتابخانه (AniList)

### مأموریت‌ها
- روزانه (۳): ۳ قسمت ببین، به ۱ اثر امتیاز بده، وارد اپ شو
- هفتگی (۲): ۱۵ قسمت ببین، ۱ بسته کارت باز کن

### اچیومنت‌ها (~۱۰۰)
دسته‌ها: اولین‌ها، تماشا (مایل‌استون قسمت‌ها)، فرنچایز (شروع/تکمیل)، تنوع ژانر،
استریک، امتیازدهی، یادداشت، نمره فرنچایز، کارت (تعداد/کمیابی/بسته)، سکه،
مأموریت، لول، ساعت تماشا، ایمپورت، حضور روزانه، XP و ویژه.

## بخش‌های «کشف»
انیمه‌های ترند، ۱۰۰ انیمه برتر سریالی، ۱۰۰ انیمه برتر سینمایی،
۱۰ انیمه برتر هفته (با نمایش تغییر رتبه ↑↓ نسبت به هفته قبل)،
انیمه‌های آندرریتد، چارت فصلی (تب فصل جاری/فصل بعد).

## امکانات دیگر
- «اگه اینو دوست داشتی...»: پیشنهاد بر اساس فرنچایزهای با نمره ≥ ۸ یا تکمیل‌شده
- فیلتر پیشرفته: ژانر چندتایی + بازه امتیاز/سال/قسمت + نوع اثر + استودیو
- نمره ۱ تا ۱۰ برای هر فرنچایز (در خروجی JSON هم ذخیره می‌شود)
- ایمپورت لیست با یوزرنیم از AniList و MAL (از تنظیمات یا منوی خانه)
- استریک روزهای متوالی + هیت‌مپ ۲۶ هفته در صفحه آمار
- تب جدید «کشف» در ناوبری پایین + صفحه «جوایز» (سطح/کارت/مأموریت/اچیومنت)

## آماده‌سازی انتشار

### نسخه و «تازه‌های نسخه»
- نسخه‌ی نمایشی در دو جا نگه‌داری می‌شود و باید هم‌زمان بالا برود:
  `version` در `pubspec.yaml` و `kAppVersion` در
  `lib/core/constants/app_config.dart` (فعلاً `1.1.0`).
- بعد از هر به‌روزرسانی نسخه، در اولین اجرای اپ (پس از اتمام آنبوردینگ)
  دیالوگ «تازه‌های نسخه» یک بار نمایش داده می‌شود. وضعیت نمایش در کلید
  `last_seen_version` از باکس `app_meta` ذخیره می‌شود.
- متن تغییرات در `lib/features/settings/whats_new_screen.dart` هاردکد شده؛
  برای نسخه‌ی جدید، یک ورودی به `_changelog` اضافه کن (فقط قابلیت‌های واقعی).
- صفحه‌ی کامل «تازه‌های نسخه» از تنظیمات هم قابل دسترسی است.

### آنبوردینگ
- آموزش اولیه‌ی ۴ صفحه‌ای (`lib/features/onboarding/onboarding_screen.dart`)
  در اولین اجرا نمایش داده می‌شود؛ با اتمام یا «رد کردن»، کلید
  `onboarding_done` در باکس `app_meta` ثبت می‌شود.
- `GoRouter.redirect` در `app_router.dart` کاربر را تا قبل از اتمام آموزش
  به `/onboarding` می‌فرستد و برعکس.
- «پخش مجدد آموزش» از بخش «راهنما و اطلاعات» تنظیمات در دسترس است.

### اسپلش‌اسکرین
1. `flutter pub get`
2. `dart run flutter_native_splash:create`
3. خروجی را روی اندروید ۱۲+ و نسخه‌های قدیمی‌تر بررسی کن؛ رنگ پس‌زمینه
   `#0F0B1A` و تصویر `assets/icon/icon.png` است (تنظیمات در انتهای
   `pubspec.yaml` زیر کلید `flutter_native_splash`).

### آیکون
- آیکون از `assets/icon/icon.png` با `flutter_launcher_icons` ساخته می‌شود:
  `dart run flutter_launcher_icons`
- فایل `assets/icon/icon_foreground.png` نسخه‌ی پیش‌زمینه برای آیکون تطبیقی
  اندروید و اسپلش اندروید ۱۲ است.

### حریم خصوصی و انتشار در گوگل‌پلی
- متن سیاست حریم خصوصی داخل اپ هست (`lib/features/settings/privacy_screen.dart`،
  از تنظیمات: «حریم خصوصی»)؛ اپ local-first است: همه‌ی داده‌ها در Hive روی
  گوشی می‌ماند و اینترنت فقط برای APIهای عمومی AniList/Jikan/MAL استفاده می‌شود.
- **برای لیستینگ پلی‌استور باید همین سیاست در یک آدرس اینترنتی عمومی (URL)
  هم منتشر شود** و آن لینک در بخش «Privacy Policy» صفحه‌ی اپ در کنسول پلی
  ثبت شود. بدون URL عمومی، انتشار ممکن نیست.

### گزارش PDF مجموعه
از صفحه‌ی هر مجموعه می‌توانی با دکمه‌ی «گزارش PDF» یک گزارش کامل
(خلاصه، درخت روابط، ترتیب تماشا، وضعیت آثار و آمار) به‌صورت PDF بگیری و
به اشتراک بگذاری.
> نکته: فونت وزیرمتنِ گزارش در اولین خروجی PDF از اینترنت دانلود و بعد
> روی دستگاه کش می‌شود؛ پس اولین‌بار به اینترنت نیاز داری.

## مراحل نیتیو اندروید (اعلان‌ها و هوم‌ویجت)
# افزودنی نیتیو — اعلان‌ها، بررسی روزانه و هوم‌ویجت (Aurora)

> این فایل قدم‌های دستی سمت `android/` (و خلاصه‌ی `ios/`) را توضیح می‌دهد؛
> چون پوشه‌ی `android/` داخل زیپ پروژه نیست، این مراحل را روی پروژه‌ی
> واقعی خودت انجام بده. سمت Dart همه‌چیز آماده است
> (`lib/data/notifications/` و `lib/data/homewidget/`).
>
> در همه‌ی مثال‌ها به‌جای `com.example.aurora` شناسه‌ی واقعی اپ
> (`applicationId`) را بگذار.

## ۱. وابستگی‌های pubspec

به `dependencies` در `pubspec.yaml` اضافه کن و بعد `flutter pub get` بزن:

```yaml
dependencies:
  flutter_local_notifications: ^19.4.0
  workmanager: ^0.9.0
  home_widget: ^0.8.0
  path_provider: ^2.1.5
```

نکته‌ها:
- `timezone` را جدا اضافه **نکن**: مستقیم در کد Dart استفاده نشده و
  `flutter_local_notifications` خودش نسخه‌ی سازگارش را می‌آورد؛ پین جدا
  (`^0.10.1`) با `^19.4.0` تداخل نسخه می‌سازد و `flutter pub get` را
  خراب می‌کند.
- `path_provider` برای باز کردن Hive داخل ایزولیت پس‌زمینه‌ی workmanager
  لازم است (`getApplicationDocumentsDirectory`).
- آخرین نسخه‌ها (مهر ۱۴۰۵): `flutter_local_notifications 22.3.2` و
  `workmanager 0.10.10` و `home_widget 0.10.0` که هر سه Flutter ≥ 3.38
  می‌خواهند. اگر فلاترت قدیمی‌تر است، همین پین‌های بالا (پایدار و
  کمی قدیمی‌تر) را نگه دار.
- `minSdkVersion` را در `android/app/build.gradle(.kts)` حداقل **۲۳**
  بگذار (نیاز androidx.work که workmanager استفاده می‌کند). اگر الان ۲۱
  است، به ۲۳ ارتقا بده.

## ۲. AndroidManifest.xml

فایل: `android/app/src/main/AndroidManifest.xml`

### ۲.۱. فضای نام tools

به تگ `<manifest>` اضافه کن:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
```

### ۲.۲. دسترسی‌ها (داخل `<manifest>`، بیرون از `<application>`)

```xml
<!-- اعلان (اندروید ۱۳ به بالا؛ درخواست ران‌تایم را خود اپ می‌دهد) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<!-- لرزش اعلان -->
<uses-permission android:name="android.permission.VIBRATE" />
<!-- زمان‌بندی مجدد تسک‌ها بعد از ری‌بوت (برای workmanager) -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` لازم **نیست**؛ چون از
`zonedSchedule` دقیق استفاده نمی‌کنیم (زمان‌بندی با workmanager است).

### ۲.۳. غیرفعال‌سازی initializer پیش‌فرض androidx.startup (برای workmanager)

داخل `<application>`:

```xml
<!-- workmanager خودش WorkManager را مقداردهی می‌کند -->
<provider
    android:name="androidx.startup.InitializationProvider"
    android:authorities="${applicationId}.androidx-startup"
    android:exported="false"
    tools:node="remove" />
```

### ۲.۴. رسیورهای flutter_local_notifications (اختیاری)

فقط اگر بعداً خواستی از `zonedSchedule` / `periodicallyShow` استفاده کنی؛
برای `show()` فعلی لازم نیست:

```xml
<receiver
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

### ۲.۵. رسیور هوم‌ویجت (الزامی)

داخل `<application>`:

```xml
<receiver
    android:name=".AuroraWidgetProvider"
    android:exported="false"
    android:label="آرورا">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/aurora_widget_info" />
</receiver>
```

## ۳. هوم‌ویجت اندروید

### ۳.۱. `AuroraWidgetProvider.kt`

مسیر: `android/app/src/main/kotlin/com/example/aurora/AuroraWidgetProvider.kt`
(پکیج را با applicationId واقعی عوض کن):

```kotlin
package com.example.aurora

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class AuroraWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.aurora_widget)
            val prefs = HomeWidgetPlugin.getData(context)

            views.setTextViewText(
                R.id.widget_title,
                prefs.getString("cw_title", "ادامه تماشا"),
            )
            views.setTextViewText(
                R.id.widget_sub,
                prefs.getString("cw_sub", ""),
            )
            val today = prefs.getInt("airing_today", 0)
            views.setTextViewText(
                R.id.widget_airing,
                "پخش امروز: ${toFaDigits(today)}",
            )

            // تپ روی ویجت → باز شدن اپ
            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
            val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            val pendingIntent =
                PendingIntent.getActivity(context, 0, launchIntent, flags)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun toFaDigits(n: Int): String {
        val fa = charArrayOf('۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹')
        return n.toString().map { c ->
            if (c in '0'..'9') fa[c - '0'] else c
        }.joinToString("")
    }
}
```

کلیدها (`cw_title` ،`cw_sub` ،`airing_today`) دقیقاً همان‌هایی‌اند که سمت
Dart با `HomeWidget.saveWidgetData` ذخیره می‌شود
(`lib/data/homewidget/home_widget_service.dart`).

### ۳.۲. `res/xml/aurora_widget_info.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="0"
    android:initialLayout="@layout/aurora_widget"
    android:description="@string/app_widget_description"
    android:widgetCategory="home_screen" />
```

`updatePeriodMillis=0` چون به‌روزرسانی را خود اپ با
`HomeWidget.updateWidget` پوش می‌کند.

### ۳.۳. `res/layout/aurora_widget.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:layoutDirection="rtl"
    android:background="@drawable/widget_background"
    android:orientation="vertical"
    android:padding="14dp">

    <TextView
        android:id="@+id/widget_title"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:ellipsize="end"
        android:maxLines="1"
        android:text="ادامه تماشا"
        android:textColor="#FFFFFF"
        android:textSize="14sp"
        android:textStyle="bold" />

    <TextView
        android:id="@+id/widget_sub"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:ellipsize="end"
        android:maxLines="1"
        android:text=""
        android:textColor="#B9B3CC"
        android:textSize="12sp" />

    <TextView
        android:id="@+id/widget_airing"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:text="پخش امروز: ۰"
        android:textColor="#D6B4FE"
        android:textSize="12sp" />
</LinearLayout>
```

### ۳.۴. `res/drawable/widget_background.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <corners android:radius="20dp" />
    <solid android:color="#1E1533" />
    <stroke
        android:width="1dp"
        android:color="#3B2D5E" />
</shape>
```

### ۳.۵. رشته‌ی توضیح ویجت

به `res/values/strings.xml` اضافه کن:

```xml
<string name="app_widget_description">ادامه تماشا و پخش امروز انیمه‌ها</string>
```

## ۴. iOS (خلاصه)

1. در Xcode یک **Widget Extension** با نام `AuroraWidget` به پروژه اضافه کن.
2. برای اپ و اکستنشن، App Groups را با یک شناسه‌ی یکسان فعال کن، مثلاً
   `group.com.example.aurora`؛ سمت Dart (یک بار، قبل از اولین
   `saveWidgetData`، مثلاً در `main`) بگذار:
   ```dart
   await HomeWidget.setAppGroupId('group.com.example.aurora');
   ```
   (فقط iOS؛ با try/catch).
3. ویجت SwiftUI کلیدهای `cw_title` / `cw_sub` / `airing_today` را از
   `UserDefaults(suiteName: "group.com.example.aurora")` می‌خواند؛ تپ روی
   ویجت با `widgetURL(URL(string: "aurora://")!)` اپ را باز می‌کند
   (URL scheme «aurora» را در Info.plist اپ ثبت کن).
4. توجه: در iOS زمان اجرای تسک پس‌زمینه‌ی workmanager کاملاً با سیستم‌عامل
   است و ساعت انتخابی کاربر فقط «تقریبی» رعایت می‌شود.

## ۵. ترتیب انجام

1. وابستگی‌ها را به pubspec اضافه و `flutter pub get` بزن.
2. `minSdkVersion ≥ 23` را چک کن.
3. تغییرات `AndroidManifest.xml` (بخش ۲) را اعمال کن.
4. فایل‌های کاتلین و XML ویجت (بخش ۳) را بساز.
5. اپ را بیلد و نصب کن؛ ویجت «آرورا» باید در لیست ویجت‌های لانچر باشد.
6. در تنظیمات اپ، سوییچ «اعلان قسمت‌های جدید» را روشن و «ارسال اعلان
   آزمایشی» را بزن.

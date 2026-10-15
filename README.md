راهنمای اعمال فیکس اندروید — Aurora
=====================================

این زیپ را روی ریشه پروژه‌ات
(C:\Users\APPLE DOOR\Documents\My Projects\aurora)
اکسترکت کن؛ فایل‌های هم‌نام جایگزین می‌شوند:

  android/app/build.gradle.kts                                  (ویرایش شده)
  android/app/src/main/AndroidManifest.xml                       (ویرایش شده)
  android/app/src/main/kotlin/com/example/aurora/AuroraWidgetProvider.kt   (جدید)
  android/app/src/main/res/layout/aurora_widget_layout.xml       (جدید)
  android/app/src/main/res/drawable/widget_bg.xml                (جدید)
  android/app/src/main/res/xml/aurora_widget_info.xml            (جدید)

تغییرات:
1) minSdk ثابت شد روی ۲۳ — چون workmanager نسخه ۰.۹ به minSdk=23 نیاز دارد
   و همین باعث خطای manifest merger موقع بیلد می‌شد.
2) دسترسی‌های POST_NOTIFICATIONS و RECEIVE_BOOT_COMPLETED به مانیفست اضافه شد
   (لازم برای اعلان قسمت‌های جدید).
3) فایل‌های نیتیو هوم‌ویجت اضافه و در مانیفست ثبت شد. بعد از نصب، از لیست
   ویجت‌های گوشی «Aurora» را به صفحه اصلی اضافه کن.

بعد از اکسترکت:
  flutter clean
  flutter pub get
  flutter run

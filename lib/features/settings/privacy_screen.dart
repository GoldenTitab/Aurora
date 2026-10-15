import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// سیاست حریم خصوصی — اپ کاملاً local-first است.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'داده‌های تو، روی گوشی تو',
      'همه‌ی داده‌های آئورورا — لیست تماشا، وضعیت‌ها، قسمت‌های دیده‌شده، '
          'نمره‌ها، یادداشت‌ها، XP، سکه‌های «شفق»، کارت‌ها، مأموریت‌ها و '
          'اچیومنت‌ها — فقط داخل حافظه‌ی داخلی همین گوشی ذخیره می‌شود '
          '(پایگاه داده‌ی Hive). هیچ سروری از ما این داده‌ها را ندارد و '
          'بدون اقدام خودت، هیچ‌چیز از گوشی خارج نمی‌شود.',
    ),
    (
      'ارتباط با اینترنت فقط برای محتوای عمومی',
      'اپ برای گرفتن اطلاعات انیمه‌ها (عنوان، تصویر، قسمت‌ها، زمان پخش) به '
          'APIهای عمومی AniList، Jikan و MyAnimeList وصل می‌شود. این درخواست‌ها '
          'فقط شناسه‌ی انیمه را می‌فرستند؛ هیچ داده‌ی شخصی، لیست تماشا یا '
          'شناسه‌ی کاربری همراه آن‌ها ارسال نمی‌شود.',
    ),
    (
      'بدون حساب کاربری',
      'آئورورا حساب کاربری، ورود، ایمیل یا شماره تلفن نمی‌خواهد و هیچ '
          'پروفایل آنلاینی برایت نمی‌سازد. ایمپورت از AniList / MAL فقط با '
          'یوزرنیم عمومی انجام می‌شود و رمز عبوری از تو گرفته یا ذخیره نمی‌شود.',
    ),
    (
      'بدون تبلیغات و بدون ردیابی',
      'در اپ تبلیغات، ردیاب تبلیغاتی، تحلیل رفتار کاربر (آنالیتیکس) یا '
          'SDK شخص ثالث برای جمع‌آوری داده وجود ندارد.',
    ),
    (
      'پشتیبان‌گیری و حذف داده',
      'پشتیبان خودکار فقط داخل خود اپ نگه‌داری می‌شود. با «کپی خروجی دیتا '
          '(JSON)» در تنظیمات می‌توانی یک نسخه‌ی دستی بگیری و هر وقت خواستی '
          'با پاک کردن کش یا حذف نصب اپ، همه‌ی داده‌ها را از گوشی پاک کنی. '
          'با حذف اپ، تمام داده‌ها برای همیشه از بین می‌رود.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حریم خصوصی')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'آئورورا طوری ساخته شده که داده‌ات پیش خودت بماند.',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in _sections) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.$2,
                    style: TextStyle(
                      height: 1.9,
                      fontSize: 14,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            'نکته برای انتشار: برای انتشار در گوگل‌پلی، این سیاست باید در یک '
            'آدرس اینترنتی عمومی (URL) هم منتشر شود و همان لینک در صفحه‌ی '
            'اپ در پلی‌استور ثبت شود.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

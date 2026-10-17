import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ویجت یکپارچه‌ی نمایش کاور با کش هوشمند.
///
/// [cacheWidth] عرض نمایشی تصویر به پیکسل است؛ برای روان‌تر شدن اسکرول،
/// تصویر در همین اندازه دیکد می‌شود تا بافت‌های حجیمِ تمام‌رزولوشن وارد
/// حافظه‌ی GPU نشوند. مقدار پیش‌فرض برای کارت‌های معمولی کافی است؛
/// برای بندانگشتی‌های کوچک مقدار کمتری (مثلاً ۱۴۰–۱۶۰) بده.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth = 480,
  });

  final String? url;
  final BoxFit fit;
  final int cacheWidth;

  Widget _fallback(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [AppColors.surfaceHighOf(context), Color(0x598B5CF6)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.movie_creation_outlined,
        color: AppColors.textSecondaryOf(context),
        size: 28,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      // دیکد در اندازه‌ی نمایشی: مهم‌ترین عامل روان شدن اسکرول در
      // لیست‌های پرتصویر (جلوگیری از بافت‌های چندمگاپیکسلی روی GPU).
      memCacheWidth: cacheWidth,
      maxWidthDiskCache: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => _fallback(context),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }
}

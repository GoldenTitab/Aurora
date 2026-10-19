import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../data/providers/core_providers.dart';

class CoverImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final u = url;
    if (u == null || u.isEmpty) return _fallback(context);
    // حالت کم‌مصرف: نصف کیفیت
    final w = ref.watch(dataSaverProvider) ? (cacheWidth / 2).round() : cacheWidth;
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      memCacheWidth: w,
      maxWidthDiskCache: w,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => _fallback(context),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }
}

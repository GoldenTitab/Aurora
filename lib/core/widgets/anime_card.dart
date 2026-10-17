import 'package:flutter/material.dart';
import '../../data/models/anime_card_data.dart';
import '../theme/app_colors.dart';
import '../utils/persian_numbers.dart';
import '../utils/text_utils.dart';
import 'cover_image.dart';
import 'score_badge.dart';
import '../../core/i18n/lang.dart';

class AnimeCard extends StatelessWidget {
  const AnimeCard({super.key, required this.data, required this.onTap});

  final AnimeCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(url: data.cover, cacheWidth: 420),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ScoreBadge(score: data.score),
                  ),
                  if (data.source == SearchSource.mal ||
                      data.source == SearchSource.jikan)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        child: Text(
                          data.source.labelFa,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.titleFa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: dirFor(data.titleFa),
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.year == null ? '—' : toFa(data.year!),
                    style: t.bodySmall?.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimeCardSkeleton extends StatefulWidget {
  const AnimeCardSkeleton({super.key});

  @override
  State<AnimeCardSkeleton> createState() => _AnimeCardSkeletonState();
}

class _AnimeCardSkeletonState extends State<AnimeCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_c),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class AnimeCardError extends StatelessWidget {
  const AnimeCardError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOf(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onRetry,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondaryOf(context),
              ),
              SizedBox(height: 8),
              Text(
                tr('couldn_t_load_tap_to_retry'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

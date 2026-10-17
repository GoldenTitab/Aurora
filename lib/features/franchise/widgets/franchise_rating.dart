import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../data/providers.dart';
import '../../../core/i18n/lang.dart';

/// نمره کاربر به فرنچایز از ۱ تا ۱۰.
class FranchiseRating extends ConsumerWidget {
  const FranchiseRating({super.key, required this.franchiseId});

  final String franchiseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(franchiseRatingProvider(franchiseId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 18,
                color: AppColors.starTextOf(context),
              ),
              const SizedBox(width: 8),
               Text(
                tr('my_score_for_this_franchise'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              if (rating != null)
                Text(
                  toFa(rating),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.starTextOf(context),
                  ),
                ),
              if (rating != null)
                IconButton(
                  tooltip: tr('remove_score'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref
                      .read(franchiseRatingProvider(franchiseId).notifier)
                      .clear(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: (rating ?? 5).toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: toFa(rating ?? 5),
                  activeColor: AppColors.star,
                  inactiveColor: AppColors.surfaceHighOf(context),
                  onChanged: (v) => ref
                      .read(franchiseRatingProvider(franchiseId).notifier)
                      .setRating(v.round()),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                toFa(1),
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 11,
                ),
              ),
              Text(
                toFa(10),
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

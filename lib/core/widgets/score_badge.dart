import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/persian_numbers.dart';

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC0F0B1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            score <= 0 ? '—' : toFa(score.toStringAsFixed(1)),
            // چیپ همیشه تیره است؛ متن هم همیشه روشن تا در هر دو تم خوانا بماند.
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

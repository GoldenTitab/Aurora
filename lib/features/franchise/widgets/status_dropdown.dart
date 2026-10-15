import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/watch_status.dart';

class StatusDropdown extends StatelessWidget {
  const StatusDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final WatchStatus? value;
  final ValueChanged<WatchStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<WatchStatus?>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceHighOf(context),
          borderRadius: BorderRadius.circular(14),
          icon: Icon(
            Icons.expand_more_rounded,
            color: AppColors.textSecondaryOf(context),
          ),
          hint: Row(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: AppColors.textSecondaryOf(context),
              ),
              SizedBox(width: 8),
              Text(
                'ثبت وضعیت',
                style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 13),
              ),
            ],
          ),
          items: [
            for (final s in WatchStatus.values)
              DropdownMenuItem<WatchStatus?>(
                value: s,
                child: Row(
                  children: [
                    Icon(s.icon, size: 18, color: s.color),
                    const SizedBox(width: 8),
                    Text(
                      s.labelFa,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            DropdownMenuItem<WatchStatus?>(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'حذف از لیست',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

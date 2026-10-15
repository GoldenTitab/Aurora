import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum WatchStatus { watching, completed, planToWatch, onHold, dropped }

extension WatchStatusX on WatchStatus {
  String get labelFa {
    switch (this) {
      case WatchStatus.watching:
        return 'در حال تماشا';
      case WatchStatus.completed:
        return 'تماشا شده';
      case WatchStatus.planToWatch:
        return 'می‌خوام ببینم';
      case WatchStatus.onHold:
        return 'متوقف شده';
      case WatchStatus.dropped:
        return 'رها شده';
    }
  }

  IconData get icon {
    switch (this) {
      case WatchStatus.watching:
        return Icons.play_circle_outline_rounded;
      case WatchStatus.completed:
        return Icons.check_circle_outline_rounded;
      case WatchStatus.planToWatch:
        return Icons.bookmark_border_rounded;
      case WatchStatus.onHold:
        return Icons.pause_circle_outline_rounded;
      case WatchStatus.dropped:
        return Icons.cancel_outlined;
    }
  }

  Color get color {
    switch (this) {
      case WatchStatus.watching:
        return AppColors.watching;
      case WatchStatus.completed:
        return AppColors.completed;
      case WatchStatus.planToWatch:
        return AppColors.planToWatch;
      case WatchStatus.onHold:
        return AppColors.onHold;
      case WatchStatus.dropped:
        return AppColors.dropped;
    }
  }

  String get storageKey => name;

  static WatchStatus? fromKey(String? key) {
    if (key == null) return null;
    for (final s in WatchStatus.values) {
      if (s.name == key) return s;
    }
    return null;
  }
}

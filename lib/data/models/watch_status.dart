import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/i18n/lang.dart';

enum WatchStatus { watching, completed, planToWatch, onHold, dropped }

extension WatchStatusX on WatchStatus {
  String get labelFa {
    switch (this) {
      case WatchStatus.watching:
        return tr('watching');
      case WatchStatus.completed:
        return tr('watched');
      case WatchStatus.planToWatch:
        return tr('plan_to_watch');
      case WatchStatus.onHold:
        return tr('on_hold');
      case WatchStatus.dropped:
        return tr('dropped');
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

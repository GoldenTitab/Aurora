import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../data/providers.dart';
import '../../../core/i18n/lang.dart';

/// انتخاب امتیاز کاربر به یک اثر (۰ تا ۱۰) با پنج ستاره.
///
/// ضربه روی ستاره‌ی انتخاب‌شده یا نگه‌داشتن روی هر ستاره،
/// امتیاز را پاک می‌کند.
class UserScorePicker extends ConsumerStatefulWidget {
  const UserScorePicker({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<UserScorePicker> createState() => _UserScorePickerState();
}

class _UserScorePickerState extends ConsumerState<UserScorePicker> {
  double? _score;

  @override
  void initState() {
    super.initState();
    _score = ref.read(userExtrasProvider).scoreOf(widget.entryId);
  }

  double get _stars => (_score ?? 0) / 2;

  Future<void> _onTap(int index) async {
    final value = (index + 1) * 2.0;
    // جایزه XP فقط برای اولین امتیازی که به این اثر داده می‌شود
    // (تغییر مکرر امتیاز فارم XP نکند).
    final had = ref.read(userExtrasProvider).scoreOf(widget.entryId) != null;
    final next = _score == value ? null : value;
    await ref.read(userExtrasProvider).saveScore(widget.entryId, next);
    if (!mounted) return;
    setState(() => _score = next);
    if (next != null && !had) {
      ref.read(economyProvider.notifier).onRatingGiven();
    }
  }

  Future<void> _clear() async {
    await ref.read(userExtrasProvider).saveScore(widget.entryId, null);
    if (!mounted) return;
    setState(() => _score = null);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
         Text(
          tr('my_score'),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(width: 4),
        for (var i = 0; i < 5; i++)
          Tooltip(
            message: tr('out_of_10', [toFa((i + 1) * 2)]),
            child: InkWell(
              onTap: () => _onTap(i),
              onLongPress: _clear,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.star_rounded,
                  size: 26,
                  color: i < _stars ? AppColors.starTextOf(context) : AppColors.borderOf(context),
                ),
              ),
            ),
          ),
        if (_score != null) ...[
          const SizedBox(width: 6),
          Text(
            toFa(_score!.toStringAsFixed(1)),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.starTextOf(context),
            ),
          ),
        ],
      ],
    );
  }
}

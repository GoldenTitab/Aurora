import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_numbers.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/cover_image.dart';
import '../../../data/models/home_items.dart';
import '../../../data/providers.dart';

/// بنر یادآوری قسمت‌های جدید در بالای صفحه خانه.
class NewEpisodesBanner extends ConsumerStatefulWidget {
  const NewEpisodesBanner({super.key});

  @override
  ConsumerState<NewEpisodesBanner> createState() => _NewEpisodesBannerState();
}

class _NewEpisodesBannerState extends ConsumerState<NewEpisodesBanner> {
  static const int _dismissTtlMs = 24 * 3600 * 1000;
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(newEpisodesProvider);
    if (items.isEmpty || _dismissed) return const SizedBox.shrink();

    final dismissedAt = ref.watch(userExtrasProvider).dismissedNewEpisodesAt();
    final hidden =
        DateTime.now().millisecondsSinceEpoch - dismissedAt < _dismissTtlMs;
    if (hidden) return const SizedBox.shrink();

    final total = items.fold<int>(0, (s, i) => s + i.newCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.star.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.starTextOf(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${toFa(total)} قسمت جدید پخش شده',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => _showSheet(context, items),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTextOf(context),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'مشاهده',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'بستن',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(userExtrasProvider).dismissNewEpisodes();
                    setState(() => _dismissed = true);
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context, List<NewEpisodeItem> items) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'قسمت‌های جدید',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'بستن',
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.borderOf(context)),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: AppColors.borderOf(context)),
                  itemBuilder: (c, i) {
                    final item = items[i];
                    return InkWell(
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        context.push(
                          franchiseRouteFor(
                            item.franchiseAnilistId,
                            item.entryId,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 46,
                                height: 66,
                                child: CoverImage(url: item.cover),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.entryTitle,
                                    textDirection:
                                        dirFor(item.entryTitle),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.franchiseTitleFa,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textSecondaryOf(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'قسمت ${toFa(item.newCount)}',
                                    style: TextStyle(
                                      color: AppColors.primaryTextOf(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

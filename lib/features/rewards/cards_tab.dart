import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/section_title.dart';
import '../../data/gamification/card_pool.dart';
import '../../data/models/collectible_card.dart';
import '../../data/providers.dart';

/// تب «کارت‌ها»: باز کردن بسته و مشاهده کلکسیون.
class CardsTab extends ConsumerWidget {
  const CardsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);
    final eco = ref.watch(economyProvider);
    final total = cards.collection.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.style_rounded,
                    color: AppColors.primaryTextOf(context),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بسته کارت',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '۳ کارت تصادفی از شخصیت‌های انیمه‌های کتابخانه‌ات',
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: eco.coins < packPriceCoins
                          ? null
                          : () => context.push('/pack'),
                      icon: const Icon(Icons.card_giftcard_rounded),
                      label:
                          Text('باز کردن (${toFa(packPriceCoins)} شفق)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: cards.poolLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final n = await ref
                                .read(cardsProvider.notifier)
                                .rebuildPool(force: true);
                            if (context.mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    n > 0
                                        ? 'استخر با ${toFa(n)} شخصیت به‌روز شد.'
                                        : 'شخصیتی پیدا نشد؛ اول چند انیمه به لیستت اضافه کن.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: cards.poolLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('به‌روزرسانی'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${toFa(cards.poolSize)} شخصیت در استخر',
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle('کلکسیون من', count: toFa(total)),
        const SizedBox(height: 12),
        if (total == 0)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'هنوز کارتی نداری؛ یه بسته باز کن!',
                style: TextStyle(color: AppColors.textSecondaryOf(context)),
              ),
            ),
          )
        else
          for (final r in CardRarity.values)
            if (cards.collection[r]!.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: r.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${r.labelFa} (${toFa(cards.collection[r]!.length)})',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: r.color,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.72,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: cards.collection[r]!.length,
                itemBuilder: (context, i) =>
                    _CardTile(card: cards.collection[r]![i]),
              ),
              const SizedBox(height: 16),
            ],
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card});
  final CollectibleCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: card.rarity.color.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: CoverImage(url: card.image),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: dirFor(card.name),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        card.rarity.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    card.rarity.labelFa,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: card.rarity.color,
                    ),
                  ),
                ),
                if (card.count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '×${toFa(card.count)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

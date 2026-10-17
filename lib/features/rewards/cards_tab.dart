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
import '../../core/i18n/lang.dart';

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

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _PackHeader(cards: cards, ecoCoins: eco.coins),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: SectionTitle(tr('my_collection'), count: toFa(total)),
          ),
        ),
        if (total == 0)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text(
                  tr('no_cards_yet_open_a_pack'),
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                ),
              ),
            ),
          )
        else
          for (final r in CardRarity.values)
            if (cards.collection[r]!.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
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
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.72,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CardTile(card: cards.collection[r]![i]),
                    childCount: cards.collection[r]!.length,
                  ),
                ),
              ),
            ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _PackHeader extends ConsumerWidget {
  const _PackHeader({required this.cards, required this.ecoCoins});
  final CardsState cards;
  final int ecoCoins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
                    Text(
                      tr('card_pack'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      tr('3_random_character_cards_from_your_library_s_ani'),
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
                  onPressed: ecoCoins < packPriceCoins
                      ? null
                      : () => context.push('/pack'),
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: Text(tr('open_shafaq', [toFa(packPriceCoins)])),
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
                                    ? tr('pool_refreshed_with_characters', [
                                        toFa(n),
                                      ])
                                    : tr(
                                        'no_characters_found_add_a_few_anime_to_your_list',
                                      ),
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
                label: Text(tr('refresh')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('characters_in_the_pool', [toFa(cards.poolSize)]),
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 11,
            ),
          ),
          if (cards.poolBreakdown.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${tr('pool_mix')}: ${CardRarity.values.where((r) => (cards.poolBreakdown[r] ?? 0) > 0).map((r) => '${r.labelFa} ${toFa(cards.poolBreakdown[r]!)}').join(' · ')}',
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: cards.poolLoading
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ref.read(cardsProvider.notifier).clearPoolCache();
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(tr('pool_cache_cleared'))),
                        );
                      }
                    },
              icon: const Icon(Icons.cleaning_services_rounded, size: 16),
              label: Text(tr('clear_pool_cache')),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
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
              child: CoverImage(url: card.image, cacheWidth: 340),
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
                    color: card.rarity.color.withValues(alpha: 0.15),
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

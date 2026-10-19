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

class CardsTab extends ConsumerStatefulWidget {
  const CardsTab({super.key});

  @override
  ConsumerState<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends ConsumerState<CardsTab> {
  String _query = '';
  CardRarity? _rarity; // null = همه
  String _sort = 'rarest';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsProvider);
    final eco = ref.watch(economyProvider);
    final all = [
      for (final list in cards.collection.values) ...list,
    ];
    final total = all.fold<int>(0, (s, c) => s + c.count);

    final filtered = all.where((c) {
      if (_rarity != null && c.rarity != _rarity) return false;
      final q = _query.trim().toLowerCase();
      if (q.isNotEmpty && !c.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    switch (_sort) {
      case 'az':
        filtered.sort((a, b) => a.name.compareTo(b.name));
      case 'newest':
        final order = {
          for (var i = 0; i < cards.recentIds.length; i++)
            cards.recentIds[i]: i,
        };
        filtered.sort(
          (a, b) => (order[a.charId] ?? 9999).compareTo(order[b.charId] ?? 9999),
        );
      default:
        filtered.sort(
          (a, b) => b.rarity.index.compareTo(a.rarity.index),
        );
    }

    // تازه‌ها
    final byId = {for (final c in all) c.charId: c};
    final recent = [
      for (final id in cards.recentIds)
        if (byId[id] != null) byId[id]!,
    ].take(10).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _PackHeader(cards: cards, ecoCoins: eco.coins),
          ),
        ),
        if (recent.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(tr('new_cards'), count: toFa(recent.length)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recent.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) =>
                          _RecentCard(card: recent[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(tr('my_collection'), count: toFa(total)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: tr('search_collection'),
                    hintStyle: TextStyle(
                      color: AppColors.textSecondaryOf(context),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceOf(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.borderOf(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(tr('all')),
                          selected: _rarity == null,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() => _rarity = null),
                        ),
                      ),
                      for (final r in CardRarity.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(r.labelFa),
                            selected: _rarity == r,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => setState(() => _rarity = r),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${tr('sort_by')}:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: _sort,
                      underline: const SizedBox.shrink(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryTextOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text(tr('sort_newest')),
                        ),
                        DropdownMenuItem(
                          value: 'rarest',
                          child: Text(tr('sort_rarest')),
                        ),
                        DropdownMenuItem(
                          value: 'az',
                          child: Text(tr('sort_az')),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sort = v ?? 'rarest'),
                    ),
                    const Spacer(),
                    if (_rarity != null)
                      Text(
                        '${toFa(filtered.length)} / ${toFa(all.length)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Text(
                  total == 0
                      ? tr('no_cards_yet_open_a_pack')
                      : tr('no_cards_match'),
                  style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
          )
        else
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
                (context, i) => _CardTile(card: filtered[i]),
                childCount: filtered.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.card});
  final CollectibleCard card;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCardDetail(context, card),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: card.rarity.color.withValues(alpha: 0.7),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CoverImage(url: card.image, cacheWidth: 260),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: dirFor(card.name),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

void _showCardDetail(BuildContext context, CollectibleCard card) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CardDetailSheet(card: card),
  );
}

class _CardDetailSheet extends ConsumerWidget {
  const _CardDetailSheet({required this.card});
  final CollectibleCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(cardPoolProvider);
    final entry = pool.poolEntry(card.charId);
    final favs = (entry?['favourites'] as num?)?.toInt();
    final gender = entry?['gender'] as String?;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: card.rarity.color,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SizedBox(
                  width: 200,
                  height: 260,
                  child: CoverImage(url: card.image, cacheWidth: 480),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              card.name,
              textDirection: dirFor(card.name),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: card.rarity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                card.rarity.labelFa,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: card.rarity.color,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (favs != null)
              Text(
                tr('favourites_on_anilist', [toFa(favs)]),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            if (gender != null && gender.isNotEmpty)
              Text(
                gender,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            if (card.count > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '×${toFa(card.count)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTextOf(context),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('close')),
            ),
          ],
        ),
      ),
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
    return InkWell(
      onTap: () => _showCardDetail(context, card),
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
      ),
    );
  }
}

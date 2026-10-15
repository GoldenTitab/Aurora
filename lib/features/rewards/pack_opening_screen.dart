import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/text_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../data/gamification/card_pool.dart';
import '../../data/models/collectible_card.dart';
import '../../data/providers.dart';

/// صفحه باز کردن بسته کارت با نمایش مرحله‌ای.
class PackOpeningScreen extends ConsumerStatefulWidget {
  const PackOpeningScreen({super.key});

  @override
  ConsumerState<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends ConsumerState<PackOpeningScreen> {
  bool _opening = false;
  PackResult? _result;
  int _revealed = 0;
  String? _error;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
      _result = null;
      _revealed = 0;
    });
    final r = await ref.read(cardsProvider.notifier).openPack();
    if (!mounted) return;
    setState(() => _opening = false);
    if (r == null) {
      setState(() => _error = 'سکه کافی نیست یا استخر خالی است.');
      return;
    }
    setState(() => _result = r);
    for (var i = 1; i <= r.cards.length; i++) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _revealed = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eco = ref.watch(economyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('باز کردن بسته')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.starTextOf(context),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${toFa(eco.coins)} شفق داری',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.starTextOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_result == null) ...[
              const Spacer(),
              _PackArt(opening: _opening),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.dropped),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _opening || eco.coins < packPriceCoins ? null : _open,
                  icon: _opening
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.card_giftcard_rounded),
                  label: Text(
                    _opening
                        ? 'در حال باز کردن...'
                        : 'باز کردن بسته (${toFa(packPriceCoins)} شفق)',
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _result!.cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: i < _revealed
                            ? _RevealedCard(
                                card: _result!.cards[i],
                                duplicate: _result!.duplicates[i],
                              )
                            : const _HiddenCard(),
                      ),
                    ],
                  ],
                ),
              ),
              if (_revealed >= _result!.cards.length) ...[
                if (_result!.coinsFromDuplicates > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'کارت‌های تکراری به ${toFa(_result!.coinsFromDuplicates)} شفق تبدیل شدند',
                      style: TextStyle(
                        color: AppColors.starTextOf(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _opening || eco.coins < packPriceCoins ? null : _open,
                    icon: const Icon(Icons.refresh_rounded),
                    label:
                        Text('یه بسته دیگه (${toFa(packPriceCoins)} شفق)'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PackArt extends StatelessWidget {
  const _PackArt({required this.opening});
  final bool opening;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: opening ? 1 : 0),
      duration: const Duration(milliseconds: 600),
      builder: (context, v, _) => Transform.scale(
        scale: 1 + v * 0.08,
        child: Transform.rotate(
          angle: v * 0.1,
          child: Container(
            width: 150,
            height: 200,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFFF472B6)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.style_rounded,
                  size: 56,
                  color: Colors.white,
                ),
                SizedBox(height: 8),
                Text(
                  'بسته شفق',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '۳ کارت',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenCard extends StatelessWidget {
  const _HiddenCard();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.68,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHighOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Center(
          child: Text(
            '؟',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealedCard extends StatelessWidget {
  const _RevealedCard({required this.card, required this.duplicate});
  final CollectibleCard card;
  final bool duplicate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, v, _) => Transform.scale(
        scale: v,
        child: AspectRatio(
          aspectRatio: 0.68,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: card.rarity.color,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: card.rarity.color.withValues(alpha: 0.35),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: CoverImage(url: card.image),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Text(
                        card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: dirFor(card.name),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: card.rarity.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          card.rarity.labelFa,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: card.rarity.color,
                          ),
                        ),
                      ),
                      if (duplicate)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'تکراری → +${toFa(card.rarity.duplicateCoins)} شفق',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.starTextOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

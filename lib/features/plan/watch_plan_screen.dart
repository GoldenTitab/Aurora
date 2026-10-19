import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_numbers.dart';
import '../../core/utils/route_utils.dart';
import '../../core/utils/text_utils.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/cover_image.dart';
import '../../data/models/watch_plan.dart';
import '../../data/models/watch_status.dart';
import '../../data/providers.dart';
import '../../core/i18n/lang.dart';

class WatchPlanScreen extends ConsumerStatefulWidget {
  const WatchPlanScreen({super.key});

  @override
  ConsumerState<WatchPlanScreen> createState() => _WatchPlanScreenState();
}

class _WatchPlanScreenState extends ConsumerState<WatchPlanScreen> {
  int _minutes = 60;
  WatchPlan? _plan;
  Set<WatchStatus> _sources = const {WatchStatus.watching, WatchStatus.onHold};

  static const _presets = [30, 60, 120, 180, 240, 300, 360];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text(tr('watch_plan'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
           Text(
            tr('how_much_time_do_you_have'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _presets)
                ChoiceChip(
                  label: Text(_label(m)),
                  selected: _minutes == m,
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                tr('custom_time'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _minutes.toDouble().clamp(15, 480),
                  min: 15,
                  max: 480,
                  divisions: 31,
                  label: _label(_minutes),
                  onChanged: (v) => setState(() => _minutes = v.round()),
                ),
              ),
              Text(
                _label(_minutes),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr('plan_source'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(WatchStatus.watching.labelFa),
                selected: _sources.length == 1 &&
                    _sources.contains(WatchStatus.watching),
                onSelected: (_) => setState(
                  () => _sources = {WatchStatus.watching},
                ),
              ),
              ChoiceChip(
                label: Text(WatchStatus.onHold.labelFa),
                selected: _sources.length == 1 &&
                    _sources.contains(WatchStatus.onHold),
                onSelected: (_) => setState(
                  () => _sources = {WatchStatus.onHold},
                ),
              ),
              ChoiceChip(
                label: Text(tr('watching_and_onhold')),
                selected: _sources.length == 2,
                onSelected: (_) => setState(
                  () => _sources = {
                    WatchStatus.watching,
                    WatchStatus.onHold,
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _build,
            icon: const Icon(Icons.auto_awesome_rounded),
            label:  Text(tr('build')),
          ),
          const SizedBox(height: 20),
          if (_plan != null) _PlanCard(plan: _plan!),
        ],
      ),
    );
  }

  String _label(int m) {
    if (m < 60) return tr('min', [toFa(m)]);
    final h = m ~/ 60;
    final rem = m % 60;
    if (rem == 0) return tr('h', [toFa(h)]);
    return tr('h_m', [toFa(h), toFa(rem)]);
  }

  void _build() {
    final plan = ref
        .read(watchPlanServiceProvider)
        .buildPlan(minutesAvailable: _minutes, sources: _sources);
    setState(() => _plan = plan);
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final WatchPlan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          tr('no_plan_created_you_need_at_least_one_anime_with'),
          style: TextStyle(color: AppColors.textSecondaryOf(context), height: 1.7),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: AppColors.primaryTextOf(context),
                  ),
                  const SizedBox(width: 8),
                   Text(
                    tr('suggested_plan'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatDurationFa(plan.total),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTextOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tr('out_of_your', [formatDurationFa(plan.requested)]) +
                tr('scheduled', [formatDurationFa(plan.total)]),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < plan.items.length; i++)
          _PlanItemCard(index: i + 1, item: plan.items[i]),
      ],
    );
  }
}

class _PlanItemCard extends ConsumerWidget {
  const _PlanItemCard({required this.index, required this.item});
  final int index;
  final WatchPlanItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            franchiseRouteFor(
              item.franchise.anilistId,
              item.franchise.id,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    toFa(index),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppColors.primaryTextOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 40,
                    height: 56,
                    child: CoverImage(
                      url: item.entry.cover ?? item.franchise.cover,
                      cacheWidth: 140,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.franchise.titleFa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: dirFor(item.entry.title),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tr('episodes_4', [toFa(item.startEpisode), toFa(item.endEpisode)])} · ${formatDurationFa(item.estimatedDuration)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryTextOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _episodeChecklist(
              context,
              ref,
              ref.watch(episodeProgressProvider)[item.entry.id] ??
                  const <int>{},
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _episodeChecklist(
    BuildContext context,
    WidgetRef ref,
    Set<int> watched,
  ) {
    final total = item.entry.episodes > 0 ? item.entry.episodes : 24;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: AppColors.borderOf(context)),
          const SizedBox(height: 8),
          Text(
            tr('session_progress'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var ep = item.startEpisode; ep <= item.endEpisode; ep++)
                InkWell(
                  onTap: () => ref
                      .read(episodeProgressProvider.notifier)
                      .toggle(item.entry.id, ep, total),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: watched.contains(ep)
                          ? AppColors.completed.withValues(alpha: 0.2)
                          : AppColors.surfaceHighOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: watched.contains(ep)
                            ? AppColors.completed
                            : AppColors.borderOf(context),
                      ),
                    ),
                    child: watched.contains(ep)
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.completed,
                          )
                        : Text(
                            toFa(ep),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

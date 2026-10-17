import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/route_utils.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/state_views.dart';
import '../../data/providers.dart';
import '../../data/remote/api_exception.dart';
import '../../data/services/suggestion_engine.dart';
import '../../core/i18n/lang.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  Suggestion? _current;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ref.read(suggestionServiceProvider).pick();
      if (!mounted) return;
      setState(() {
        _current = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text(tr('pick_an_anime_for_me')),
        actions: [
          IconButton(
            tooltip: tr('clear_suggestion_history'),
            onPressed: () async {
              await ref.read(watchOrderStorageProvider).clearHistory();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(tr('suggestion_history_cleared'))),
              );
            },
            icon: const Icon(Icons.history_toggle_off_rounded),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return  LoadingView(message: tr('picking'));
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _pick);
    }
    final s = _current;
    if (s == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            tr('no_suggestion_found_to_get_one_you_need_to_be_on') +
            tr('and_there_must_be_an_anime_outside_your_list_in_'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondaryOf(context), height: 1.8),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 200,
                        height: 290,
                        child: CoverImage(url: s.data.cover, cacheWidth: 460),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.data.titleFa,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.data.titleEn,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Text(
                        s.reasonFa,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryTextOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.refresh_rounded),
                  label:  Text(tr('another_one')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    franchiseRouteFor(s.data.anilistId, s.historyId),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label:  Text(tr('go_to_page')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/section_title.dart';
import '../../data/providers.dart';

/// ایمپورت لیست انیمه با یوزرنیم از AniList یا MAL.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _useAnilist = true;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final username = _ctrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اول یوزرنیمت رو بنویس')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(importProvider.notifier).run(
          useAnilist: _useAnilist,
          username: username,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ایمپورت لیست')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SectionTitle('از کجا وارد کنم؟'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SourceCard(
                  selected: _useAnilist,
                  title: 'AniList',
                  subtitle: 'سریع و کامل',
                  icon: Icons.bolt_rounded,
                  onTap: () => setState(() => _useAnilist = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceCard(
                  selected: !_useAnilist,
                  title: 'MAL',
                  subtitle: 'از طریق Jikan',
                  icon: Icons.public_rounded,
                  onTap: () => setState(() => _useAnilist = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionTitle('یوزرنیم'),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: _useAnilist ? 'AniList username' : 'MyAnimeList username',
              hintStyle: TextStyle(color: AppColors.textSecondaryOf(context)),
              filled: true,
              fillColor: AppColors.surfaceOf(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.running ? null : _start,
              icon: state.running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(state.running ? 'در حال وارد کردن...' : 'شروع ایمپورت'),
            ),
          ),
          if (state.running) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.status,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (state.result != null && !state.running) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: state.result!.ok
                      ? AppColors.completed.withValues(alpha: 0.5)
                      : AppColors.dropped.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.result!.ok
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: state.result!.ok
                        ? AppColors.completed
                        : AppColors.dropped,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.result!.message,
                      style: const TextStyle(fontSize: 13, height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.read(importProvider.notifier).reset(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ایمپورت دوباره'),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '• لیست باید عمومی باشد.\n'
            '• وضعیت‌ها این‌طور نگاشت می‌شوند: در حال تماشا، تماشا شده، متوقف شده، رها شده، می‌خوام ببینم.\n'
            '• تعداد قسمت‌های دیده‌شده هم منتقل می‌شود.\n'
            '• برای جلوگیری از محدودیت API، حداکثر ۶۰ اثر (AniList) یا ۴۰ اثر (MAL) در هر ایمپورت وارد می‌شود.',
            style: TextStyle(
              color: AppColors.textSecondaryOf(context),
              fontSize: 12,
              height: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderOf(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? AppColors.primaryTextOf(context)
                  : AppColors.textSecondaryOf(context),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
              textDirection: TextDirection.ltr,
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

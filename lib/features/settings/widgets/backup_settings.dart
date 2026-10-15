import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/providers.dart';
import '../../../data/storage/data_export.dart';

/// بخش «پشتیبان‌گیری و انتقال» در تنظیمات.
class BackupSettings extends ConsumerWidget {
  const BackupSettings({super.key});

  Future<void> _copyFull(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: DataExport.buildFull()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کپی شد؛ در فایل متنی ذخیره‌اش کن'),
        ),
      );
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کلیپ‌بورد خالی است')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی؟'),
        content: const Text('دیتای فعلی جایگزین می‌شود...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('بازیابی'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await DataExport.importFull(text);
    if (result.ok) {
      ref.invalidate(watchStatusProvider);
      ref.invalidate(episodeProgressProvider);
      ref.invalidate(userExtrasProvider);
      ref.invalidate(economyProvider);
      ref.invalidate(missionsProvider);
      ref.invalidate(myListFranchisesProvider);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('پشتیبان‌گیری و انتقال'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _copyFull(context),
          icon: const Icon(Icons.copy_rounded),
          label: const Text('کپی خروجی کامل (JSON)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _restore(context, ref),
          icon: const Icon(Icons.paste_rounded),
          label: const Text('بازیابی از کلیپ‌بورد'),
        ),
        const SizedBox(height: 8),
        Text(
          'خروجی شامل وضعیت‌ها، یادداشت‌ها، امتیازها، ترتیب شخصی و کش فرنچایزهاست و برای انتقال به گوشی دیگر کافی است.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryOf(context),
            height: 1.8,
          ),
        ),
      ],
    );
  }
}

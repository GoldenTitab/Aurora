import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/storage/migrations.dart';
import '../settings/whats_new_screen.dart';

/// صفحه‌ی آموزش اولیه (۴ صفحه، راست‌چین).
/// با پایان یا رد شدن، کلید `onboarding_done` در باکس meta ذخیره می‌شود.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_PageData>[
    _PageData(
      icon: Icons.auto_awesome_rounded,
      title: 'به Aurora خوش آمدی',
      body:
          'آئورورا یک دنبال‌کننده‌ی انیمه است: وضعیت تماشایت را ثبت کن، '
          'قسمت‌های دیده‌شده را علامت بزن، به فرنچایزها نمره بده و یادداشت '
          'بنویس — همه‌چیز فارسی، راست‌چین و کاملاً آفلاین روی گوشی خودت.',
    ),
    _PageData(
      icon: Icons.account_tree_rounded,
      title: 'مفهوم فرنچایز',
      body:
          'هر انیمه معمولاً فقط یک فصل نیست. آئورورا فصل‌ها، فیلم‌های سینمایی، '
          'OVAها و اسپین‌آف‌های مرتبط را پیدا می‌کند و همه را زیر یک «فرنچایز» '
          'جمع می‌کند؛ مثل یک درخت که هر شاخه‌اش یک اثر است و پیشرفت کل مجموعه '
          'را یک‌جا می‌بینی.',
    ),
    _PageData(
      icon: Icons.download_rounded,
      title: 'لیستت را بیاور',
      body:
          'اگر قبلاً در AniList یا MyAnimeList لیست داری، با وارد کردن یوزرنیم '
          'می‌توانی همه‌اش را یک‌جا وارد آئورورا کنی. بعداً هم هر وقت خواستی '
          'از بخش تنظیمات در دسترس است.',
    ),
    _PageData(
      icon: Icons.emoji_events_rounded,
      title: 'بازی‌وار، مثل یک بازی',
      body:
          'با تماشا کردن XP می‌گیری و از سطح Beginner تا Expert بالا می‌روی؛ '
          'سکه‌ی «شفق» جمع می‌کنی و با آن بسته‌ی کارت‌های کلکسیونی شخصیت‌ها را '
          'باز می‌کنی؛ مأموریت‌های روزانه/هفتگی و حدود صد اچیومنت هم در انتظارت است.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await Hive.box<String>(Boxes.meta).put('onboarding_done', '1');
    if (!mounted) return;
    // برای کاربری که نسخه را به‌روز کرده، یک بار «تازه‌ها» را نشان بده.
    final showWhatsNew = await WhatsNew.consume();
    if (!mounted) return;
    if (showWhatsNew) {
      await showDialog<void>(
        context: context,
        builder: (_) => const WhatsNewDialog(),
      );
      if (!mounted) return;
    }
    context.go('/discover');
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _finish,
                child: const Text('رد کردن'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            // نقطه‌های راهنما
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.primary
                          : AppColors.textSecondaryOf(context).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? 'شروع!' : 'بعدی'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _PageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            style: TextStyle(
              fontSize: 15,
              height: 1.9,
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
          // صفحه‌ی ایمپورت: دکمه‌ی مستقیم به /import
          if (data.icon == Icons.download_rounded) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push('/import'),
              icon: const Icon(Icons.download_rounded),
              label: const Text('ایمپورت از AniList / MAL'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// OnboardingScreen — bola ilovasini birinchi marta ochganida 3 ta slayd
// ─────────────────────────────────────────────────────────────────────
//
// 3 ta slayd:
//   1) "Ota-onangiz bilan birga"  — pairing tushuntiruvi
//   2) "Joylashuv ulashasiz"      — nima uchun joylashuv
//   3) "SOS — yordam tugmasi"     — favqulodda yordam tugmasi
//
// Har slaydda: Faro maskot + sarlavha + 1 satr matn + page indicator
// (•••) + "Keyingi" tugma. Oxirgi slaydda "Boshlash" → /pairing.
//
// SharedPreferences `onboarding_seen_v1` bilan bir martalik —
// SplashScreen flag tekshiradi va qayta ko'rsatmaydi.

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:farzandim_child/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences kaliti — onboarding qayta ko'rsatilmasligi uchun.
/// `_v1` suffiksi: kelajakda slaydlar o'zgartirilsa `_v2` bilan
/// foydalanuvchilarga qayta ko'rsatish mumkin.
const String kOnboardingSeenKey = 'onboarding_seen_v1';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      title: 'Ota-onangiz bilan birga',
      body: 'Oilangiz sizning xavfsizligingizdan xabardor bo\'ladi.',
      variant: FaroVariant.body,
    ),
    _SlideData(
      title: 'Joylashuv ulashasiz',
      body: 'Joylashuvingiz faqat ota-onangizga ko\'rinadi.',
      variant: FaroVariant.body,
    ),
    _SlideData(
      title: 'SOS — yordam tugmasi',
      body: 'Yordam kerak bo\'lsa, oilangizga bir tugma bilan xabar bering.',
      variant: FaroVariant.body,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _onPrimary() async {
    if (!_isLast) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeenKey, true);
    if (!mounted) return;
    context.go('/pairing');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Yuqori o'ng burchakda "O'tkazib yuborish" — onboarding'ni
              // tezda yopish istasa (ayniqsa qayta o'rnatishda). Oxirgi
              // slaydda yashiramiz — u yer "Boshlash" tugmasi.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLast ? null : _finishOnboarding,
                  child: Text(
                    _isLast ? '' : "O'tkazib yuborish",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _SlideView(data: _slides[i]),
                ),
              ),

              // Page indicator (• • •) — joriy slayd kattaroq.
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            // ignore: deprecated_member_use
                            : AppColors.primary.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: PrimaryButton(
                  text: _isLast ? 'Boshlash' : 'Keyingi',
                  onPressed: _onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.body,
    required this.variant,
  });

  final String title;
  final String body;
  final FaroVariant variant;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          FaroMascot(variant: data.variant, size: 220)
              .animate(key: ValueKey(data.title))
              .fadeIn(duration: 500.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          )
              .animate(key: ValueKey('${data.title}-t'))
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .moveY(begin: 8, end: 0),
          const SizedBox(height: 12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          )
              .animate(key: ValueKey('${data.title}-b'))
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .moveY(begin: 8, end: 0),
          const Spacer(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// OnboardingScreen — bola ilovasini birinchi marta ochganida 4 ta slayd
// ─────────────────────────────────────────────────────────────────────
//
// 4 ta slayd:
//   1) "Ota-onangiz bilan birga"  — pairing tushuntiruvi
//   2) "Joylashuv ulashasiz"      — nima uchun joylashuv
//   3) "SOS — yordam tugmasi"     — favqulodda yordam tugmasi
//   4) "Sevimli mavzularingiz?"  — qiziqishlar (chip grid, kamida 1 ta)
//
// 1-3 slaydlarda: Faro maskot + sarlavha + 1 satr matn + page indicator
// + "Keyingi" tugma.
// 4-slaydda: sarlavha + 12 ta chip + page indicator + "Boshlash" tugma
// (kamida 1 ta tanlanmaguncha disable). Tanlangan tag'lar SharedPreferences
// `child_interests_pending_v1` ga yoziladi → pairing tugagach backend'ga
// PUT /children/me/interests bilan yuboriladi (InterestsSyncService).
//
// SharedPreferences `onboarding_seen_v1` bilan bir martalik —
// SplashScreen flag tekshiradi va qayta ko'rsatmaydi.

// ignore_for_file: public_member_api_docs

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
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

const int _totalSlides = 4; // 3 ta info + 1 ta qiziqishlar

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  /// 4-chi slaydda tanlangan qiziqishlar (ID'lar).
  final Set<String> _selectedInterests = {};

  static const _infoSlides = <_InfoSlideData>[
    _InfoSlideData(
      title: 'Ota-onangiz bilan birga',
      body: "Oilangiz sizning xavfsizligingizdan xabardor bo'ladi.",
      variant: FaroVariant.body,
    ),
    _InfoSlideData(
      title: 'Joylashuv ulashasiz',
      body: "Joylashuvingiz faqat ota-onangizga ko'rinadi.",
      variant: FaroVariant.body,
    ),
    _InfoSlideData(
      title: 'SOS — yordam tugmasi',
      body: "Yordam kerak bo'lsa, oilangizga bir tugma bilan xabar bering.",
      variant: FaroVariant.body,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _totalSlides - 1;
  bool get _isInterestsPage => _page == _totalSlides - 1;
  bool get _canFinish => _selectedInterests.isNotEmpty;

  Future<void> _onPrimary() async {
    if (!_isLast) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (!_canFinish) return; // tugma disable bo'lgan, lekin ehtiyot uchun
    await _finishOnboarding(saveInterests: true);
  }

  Future<void> _finishOnboarding({required bool saveInterests}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeenKey, true);
    if (saveInterests && _selectedInterests.isNotEmpty) {
      // Bola pair bo'lmagan — JWT yo'q. Pending'da saqlaymiz.
      // PairingNotifier pair tugagach InterestsSyncService chaqiradi.
      await prefs.setStringList(
        kPendingInterestsKey,
        _selectedInterests.toList(),
      );
    }
    if (!mounted) return;
    context.go('/pairing');
  }

  void _toggleInterest(String id) {
    setState(() {
      if (_selectedInterests.contains(id)) {
        _selectedInterests.remove(id);
      } else {
        _selectedInterests.add(id);
      }
    });
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
              // tezda yopish. Oxirgi slaydda (qiziqishlar) yashiramiz —
              // u yer "Boshlash" tugmasi va minimum 1 ta tag majburiy.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLast
                      ? null
                      : () => _finishOnboarding(saveInterests: false),
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
                  itemCount: _totalSlides,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    if (i < _infoSlides.length) {
                      return _InfoSlideView(data: _infoSlides[i]);
                    }
                    return _InterestsSlideView(
                      selected: _selectedInterests,
                      onToggle: _toggleInterest,
                    );
                  },
                ),
              ),

              // Page indicator (• • • •) — joriy slayd kattaroq.
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalSlides, (i) {
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
                  onPressed: (_isInterestsPage && !_canFinish)
                      ? null
                      : _onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Info slide (1-3) — Faro maskot + sarlavha + 1 satr
// ───────────────────────────────────────────────────────────────────

class _InfoSlideData {
  const _InfoSlideData({
    required this.title,
    required this.body,
    required this.variant,
  });

  final String title;
  final String body;
  final FaroVariant variant;
}

class _InfoSlideView extends StatelessWidget {
  const _InfoSlideView({required this.data});

  final _InfoSlideData data;

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

// ───────────────────────────────────────────────────────────────────
// Interests slide (4) — chip grid bilan tanlash
// ───────────────────────────────────────────────────────────────────

class _InterestsSlideView extends StatelessWidget {
  const _InterestsSlideView({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Kichik Faro yuqori — fokusni chip'larga qoldiramiz.
          Center(
            child: const FaroMascot(
              variant: FaroVariant.faceExcited,
              size: 96,
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sevimli mavzularingiz?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tanlovingizga qarab kitob, video va konkurs tavsiya qilamiz.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final opt in kInterestOptions)
                    _InterestChip(
                      option: opt,
                      selected: selected.contains(opt.id),
                      onTap: () => onToggle(opt.id),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final InterestOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : AppColors.bgSurface;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    final border =
        // ignore: deprecated_member_use
        selected ? AppColors.primary : AppColors.primary.withOpacity(0.18);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.5),
        boxShadow: selected
            ? [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: AppColors.primaryShadow.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(option.icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  option.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

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
// 1-3 slaydlarda: Faro maskot rangli halo doirasida + sarlavha + 1 satr
// matn + page indicator + "Keyingi" tugma.
// 4-slaydda: sarlavha + 12 ta chip + page indicator + "Boshlash" tugma
// (kamida 1 ta tanlanmaguncha disable). Tanlangan tag'lar SharedPreferences
// `child_interests_pending_v1` ga yoziladi → pairing tugagach backend'ga
// PUT /children/me/interests bilan yuboriladi (InterestsSyncService).
//
// SharedPreferences `onboarding_seen_v1` bilan bir martalik —
// SplashScreen flag tekshiradi va qayta ko'rsatmaydi.

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:farzandim_child/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      titleKey: 'onboarding.slide1.title',
      bodyKey: 'onboarding.slide1.body',
      tagKey: 'onboarding.slide1.tag',
      variant: FaroVariant.body,
      accent: Color(0xFF58CC02), // primary green halo
      icon: Icons.family_restroom_rounded,
    ),
    _InfoSlideData(
      titleKey: 'onboarding.slide2.title',
      bodyKey: 'onboarding.slide2.body',
      tagKey: 'onboarding.slide2.tag',
      variant: FaroVariant.body,
      accent: Color(0xFF2BB6FF), // sky blue halo
      icon: Icons.location_on_rounded,
    ),
    _InfoSlideData(
      titleKey: 'onboarding.slide3.title',
      bodyKey: 'onboarding.slide3.body',
      tagKey: 'onboarding.slide3.tag',
      variant: FaroVariant.body,
      accent: Color(0xFFFF5252), // SOS red halo
      icon: Icons.shield_rounded,
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
      HapticFeedback.lightImpact();
      await _controller.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (!_canFinish) return; // tugma disable bo'lgan, lekin ehtiyot uchun
    HapticFeedback.mediumImpact();
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
    HapticFeedback.selectionClick();
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
              // Yuqori bar — chap "Orqaga" (1-slaydda ko'rinmaydi),
              // o'ng "O'tkazib yuborish" (oxirgi slaydda yashirin).
              _TopBar(
                page: _page,
                totalSlides: _totalSlides,
                isLast: _isLast,
                onBack: () => _controller.previousPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                ),
                onSkip: () => _finishOnboarding(saveInterests: false),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _totalSlides,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _page = i);
                  },
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
                padding: const EdgeInsets.only(bottom: 20, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalSlides, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  Color(0xFF7BD33B),
                                ],
                              )
                            : null,
                        color: active
                            ? null
                            : AppColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: PrimaryButton(
                  text: _isLast
                      ? (_canFinish
                          ? 'onboarding.startWithCount'.tr(
                              namedArgs: {
                                'count': '${_selectedInterests.length}',
                              },
                            )
                          : 'onboarding.minSelect'.tr())
                      : 'onboarding.next'.tr(),
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
// Top bar — Back chevron (1-slaydda gone) + Skip (oxirgida gone)
// ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.totalSlides,
    required this.isLast,
    required this.onBack,
    required this.onSkip,
  });

  final int page;
  final int totalSlides;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: page == 0 ? 0 : 1,
            child: IconButton(
              onPressed: page == 0 ? null : onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          // "1 / 4" — kichkina hisoblagich (modern OE feel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${page + 1} / $totalSlides',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isLast ? 0 : 1,
            child: TextButton(
              onPressed: isLast ? null : onSkip,
              child: Text(
                'onboarding.skip'.tr(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Info slide (1-3) — rangli halo + maskot + sarlavha + 1 satr
// ───────────────────────────────────────────────────────────────────

class _InfoSlideData {
  const _InfoSlideData({
    required this.titleKey,
    required this.bodyKey,
    required this.tagKey,
    required this.variant,
    required this.accent,
    required this.icon,
  });

  final String titleKey;
  final String bodyKey;
  final String tagKey;
  final FaroVariant variant;

  /// Slaydga rang berish — orqa halo doirasi va pastdagi feature pill rangi.
  final Color accent;

  /// Pastdagi feature pill ichidagi ikonka.
  final IconData icon;
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
          const Spacer(flex: 2),
          // Rangli halo — slayd accent rangida 2 qatlam glow
          _MascotHalo(
            accent: data.accent,
            child: FaroMascot(variant: data.variant, size: 200),
          )
              .animate(key: ValueKey(data.titleKey))
              .fadeIn(duration: 480.ms)
              .scale(
                begin: const Offset(0.82, 0.82),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 36),
          // Kichik feature pill — accent rangida (rang akcent qiladi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon, size: 14, color: data.accent),
                const SizedBox(width: 6),
                Text(
                  data.tagKey.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: data.accent,
                  ),
                ),
              ],
            ),
          )
              .animate(key: ValueKey('${data.titleKey}-pill'))
              .fadeIn(duration: 360.ms, delay: 80.ms)
              .moveY(begin: 6, end: 0),
          const SizedBox(height: 16),
          Text(
            data.titleKey.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          )
              .animate(key: ValueKey('${data.titleKey}-t'))
              .fadeIn(duration: 420.ms, delay: 120.ms)
              .moveY(begin: 10, end: 0),
          const SizedBox(height: 12),
          Text(
            data.bodyKey.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          )
              .animate(key: ValueKey('${data.titleKey}-b'))
              .fadeIn(duration: 420.ms, delay: 220.ms)
              .moveY(begin: 10, end: 0),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

/// Faro maskot atrofiga rangli ikki qatlamli halo qo'shadi —
/// orqasidagi 2 ta soft radial glow + nozik border ring.
class _MascotHalo extends StatelessWidget {
  const _MascotHalo({required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tashqi soft glow
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.0),
                ],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          // Ichki soft disc
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
            ),
          ),
          // Nozik chegara
          Container(
            width: 232,
            height: 232,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
          ),
          child,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Kichik Faro yuqori — fokusni chip'larga qoldiramiz.
          Center(
            child: const FaroMascot(
              variant: FaroVariant.faceExcited,
              size: 92,
            )
                .animate()
                .fadeIn(duration: 380.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'onboarding.interests.title'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'onboarding.interests.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          // Tanlangan soni indikator
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: selected.isEmpty
                ? const SizedBox.shrink()
                : Center(
                    key: ValueKey(selected.length),
                    child: Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'onboarding.selectedCount'.tr(
                              namedArgs: {'count': '${selected.length}'},
                            ),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < kInterestOptions.length; i++)
                    _InterestChip(
                      option: kInterestOptions[i],
                      selected: selected.contains(kInterestOptions[i].id),
                      onTap: () => onToggle(kInterestOptions[i].id),
                    )
                        .animate(key: ValueKey('chip-$i'))
                        .fadeIn(
                          duration: 280.ms,
                          delay: (60 * i).ms,
                        )
                        .moveY(begin: 8, end: 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
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
    final border = selected
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.16);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.5),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primaryShadow.withValues(alpha: 0.32),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppColors.primary.withValues(alpha: 0.12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.primary.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    option.icon,
                    size: 14,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  option.label(),
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

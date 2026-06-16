// ─────────────────────────────────────────────────────────────────────
// OnboardingScreen — bola ilovasini birinchi marta ochganida bir ekran
// (Parvoz NIGHT/GLASS Premium redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Yagona ekran: "Sevimli mavzularingiz?" — bola qiziqishlarini tanlash.
// Eski 3 ta info slayd (pairing/joylashuv/SOS) olib tashlandi —
// pair tugagach bola dashboard'ga o'tib bormaydi, oldin shu yerda
// qiziqishlar tanlanadi va backend'ga jo'natiladi.
//
// Tanlangan tag'lar SharedPreferences `child_interests_pending_v1` ga
// yoziladi → pairing tugagach backend'ga PUT /children/me/interests
// bilan yuboriladi (InterestsSyncService).
//
// SharedPreferences `onboarding_seen_v1` bilan bir martalik —
// SplashScreen flag tekshiradi va qayta ko'rsatmaydi.
//
// LOGIKA SAQLANGAN — faqat ko'rinish night/glass (parvoz tokenlar +
// parvozGlassFlat). GradientBackground olib tashlandi.

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:farzandim_child/features/onboarding/data/interests_sync_service.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences kaliti — onboarding qayta ko'rsatilmasligi uchun.
const String kOnboardingSeenKey = 'onboarding_seen_v1';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final Set<String> _selectedInterests = {};

  bool get _canFinish => _selectedInterests.isNotEmpty;

  Future<void> _onPrimary() async {
    if (!_canFinish) return;
    HapticFeedback.mediumImpact();
    await _finishOnboarding(saveInterests: true);
  }

  Future<void> _onSkip() async {
    HapticFeedback.lightImpact();
    await _finishOnboarding(saveInterests: false);
  }

  Future<void> _finishOnboarding({required bool saveInterests}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeenKey, true);
    if (saveInterests && _selectedInterests.isNotEmpty) {
      await prefs.setStringList(
        kPendingInterestsKey,
        _selectedInterests.toList(),
      );
      // Onboarding endi pair tugagandan KEYIN ko'rsatiladi — CHILD JWT
      // mavjud. Shuning uchun qiziqishlarni darhol backend'ga yuboramiz
      // (pairing oxiridagi sync allaqachon o'tib ketgan). Xato bo'lsa
      // pending qoladi, keyingi restart/repair'da qayta urinadi.
      await ref.read(interestsSyncServiceProvider).syncPendingInterests();
    }
    if (!mounted) return;
    // /splash markaziy router: paired bo'lsa permission-setup yoki dashboard.
    context.go('/splash');
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
      backgroundColor: AppColors.parvozBg,
      body: SafeArea(
        child: Column(
          children: [
            // Yuqori o'ng — "O'tkazib yuborish"
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'onboarding.skip'.tr(),
                      style: const TextStyle(
                        color: AppColors.parvozTextDim,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Parvoz logo — glass card + aqua glow
            const _LogoHero()
                .animate()
                .fadeIn(duration: 480.ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'onboarding.interests.title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.parvozText,
                  letterSpacing: -0.4,
                  height: 1.2,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 420.ms, delay: 120.ms)
                .moveY(begin: 10, end: 0),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                'onboarding.interests.subtitle'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.parvozTextDim,
                  height: 1.45,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 420.ms, delay: 200.ms)
                .moveY(begin: 10, end: 0),

            const SizedBox(height: 12),

            _SelectedCounter(count: _selectedInterests.length),

            const SizedBox(height: 8),

            // Chip grid
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < kInterestOptions.length; i++)
                      _InterestChip(
                        option: kInterestOptions[i],
                        selected: _selectedInterests
                            .contains(kInterestOptions[i].id),
                        onTap: () =>
                            _toggleInterest(kInterestOptions[i].id),
                      )
                          .animate()
                          .fadeIn(
                            duration: 320.ms,
                            delay: (40 * i + 220).ms,
                          )
                          .moveY(begin: 10, end: 0),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canFinish ? _onPrimary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.parvozGreen,
                    foregroundColor: AppColors.parvozOnGreen,
                    disabledBackgroundColor: AppColors.parvozSurfaceHigh,
                    disabledForegroundColor: AppColors.parvozTextDim,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _canFinish
                        ? 'onboarding.startWithCount'.tr(
                            namedArgs: {
                              'count': '${_selectedInterests.length}',
                            },
                          )
                        : 'onboarding.minSelect'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Logo hero — Parvoz logo glass card + aqua glow
// ───────────────────────────────────────────────────────────────────

class _LogoHero extends StatelessWidget {
  const _LogoHero();

  @override
  Widget build(BuildContext context) {
    const cardSize = 132.0;
    return Container(
      width: cardSize,
      height: cardSize,
      decoration: parvozGlass(radius: 32).copyWith(
        boxShadow: [
          BoxShadow(
            color: AppColors.parvozGreen.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          const BoxShadow(
            color: Color(0x59000000),
            blurRadius: 22,
            offset: Offset(0, 10),
            spreadRadius: -2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/icons/child_app_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.parvozGreen,
              alignment: Alignment.center,
              child: const Text(
                'P',
                style: TextStyle(
                  color: AppColors.parvozOnGreen,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Tanlangan soni indikator (animatsiyali pill)
// ───────────────────────────────────────────────────────────────────

class _SelectedCounter extends StatelessWidget {
  const _SelectedCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: count == 0
          ? const SizedBox.shrink()
          : Center(
              key: ValueKey(count),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.parvozGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.parvozGreen.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.parvozGreen,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'onboarding.selectedCount'.tr(
                        namedArgs: {'count': '$count'},
                      ),
                      style: const TextStyle(
                        color: AppColors.parvozGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
// Chip — qiziqish tanlash. Tanlanganda kenglik o'zgarmaydi (layout shift'siz).
// ───────────────────────────────────────────────────────────────────

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
    // Tanlanganda matn va ikon rangi o'zgarmaydi, kenglik konstant
    // (Wrap'da layout shift bo'lmasligi uchun).
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: selected
          ? parvozGlassFlat(radius: 999).copyWith(
              border: Border.all(color: AppColors.parvozGreen, width: 1.5),
            )
          : parvozGlassFlat(radius: 999),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppColors.parvozGreen.withValues(alpha: 0.12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon — har qiziqishning o'z accent rangida (zamonaviy).
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.accent.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    option.icon,
                    size: 20,
                    color: option.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  option.label(),
                  style: const TextStyle(
                    color: AppColors.parvozText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Check belgi har doim joy egallaydi — selected=opacity 1.
                const SizedBox(width: 6),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1 : 0,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.parvozGreen,
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

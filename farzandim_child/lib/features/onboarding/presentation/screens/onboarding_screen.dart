// ─────────────────────────────────────────────────────────────────────
// OnboardingScreen — "Sevimli mavzularingiz" (bola qiziqishlarini tanlash)
// (Parvoz dizayni — ko'k shisha, ota-ona onboarding uslubida)
// ─────────────────────────────────────────────────────────────────────
//
// Sarlavha + izoh (chapga) + 2 ustunli chip grid (tanlangani ko'k, aks holda
// shisha) + "Kirish" tugma. Tanlangan tag'lar SharedPreferences
// `child_interests_pending_v1` ga yoziladi → pairing tugagach backend'ga
// PUT /children/me/interests (InterestsSyncService).
//
// SharedPreferences `onboarding_seen_v1` bilan bir martalik — SplashScreen
// flag tekshiradi va qayta ko'rsatmaydi.

// ignore_for_file: public_member_api_docs

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/onboarding/data/interest_options.dart';
import 'package:farzandim_child/features/onboarding/data/interests_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences kaliti — onboarding qayta ko'rsatilmasligi uchun.
const String kOnboardingSeenKey = 'onboarding_seen_v1';

// ════════════ Parvoz tokenlar (lokal, ko'k) ════════════
const _bg = Color(0xFF02060D);
const _blue = Color(0xFF216BFF);
const _blueLight = Color(0xFF3C82FF);
const _dim = Color(0x99FFFFFF);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final Set<String> _selectedInterests = {};

  Future<void> _onEnter() async {
    HapticFeedback.mediumImpact();
    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeenKey, true);
    if (_selectedInterests.isNotEmpty) {
      await prefs.setStringList(
        kPendingInterestsKey,
        _selectedInterests.toList(),
      );
      // Pair tugagan bo'lsa (CHILD JWT bor) — darhol backend'ga yuboramiz.
      // Xato bo'lsa pending qoladi, keyingi restart/repair'da qayta urinadi.
      await ref.read(interestsSyncServiceProvider).syncPendingInterests();
    }
    if (!mounted) return;
    // /splash markaziy router: paired bo'lsa permission-setup yoki dashboard,
    // aks holda pairing.
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
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned(
            top: -160,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: _TopGlow())),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'onboarding.interests.title'.tr(),
                    style: GoogleFonts.unbounded(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'onboarding.interests.subtitle'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.45,
                      color: _dim,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        const cols = 2;
                        const crossGap = 12.0;
                        const pillH = 56.0;
                        final rows = (kInterestOptions.length / cols).ceil();
                        final pillW = (c.maxWidth - crossGap) / cols;
                        // Qatorlarni mavjud balandlikka taqsimlaymiz — dizayndagidek
                        // ixcham kataklar bo'shliqni to'ldiradi (ortiqcha bo'sh joy yo'q).
                        final free = c.maxHeight - rows * pillH;
                        final mainGap = (free / (rows - 1)).clamp(14.0, 30.0);
                        return GridView.count(
                          crossAxisCount: cols,
                          childAspectRatio: pillW / pillH,
                          crossAxisSpacing: crossGap,
                          mainAxisSpacing: mainGap,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            for (final o in kInterestOptions)
                              _InterestChip(
                                option: o,
                                selected: _selectedInterests.contains(o.id),
                                onTap: () => _toggleInterest(o.id),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: _PrimaryButton(
                    label: 'onboarding.enter'.tr(),
                    onTap: _onEnter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Qiziqish chip (2 ustunli grid) ════════════
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: selected ? _bluePill() : _glassPill(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(option.icon, size: 22, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ "Kirish" tugma (ko'k, o'ng strelka) ════════════
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 58,
        decoration: _bluePill(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════ Yumshoq ko'k yog'du ════════════
class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x59508AFF), Color(0x00508AFF)],
          stops: [0, 0.72],
        ),
      ),
    );
  }
}

// ════════════ Shisha dekoratsiyalar ════════════
BoxDecoration _glassPill() => BoxDecoration(
  borderRadius: BorderRadius.circular(999),
  gradient: const LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
  ),
  border: Border.all(color: const Color(0x1FFFFFFF), width: 1.2),
);

BoxDecoration _bluePill() => BoxDecoration(
  borderRadius: BorderRadius.circular(999),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_blueLight, _blue],
  ),
  border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
  boxShadow: [
    BoxShadow(
      color: _blue.withValues(alpha: 0.4),
      blurRadius: 24,
      spreadRadius: -2,
      offset: const Offset(0, 10),
    ),
  ],
);

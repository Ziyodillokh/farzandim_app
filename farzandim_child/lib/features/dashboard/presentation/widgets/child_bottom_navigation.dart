// ─────────────────────────────────────────────────────────────────────
// ChildBottomNavigation — suzuvchi pill nav (Figma "Main" 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Tab'lar (chap→o'ng):
//   🏠 Asosiy        — /dashboard
//   ▶️ Videolar      — /videos
//   📝 Testlar       — /contests
//   📖 Audiokitoblar — /audiobooks
//   👤 Profil        — /profile (bolaning HAQIQIY avatari)
//
// Ikonlar — Solar to'plami (dizayn spetsifikatsiyasi bo'yicha):
//   Asosiy: Bold/Home Smile · Videolar: Linear/Play ·
//   Testlar: Linear/Checklist Minimalistic · Audiokitoblar: Linear/Notebook
//   Minimalistic · Profil: bolaning haqiqiy avatari.
// Faol tab yumaloq-kvadrat yorug' fon + ko'k glow ichida.

import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/mini_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

const _blue = Color(0xFF216BFF);
const _navBar = Color(0xE61A1F23); // #1A1F23 @ 90%
const _navBorder = Color(0xFF313639);
const _inactive = Color(0xFFA6A8A9);
const _activeIcon = Color(0xFFF9F9F9);

class ChildBottomNavigation extends ConsumerWidget {
  const ChildBottomNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kEnableContentLibrary) {
      return const SizedBox.shrink();
    }

    final location = GoRouterState.of(context).matchedLocation;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    void go(String path) {
      if (location != path) {
        if (path == '/dashboard') {
          context.go(path);
        } else {
          context.push(path);
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniAudioPlayer(),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 12 + bottomInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: _navBar,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _navBorder),
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: SolarIconsBold.homeSmile,
                      label: 'nav.home'.tr(),
                      active: location == '/dashboard',
                      onTap: () => go('/dashboard'),
                    ),
                    _NavItem(
                      icon: SolarIconsOutline.play,
                      label: 'nav.videos'.tr(),
                      active:
                          location == '/videos' || location == '/video-player',
                      onTap: () => go('/videos'),
                    ),
                    _NavItem(
                      icon: SolarIconsOutline.checklistMinimalistic,
                      label: 'nav.quizzes'.tr(),
                      active: location == '/contests',
                      onTap: () => go('/contests'),
                    ),
                    _NavItem(
                      icon: SolarIconsOutline.notebookMinimalistic,
                      label: 'nav.audiobooks'.tr(),
                      active:
                          location == '/audiobooks' ||
                          location == '/audio-player',
                      onTap: () => go('/audiobooks'),
                    ),
                    _ProfileNavItem(
                      active: location == '/profile',
                      onTap: () => go('/profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Faol tab foni — yumaloq-kvadrat (squircle) + ko'k glow (Figma).
class _ActiveHalo extends StatelessWidget {
  const _ActiveHalo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = active ? _activeIcon : _inactive;
    final Widget iconWidget = Icon(icon, size: 24, color: tint);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!active) HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 34,
                child: Center(
                  child: active ? _ActiveHalo(child: iconWidget) : iconWidget,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? Colors.white : _inactive,
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

/// Profil tab — bolaning HAQIQIY avatari (dumaloq); rasm bo'lmasa person.
class _ProfileNavItem extends ConsumerWidget {
  const _ProfileNavItem({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(pairingStateProvider).childId;
    final avatarUrl = childId == null
        ? null
        : ref.watch(childAvatarUrlProvider(childId)).valueOrNull;

    final Widget face = avatarUrl != null
        ? ClipOval(
            child: Image.network(
              avatarUrl,
              width: 26,
              height: 26,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _PersonFallback(),
            ),
          )
        : const _PersonFallback();

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!active) HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 34,
                child: Center(child: active ? _ActiveHalo(child: face) : face),
              ),
              const SizedBox(height: 3),
              Text(
                'nav.profile'.tr(),
                maxLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : _inactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonFallback extends StatelessWidget {
  const _PersonFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person_outline_rounded, size: 24, color: _inactive);
  }
}

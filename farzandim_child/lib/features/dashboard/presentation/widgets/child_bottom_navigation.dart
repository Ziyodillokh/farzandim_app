// ─────────────────────────────────────────────────────────────────────
// ChildBottomNavigation — suzuvchi pill nav (Figma "Main" 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Tab'lar (chap→o'ng):
//   🏠 Asosiy        — /dashboard
//   ▶️ Videolar      — /videos
//   📝 Testlar       — /contests
//   📖 Audiokitoblar — /audiobooks
//   👤 Profil        — /profile
//
// Bar: frosted #1A1F23@90% + blur, radius 24, chegara #313639, inset 20.
// Faol tab: OQ ikon + ko'k (#216BFF) glow ortida; nofaol: #A6A8A9.
// MiniAudioPlayer pill ustida suzadi (audio o'ynayotganda).

import 'dart:ui' show ImageFilter;

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/shared/widgets/mini_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
          // Suzuvchi: yon 14, pastdan 12 + safe-area (home indikator).
          // "Audiokitoblar" label tor telefonlarda ham to'liq sig'ishi uchun
          // inset/padding qisqartirilgan.
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
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Asosiy',
                      active: location == '/dashboard',
                      onTap: () => go('/dashboard'),
                    ),
                    _NavItem(
                      icon: Icons.play_circle_outline_rounded,
                      activeIcon: Icons.play_circle_rounded,
                      label: 'Videolar',
                      active:
                          location == '/videos' || location == '/video-player',
                      onTap: () => go('/videos'),
                    ),
                    _NavItem(
                      icon: Icons.fact_check_outlined,
                      activeIcon: Icons.fact_check_rounded,
                      label: 'Testlar',
                      active: location == '/contests',
                      onTap: () => go('/contests'),
                    ),
                    _NavItem(
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book_rounded,
                      label: 'Audiokitoblar',
                      active:
                          location == '/audiobooks' ||
                          location == '/audio-player',
                      onTap: () => go('/audiobooks'),
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profil',
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!active) HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Faol tab ortida ko'k glow.
                    if (active)
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _blue.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    Icon(
                      active ? (activeIcon ?? icon) : icon,
                      color: active ? _activeIcon : _inactive,
                      size: 24,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // FittedBox — tor telefonlarda "Audiokitoblar" kesilmasdan
              // ozgina kichrayadi (ellipsis o'rniga).
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

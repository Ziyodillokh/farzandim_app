// ─────────────────────────────────────────────────────────────────────
// ChildBottomNavigation — suzuvchi pill nav (Figma: Asosiy dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Tab'lar (chap→o'ng, Figma bilan 1:1):
//   🏠 Asosiy        — /dashboard
//   ▶️ Videolar      — /videos
//   📝 Testlar       — /contests
//   📖 Audiokitoblar — /audiobooks
//   👤 Profil        — /profile
//
// Faol element — KO'K ikon + label; nofaol — xira. MiniAudioPlayer pill
// ustida suzadi (audio o'ynayotganda).

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/shared/widgets/mini_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const _blue = Color(0xFF216BFF);
const _surface = Color(0xFF10161F);
const _border = Color(0x1FFFFFFF);
const _inactive = Color(0x8CFFFFFF);

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
          // Suzuvchi: yon 14, pastdan 10 + safe-area (home indikator).
          padding: EdgeInsets.fromLTRB(14, 0, 14, 10 + bottomInset),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
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
                  active: location == '/videos' || location == '/video-player',
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
                      location == '/audiobooks' || location == '/audio-player',
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
    final color = active ? _blue : _inactive;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!active) HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: active
              ? BoxDecoration(
                  color: _blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? (activeIcon ?? icon) : icon, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

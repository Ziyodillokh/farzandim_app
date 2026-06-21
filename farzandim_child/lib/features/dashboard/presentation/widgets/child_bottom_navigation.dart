// ─────────────────────────────────────────────────────────────────────
// ChildBottomNavigation — floating pill nav (Parvoz UI Redesign — Night)
// ─────────────────────────────────────────────────────────────────────
//
// Google Stitch "Parvoz UI Redesign" dizayniga moslangan SUZUVCHI pill
// navigatsiya: yon va pastdan bo'shliq, to'liq yumaloq (rounded-full),
// navy surface + nozik chegara + yumshoq soya. Faol element — KO'K
// (#2170E4) doira ichida oq to'ldirilgan ikon (Stitch active state).
//
// Tab'lar (chap→o'ng):
//   🏠 home          — /dashboard   (Bosh sahifa)
//   📚 video_library — /content     (Kutubxona — videolar + audiokitoblar)
//   ✈️ send          — /voice-chat  (Suhbat)
//   🏆 leaderboard   — /contests    (Reyting / Konkurslar)
//   👤 person        — /profile     (Profil)
//
// MiniAudioPlayer pill ustida suzadi (audio o'ynayotganda). Faqat NIGHT —
// ranglar AppColors.parvoz* (light mode keyin alohida).

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/shared/widgets/mini_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          // Suzuvchi: yon 20, pastdan 12 + safe-area (home indikator).
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottomInset),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.parvozSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.parvozBorderStrong),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  active: location == '/dashboard',
                  onTap: () => go('/dashboard'),
                ),
                _NavItem(
                  icon: Icons.video_library_outlined,
                  activeIcon: Icons.video_library_rounded,
                  active: location == '/content' ||
                      location == '/videos' ||
                      location == '/audiobooks' ||
                      location == '/books',
                  onTap: () => go('/content'),
                ),
                _NavItem(
                  icon: Icons.send_outlined,
                  activeIcon: Icons.send_rounded,
                  active: location == '/voice-chat',
                  onTap: () => go('/voice-chat'),
                ),
                _NavItem(
                  icon: Icons.leaderboard_outlined,
                  activeIcon: Icons.leaderboard_rounded,
                  active: location == '/contests',
                  onTap: () => go('/contests'),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
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
    required this.active,
    required this.onTap,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!active) HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(10),
        // Premium: faol — YASHIL to'ldirilgan ikon (fon doira yo'q).
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          scale: active ? 1.12 : 1.0,
          child: Icon(
            active ? (activeIcon ?? icon) : icon,
            color: active ? AppColors.parvozGreen : AppColors.parvozTextDim,
            size: 26,
          ),
        ),
      ),
    );
  }
}

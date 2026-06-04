// ─────────────────────────────────────────────────────────────────────
// ChildBottomNavigation — 4 ta tab + ustida MiniAudioPlayer
// ─────────────────────────────────────────────────────────────────────
//
// Tab'lar:
//   📊 bar_chart       — /dashboard      (Diagnostika + ilova foydalanish)
//   📺 ondemand_video  — /videos         (Videolar feed)
//   🎧 headphones      — /audiobooks     (Audiokitoblar)
//   🏆 emoji_events    — /contests       (Konkurslar)
//   👤 person          — /profile        (Gamifikatsiya: Level/XP/DON)
//   🔔 notifications   — /notifications  (Bildirishnoma + badge)
//
// Eslatma: /dashboard ekrani Diagnostika ma'lumotlarini o'z ichiga oladi —
// /analytics ekrani /dashboard'ga redirect qilinadi (ikkalasi bir xil page).
//
// MiniAudioPlayer nav row ustiga qo'yiladi — audio o'ynayotgan paytda
// hamma ekranlarda ko'rinishi uchun (Spotify uslubi). Audio yo'q
// bo'lsa SizedBox.shrink — joy band qilmaydi.

import 'package:farzandim_child/core/theme/app_icons.dart';
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
    // Content library disabled bo'lsa bottom nav butunlay yashirinadi.
    // Bildirishnoma badge endi yuqori header'da ko'rinadi.
    if (!kEnableContentLibrary) {
      return const SizedBox.shrink();
    }

    final location = GoRouterState.of(context).matchedLocation;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniAudioPlayer(),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.bar_chart_outlined,
                    active: location == '/dashboard',
                    onTap: () {
                      if (location != '/dashboard') {
                        context.go('/dashboard');
                      }
                    },
                  ),
                  _NavItem(
                    icon: Icons.ondemand_video,
                    active: location == '/videos',
                    onTap: () {
                      if (location != '/videos') {
                        context.push('/videos');
                      }
                    },
                  ),
                  _NavItem(
                    icon: AppIcons.speaker,
                    active: location == '/audiobooks',
                    onTap: () {
                      if (location != '/audiobooks') {
                        context.push('/audiobooks');
                      }
                    },
                  ),
                  _NavItem(
                    icon: AppIcons.trophy,
                    active: location == '/contests',
                    onTap: () {
                      if (location != '/contests') {
                        context.push('/contests');
                      }
                    },
                  ),
                  _NavItem(
                    icon: AppIcons.profile,
                    active: location == '/profile',
                    onTap: () {
                      if (location != '/profile') {
                        context.push('/profile');
                      }
                    },
                  ),
                  // Bildirishnoma ikonkasi yuqori header'ga ko'chirildi —
                  // pastki nav'da takrorlanmaydi.
                ],
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
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!active) HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 64,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              // ignore: deprecated_member_use
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          scale: active ? 1.15 : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                color: active ? AppColors.primary : AppColors.textTertiary,
                size: 28,
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -2,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
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

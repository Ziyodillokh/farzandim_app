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
          decoration: BoxDecoration(
            color: context.adaptive.bgSurface,
            border: Border(
              top: BorderSide(color: context.adaptive.border),
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
                    activeIcon: Icons.bar_chart_rounded,
                    active: location == '/dashboard',
                    onTap: () {
                      if (location != '/dashboard') {
                        context.go('/dashboard');
                      }
                    },
                  ),
                  // Content hub — videolar + audiokitoblar + kitoblar
                  // bitta tab ostida birlashtirildi. /content ekranida
                  // TabBar orqali bo'limlar tanlanadi.
                  _NavItem(
                    icon: Icons.play_circle_outline,
                    activeIcon: Icons.play_circle_fill_rounded,
                    active: location == '/content' ||
                        location == '/videos' ||
                        location == '/audiobooks' ||
                        location == '/books',
                    onTap: () {
                      if (location != '/content') {
                        context.push('/content');
                      }
                    },
                  ),
                  // Messanger (o'rtada) — dashboard kartochkasi olib
                  // tashlandi, endi alohida tab sifatida turadi.
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    active: location == '/voice-chat',
                    onTap: () {
                      if (location != '/voice-chat') {
                        context.push('/voice-chat');
                      }
                    },
                  ),
                  // Konkurslar — alohida tab (avvalgi joyiga qaytarildi).
                  _NavItem(
                    icon: Icons.emoji_events_outlined,
                    activeIcon: Icons.emoji_events_rounded,
                    active: location == '/contests',
                    onTap: () {
                      if (location != '/contests') {
                        context.push('/contests');
                      }
                    },
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 64,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x335ECB44),
                    Color(0x22169E45),
                  ],
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          scale: active ? 1.15 : 1.0,
          child: Icon(
            active ? (activeIcon ?? icon) : icon,
            color: active ? AppColors.primary : context.adaptive.textTertiary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

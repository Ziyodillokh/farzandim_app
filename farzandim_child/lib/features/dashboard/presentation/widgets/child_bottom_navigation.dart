// ─────────────────────────────────────────────────────────────────────
// ChildBottomNavigation — suzuvchi pill nav (Growth yangi konsepsiyasi)
// ─────────────────────────────────────────────────────────────────────
//
// Tab'lar (chap→o'ng):
//   🏠 Asosiy     — /dashboard
//   📚 Kutubxona  — /content (video darslar + audiokitoblar)
//   📝 Testlar    — /contests
//   📊 Rivojlanish — /progress
//   👤 Profil     — /profile
//
// Faol tab — ko'k yumaloq-kvadrat fon + ko'k glow, oq ikon va yozuv.

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_icons.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/shared/widgets/mini_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

// Shaffof blur yo'q: sahifa almashganda orqadagi eski nav xiralashib
// "oq soya" bo'lib ko'rinardi. Deyarli to'liq to'q fon — toza va barqaror.
const _navBg = Color(0xFA0D141B);
const _navBorder = Color(0x1AFFFFFF);
const _inactive = Color(0xFFA9B4C4);
const _haloColor = Color(0xFF15407A);
const _haloGlow = Color(0xFF216BFF);

/// Navigatsiya paneli balandligi (sahifalar pastki bo'shliq uchun).
const double kChildNavBarHeight = 66;

/// Nav panel ostidagi bo'shliq: iOS'da home-indikator zonasiga biroz kiradi
/// (maketdagidek), Android'da kamida 12pt.
double childNavBottomGap(BuildContext context) =>
    math.max(12, MediaQuery.paddingOf(context).bottom - 4);

class _Tab {
  const _Tab({
    required this.path,
    required this.labelKey,
    required this.icon,
    this.alsoActiveOn = const [],
  });

  final String path;
  final String labelKey;

  /// (rang, faolmi) → ikon. Faol tab — to'ldirilgan (Bold), nofaol —
  /// chiziqli (Outline) variant (maketdagidek).
  final Widget Function(Color color, bool active) icon;
  final List<String> alsoActiveOn;

  bool isActive(String location) =>
      location == path || alsoActiveOn.contains(location);
}

final _tabs = <_Tab>[
  _Tab(
    path: '/dashboard',
    labelKey: 'nav.home',
    icon: (c, a) => Icon(
      a ? SolarIconsBold.homeSmile : SolarIconsOutline.homeSmile,
      size: 23,
      color: c,
    ),
  ),
  _Tab(
    path: '/content',
    labelKey: 'nav.library',
    icon: (c, a) => HomeSvgIcon(
      a ? homeLibraryFilledSvg : homeLibrarySvg,
      size: 23,
      color: c,
    ),
    alsoActiveOn: const ['/videos', '/audiobooks', '/books'],
  ),
  _Tab(
    path: '/contests',
    labelKey: 'nav.quizzes',
    icon: (c, a) => Icon(
      a ? SolarIconsBold.documentText : SolarIconsOutline.documentText,
      size: 23,
      color: c,
    ),
  ),
  _Tab(
    path: '/progress',
    labelKey: 'nav.results',
    icon: (c, a) => Icon(
      a ? SolarIconsBold.graphUp : SolarIconsOutline.graphUp,
      size: 23,
      color: c,
    ),
    alsoActiveOn: const ['/statistics', '/analytics'],
  ),
  _Tab(
    path: '/profile',
    labelKey: 'nav.profile',
    icon: (c, a) => Icon(
      a ? SolarIconsBold.user : SolarIconsOutline.user,
      size: 23,
      color: c,
    ),
  ),
];

class ChildBottomNavigation extends StatelessWidget {
  const ChildBottomNavigation({super.key, this.showMiniPlayer = true});

  /// Audiokitob mini-pleyeri (nav ustida). Skrinshot harness'i o'chiradi —
  /// pleyer platforma plaginisiz ishlamaydi.
  final bool showMiniPlayer;

  @override
  Widget build(BuildContext context) {
    if (!kEnableContentLibrary) {
      return const SizedBox.shrink();
    }

    final location = GoRouterState.of(context).matchedLocation;

    void go(String path) {
      if (location == path) return;
      if (path == '/dashboard') {
        context.go(path);
      } else if (_tabs.any(
        (t) => t.path != '/dashboard' && t.isActive(location),
      )) {
        // Tabdan tabga — stek o'smaydi, "orqaga" doim Asosiyga qaytaradi.
        context.pushReplacement(path);
      } else {
        context.push(path);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMiniPlayer) const MiniAudioPlayer(),
        Padding(
          padding: EdgeInsets.only(bottom: childNavBottomGap(context)),
          // Growth sahifalari kabi ekran kengligiga mutanosib (hamma
          // telefonda bir xil ko'rinadi).
          child: DesignScaleRow(
            height: kChildNavBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Container(
                height: kChildNavBarHeight,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: _navBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _navBorder),
                ),
                child: Row(
                  children: [
                    for (final tab in _tabs)
                      Expanded(
                        child: _NavItem(
                          tab: tab,
                          active: tab.isActive(location),
                          onTap: () => go(tab.path),
                        ),
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
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : _inactive;
    final icon = tab.icon(color, active);
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: () {
          if (!active) HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
              child: Center(child: active ? _ActiveHalo(child: icon) : icon),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.labelKey.tr(),
                maxLines: 1,
                style: homeText(
                  11.5,
                  weight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : _inactive,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faol tab foni — ko'k yumaloq-kvadrat + yumshoq ko'k glow.
class _ActiveHalo extends StatelessWidget {
  const _ActiveHalo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _haloColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _haloGlow.withValues(alpha: 0.5),
            blurRadius: 18,
            spreadRadius: -1,
          ),
        ],
      ),
      child: child,
    );
  }
}

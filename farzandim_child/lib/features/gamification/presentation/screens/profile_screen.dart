// ─────────────────────────────────────────────────────────────────────
// ProfileScreen — "Profil" (Growth yangi konsepsiyasi)
// ─────────────────────────────────────────────────────────────────────
//
// Tartib (pastki nav tab'i — orqaga tugmasi yo'q):
//   • Header: "Profil" + sozlamalar
//   • Shaxsiy karta: avatar (→ akkaunt), ism, sinf, qurilma • batareya
//   • 3 stat karta: ketma-ket kunlar / qadamlar / DON
//   • Fanlarim: sinf + tanlangan fanlar (→ /learn/setup)
//   • Menyu: natijalar kalendari, DON tarixi/reytingi, sevimlilar, sozlamalar
//   • Yutuqlar: 3 ustunli nishonlar to'ri
//
// Faqat REAL qiymatlar (soxta namuna raqamlari yo'q).
// LOGIKA SAQLANGAN: yangi yutuq unlock bo'lsa confetti + toast + haptic.

import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/data/models/achievement.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/achievement_badges.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/achievement_sheet.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/learning_profile_card.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/profile_identity_card.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/profile_menu.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/profile_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bo'limlar orasidagi masofa.
const _sectionGap = 14.0;

/// Pastki nav ustidagi qo'shimcha bo'shliq.
const _bottomExtra = 24.0;

const _confettiColors = [
  HomeColors.primary,
  HomeColors.blue,
  HomeColors.amber,
  HomeColors.orange,
  HomeColors.green,
];

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.navigation = const ChildBottomNavigation(),
  });

  final Widget navigation;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<String> _previousAchievementIds = const [];
  bool _initialLoaded = false;
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// Yangi yutuq unlock bo'lsa — confetti + toast. Manba BACKEND
  /// (`ChildProfile.achievements`) — real-time `profile:updated` bilan
  /// yangilanadi (masalan audiokitob yakunlanib 'first_book' berilganda).
  void _onGamification(
    AsyncValue<BackendGamification?>? _,
    AsyncValue<BackendGamification?> next,
  ) {
    final b = next.valueOrNull;
    if (b == null) return;
    if (!_initialLoaded) {
      _previousAchievementIds = b.unlockedAchievements;
      _initialLoaded = true;
      return;
    }
    final newIds = b.unlockedAchievements
        .where((id) => !_previousAchievementIds.contains(id))
        .toList();
    if (newIds.isEmpty) return;
    _previousAchievementIds = b.unlockedAchievements;
    _confetti.play();
    HapticFeedback.heavyImpact();
    for (final id in newIds) {
      final a = Achievements.byId(id);
      if (a != null) showAchievementUnlockedToast(context, a);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(backendGamificationProvider, _onGamification);
    final unlockedIds =
        ref
            .watch(backendGamificationProvider)
            .valueOrNull
            ?.unlockedAchievements ??
        const <String>[];

    return Scaffold(
      backgroundColor: HomeColors.bg,
      extendBody: true,
      bottomNavigationBar: widget.navigation,
      body: Stack(
        children: [
          // Builder — Scaffold ichidagi MediaQuery: `extendBody` tufayli
          // pastki padding nav balandligini o'z ichiga oladi.
          DesignScale(
            child: Builder(
              builder: (context) {
                final insets = MediaQuery.paddingOf(context);
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    growthTopInset(context),
                    16,
                    insets.bottom + _bottomExtra,
                  ),
                  children: [
                    PageHeader(
                      title: 'nav.profile'.tr(),
                      actions: [
                        HeaderIconButton(
                          semanticLabel: 'settings.title'.tr(),
                          onTap: () => context.push('/settings'),
                          child: const Icon(
                            SolarIconsOutline.settings,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const ProfileIdentityCard(),
                    const SizedBox(height: 10),
                    const ProfileStatsRow(),
                    const SizedBox(height: _sectionGap),
                    const LearningProfileCard(),
                    const SizedBox(height: _sectionGap),
                    const ProfileMenu(),
                    const SizedBox(height: _sectionGap),
                    AchievementBadges(unlockedIds: unlockedIds),
                  ],
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: 1.5708,
              maxBlastForce: 20,
              minBlastForce: 8,
              emissionFrequency: 0.05,
              numberOfParticles: 25,
              gravity: 0.3,
              shouldLoop: false,
              colors: _confettiColors,
            ),
          ),
        ],
      ),
    );
  }
}

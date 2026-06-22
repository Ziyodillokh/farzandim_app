// ─────────────────────────────────────────────────────────────────────
// SocialFeedScreen — ichki sotsial tarmoq (Parvoz NIGHT/GLASS Premium)
// ─────────────────────────────────────────────────────────────────────
//
// Konsept v2 talabi: ichki share, tashqi link YO'Q. Bola faqat
// ruxsatli kontent yaratuvchilarni kuzatadi.
//
// Parvoz UI Redesign: GradientBackground olib tashlandi →
// Scaffold(backgroundColor: context.adaptive.pvBg). Ranglar kun/tun
// (light/dark) ga moslashadi — ilovaning themeMode'idan meros olinadi.
// Faqat KO'RINISH; provider'lar, navigatsiya, .tr() va state — o'zgarmadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/social/presentation/providers/social_providers.dart';
import 'package:farzandim_child/features/social/presentation/widgets/social_feed_tabs.dart';
import 'package:farzandim_child/features/social/presentation/widgets/social_post_card.dart';
import 'package:farzandim_child/shared/widgets/empty_state_mascot.dart';
import 'package:farzandim_child/shared/widgets/faro_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SocialFeedScreen extends ConsumerWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(filteredSocialPostsProvider);
    final tab = ref.watch(socialFeedTabProvider);
    final pv = context.adaptive;

    return Scaffold(
      backgroundColor: pv.pvBg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DashboardTopHeader(
                onAvatarTap: () => context.push('/account-edit'),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SocialFeedTabs(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: posts.isEmpty
                  ? EmptyStateMascot(
                      faroVariant: FaroVariant.faceIdle,
                      accentColor: pv.pvGreen,
                      title: tab == SocialFeedTab.following
                          ? 'social.emptyFollowingTitle'.tr()
                          : 'social.emptyForYouTitle'.tr(),
                      subtitle: tab == SocialFeedTab.following
                          ? 'social.emptyFollowingSubtitle'.tr()
                          : 'social.emptyForYouSubtitle'.tr(),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      itemCount: posts.length,
                      itemBuilder: (_, i) =>
                          // Stagger: har post 60ms kechikish bilan
                          SocialPostCard(post: posts[i])
                              .animate()
                              .fadeIn(
                                duration: 350.ms,
                                delay: (60 * i).ms,
                              )
                              .slideY(
                                begin: 0.08,
                                end: 0,
                                duration: 350.ms,
                                delay: (60 * i).ms,
                                curve: Curves.easeOutCubic,
                              ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }
}

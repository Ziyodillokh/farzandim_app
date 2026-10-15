// Profil — 3 ta stat karta (bosh sahifa kartalari uslubida):
// ketma-ket kunlar → /streak-detail, bugungi qadamlar → /steps-detail,
// DON balansi → /don-history.
//
// DON/streak — haqiqiy manba backend (`ChildProfile`), Firestore profili
// faqat zaxira, u ham bo'lmasa 0. Qadam — REAL (qurilmadagi hisob).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_stat_cards.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _gap = 7.0;

class ProfileStatsRow extends ConsumerWidget {
  const ProfileStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(backendGamificationProvider).valueOrNull;
    final profile = ref.watch(gamificationProfileProvider).valueOrNull;
    final streak = backend?.streak ?? profile?.streak ?? 0;
    final don = backend?.don ?? profile?.don ?? 0;
    final steps = ref.watch(todayStepsProvider).valueOrNull ?? 0;

    return Row(
      children: [
        Expanded(
          child: GrowthStatCard(
            glow: HomeColors.amber,
            icon: SolarIconsBold.fire,
            iconColor: HomeColors.amber,
            value: 'statistics.daysCount'.tr(namedArgs: {'days': '$streak'}),
            label: 'home.streak'.tr(),
            onTap: () => context.push('/streak-detail'),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: GrowthStatCard(
            glow: HomeColors.blue,
            icon: SolarIconsBold.walking,
            iconColor: HomeColors.blue,
            value: formatHomeNumber(steps),
            label: 'stepsDetail.title'.tr(),
            onTap: () => context.push('/steps-detail'),
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: GrowthStatCard(
            glow: HomeColors.green,
            icon: SolarIconsBold.dollar,
            iconColor: HomeColors.green,
            value: formatHomeNumber(don),
            label: 'home.balance'.tr(),
            trailing: const DonBadge(),
            onTap: () => context.push('/don-history'),
          ),
        ),
      ],
    );
  }
}

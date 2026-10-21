// "Rivojlanish" sahifasidagi "Kelajak profilim" bo'limi: eng kuchli
// qiziqishlar va kuchli tomonlar, o'sgan mavzular / qiziqishlar (bo'lsa) va
// batafsil sahifaga havola. Rivojlanish tizimi takrorlanmaydi — faqat
// Kelajak profili qisqachasi. Kelajak mavjud bo'lmasa — bo'lim ham, ustidagi
// bo'shliq ham yo'q.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_insights.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_progress.dart';
import 'package:farzandim_child/features/kelajak/domain/kelajak_types.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_display.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/kelajak/presentation/widgets/kelajak_common.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/progress_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

/// Bo'limda ko'rsatiladigan qiziqish / kuchli tomonlar soni.
const _maxShown = 3;

class KelajakProfileSection extends ConsumerWidget {
  const KelajakProfileSection({super.key, this.topGap = 14});

  /// Bo'lim ustidagi bo'shliq (Rivojlanish bo'limlari orasidagidek).
  final double topGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(kelajakAvailableProvider)) return const SizedBox.shrink();
    final overview = ref.watch(kelajakOverviewProvider).valueOrNull;
    if (overview == null) return const SizedBox.shrink();
    final profile = overview.profile;
    final Widget child;
    if (overview.age.status == KelajakAgeStatus.ageRequired) {
      child = _Prompt(
        text: 'kelajak.home.ageHint'.tr(),
        label: 'kelajak.age.requiredAction'.tr(),
        onTap: () => openKelajakAgeEdit(context, ref),
      );
    } else if (profile == null) {
      child = _Prompt(
        text: 'kelajak.profile.empty'.tr(),
        label: 'kelajak.action.start'.tr(),
        onTap: () => openKelajakHub(context),
      );
    } else {
      final progress = ref.watch(kelajakProgressProvider).valueOrNull;
      child = _Summary(profile: profile, progress: progress);
    }
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: ProgressSection(
        title: 'kelajak.profile.title'.tr(),
        subtitle: 'kelajak.profile.subtitle'.tr(),
        onSeeAll: profile == null ? null : () => openKelajakProgress(context),
        child: child,
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.profile, this.progress});

  final KelajakProfile profile;
  final KelajakProgress? progress;

  @override
  Widget build(BuildContext context) {
    final interests = _interests(context);
    final strengths = [
      for (final s in profile.insights.strengths.take(_maxShown))
        s.title.inLocale(context),
    ];
    final progress = this.progress;
    final grown = progress == null
        ? const <String>[]
        : [
            for (final c in progress.improvedCategories)
              c.name.inLocale(context),
            for (final i in progress.risingInterests) i.name.inLocale(context),
          ];
    final rows = <Widget>[
      if (interests.isNotEmpty)
        _Row(label: 'kelajak.profile.interests'.tr(), values: interests),
      if (strengths.isNotEmpty)
        _Row(label: 'kelajak.profile.strengths'.tr(), values: strengths),
      if (grown.isNotEmpty)
        _Row(
          label: 'kelajak.profile.grown'.tr(),
          values: grown,
          icon: SolarIconsOutline.graphUp,
        ),
    ];
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: KelajakNote('kelajak.profile.early'.tr()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }

  /// Ishonchli yo'nalishlar; bo'lmasa — eng yuqori o'lchamlar nomi.
  List<String> _interests(BuildContext context) {
    final insights = profile.insights.interests;
    if (insights.isNotEmpty) {
      return [
        for (final i in insights.take(_maxShown)) i.title.inLocale(context),
      ];
    }
    final dims = profile.interests;
    if (dims == null) return const [];
    return [
      for (final code in dims.top.take(_maxShown))
        for (final d in dims.dimensions)
          if (d.code == code) d.name.inLocale(context),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.values, this.icon});

  final String label;
  final List<String> values;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: homeText(
              12.5,
              weight: FontWeight.w600,
              color: HomeColors.textDim,
            ),
          ),
          const SizedBox(height: 6),
          KelajakChipWrap(labels: values, icon: icon),
        ],
      ),
    );
  }
}

/// Profil hali yo'q yoki yosh kiritilmagan: izoh va tugma.
class _Prompt extends StatelessWidget {
  const _Prompt({required this.text, required this.label, required this.onTap});

  final String text;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KelajakNote(text),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: KelajakPillButton(
              label: label,
              icon: SolarIconsOutline.arrowRight,
              height: 40,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

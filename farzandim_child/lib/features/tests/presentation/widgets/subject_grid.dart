// "Fanlar bo‘yicha" — 2 ustunli fan kartalari (HAQIQIY backend testlari).
// Holatlar: yuklanmoqda (skelet) · xato (qayta urinish) · bo'sh · ro'yxat.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_stat_cards.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/tests/domain/test_subject.dart';
import 'package:farzandim_child/features/tests/presentation/providers/tests_providers.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/subject_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _cardBg = Color(0xFF11161F);
const _cardBorder = Color(0xFF232838);
const _gap = 9.4;
const _cardHeight = 98.5;

/// Shrift masshtabiga moslashgan karta balandligi.
double _cardExtent(BuildContext context) {
  const text = 13 * 1.25 + 4 + 10.8 * 1.25; // nom + oraliq + test soni
  final scaled = MediaQuery.textScalerOf(context).scale(text);
  return _cardHeight + (scaled - text).clamp(0, 50);
}

class SubjectGrid extends ConsumerWidget {
  const SubjectGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(testSubjectsProvider);
    final async = ref.watch(backendContestsProvider);

    if (subjects.isEmpty) {
      if (async.isLoading) return const _SkeletonGrid();
      if (async.hasError) {
        return _Notice(
          icon: Icons.wifi_off_rounded,
          title: 'contests.loadError'.tr(),
          action: TextButton(
            onPressed: () => ref.invalidate(backendContestsProvider),
            child: Text('common.retry'.tr()),
          ),
        );
      }
      return _Notice(
        icon: Icons.fact_check_outlined,
        title: 'tests.empty'.tr(),
        subtitle: 'tests.emptyHint'.tr(),
      );
    }

    final extent = _cardExtent(context);
    return Column(
      children: [
        for (var i = 0; i < subjects.length; i += 2) ...[
          if (i > 0) const SizedBox(height: _gap),
          SizedBox(
            height: extent,
            child: Row(
              children: [
                Expanded(child: SubjectCard(group: subjects[i])),
                const SizedBox(width: _gap),
                Expanded(
                  child: i + 1 < subjects.length
                      ? SubjectCard(group: subjects[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Fan nomi — tarjima kaliti bo'lsa joriy tilda, bo'lmasa backend nomi.
String subjectDisplayName(TestSubjectGroup group) {
  final key = subjectLabelKey(group.key);
  return key == null ? group.fallbackLabel : key.tr();
}

class SubjectCard extends StatelessWidget {
  const SubjectCard({super.key, required this.group});

  final TestSubjectGroup group;

  @override
  Widget build(BuildContext context) {
    final style = subjectStyleFor(group.key);
    final reward = group.availableReward;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/tests/subject', extra: group.key);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder),
          ),
          child: Stack(
            children: [
              // Fan rangidagi pastki nur.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.15, 1.35),
                      radius: 0.95,
                      colors: [
                        style.glowColor,
                        style.color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10.5, 9.5, 7, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: style.squareColor,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: style.icon(25, style.squareColor),
                        ),
                        const SizedBox(width: 6),
                        // Mukofot qolgan butun kenglikni oladi (o'ngga
                        // tekislangan); juda katta summa bo'lsa kichrayadi.
                        Expanded(
                          child: reward > 0
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 3.5),
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: _Reward(reward: reward),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2.5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subjectDisplayName(group),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: homeText(
                                    13,
                                    weight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'tests.count'.plural(group.count),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: homeText(
                                    10.8,
                                    color: HomeColors.textDim,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 24,
                            color: HomeColors.chevron,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.reward});

  final int reward;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatHomeNumber(reward),
            style: homeDisplay(13.4, height: 1.1, letterSpacing: -0.2),
          ),
          const SizedBox(width: 4.5),
          const DonBadge(fontSize: 8.6),
        ],
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
      height: _cardHeight,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          Row(
            children: [
              Expanded(child: box()),
              const SizedBox(width: _gap),
              Expanded(child: box()),
            ],
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: HomeColors.textDim),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: homeText(14, weight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: homeText(12, color: HomeColors.textDim),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 4), action!],
        ],
      ),
    );
  }
}

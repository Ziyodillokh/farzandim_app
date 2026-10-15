// "Yangi testlar" — eng so'nggi testlar ro'yxati (HAQIQIY backend).
// Faol testlar avval. Bosilsa: faol → shartlar → quiz; yakunlangan → xabar.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_stat_cards.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/tests/domain/test_subject.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/subject_style.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/tests_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ro'yxatda ko'pi bilan shuncha test.
const _maxItems = 5;

const _rowBg = Color(0xFF11161F);
const _rowBorder = Color(0xFF232838);
const _rewardGreen = Color(0xFF14D68C);

class LatestTestsSection extends ConsumerWidget {
  const LatestTestsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = ref.watch(allTestsProvider).take(_maxItems).toList();
    if (tests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Text(
            'tests.latest'.tr(),
            style: homeDisplay(20.5, letterSpacing: -0.3),
          ),
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Text(
            'tests.latestSubtitle'.tr(),
            style: homeText(13, color: HomeColors.textDim),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < tests.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          _TestRow(test: tests[i]),
        ],
      ],
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({required this.test});

  final ContestModel test;

  @override
  Widget build(BuildContext context) {
    final style = subjectStyleFor(testSubjectKey(test.soha));
    final meta = [
      if (test.savollarSoni > 0) 'home.questions'.plural(test.savollarSoni),
      if (test.vaqtChegarasiDaq > 0)
        'tests.minutes'.plural(test.vaqtChegarasiDaq),
    ].join(' · ');
    return Semantics(
      button: true,
      child: Material(
        color: _rowBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _rowBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openTest(context, test),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: style.squareColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: style.icon(24, style.squareColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: homeText(
                          14.5,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: homeText(12.5, color: HomeColors.textDim),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (test.isActive && test.bonus > 0)
                  _Reward(reward: test.bonus)
                else if (!test.isActive)
                  const _FinishedChip(),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: HomeColors.chevron,
                ),
              ],
            ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+${formatHomeNumber(reward)}',
          style: homeText(14, weight: FontWeight.w700, color: _rewardGreen),
        ),
        const SizedBox(width: 5),
        const DonBadge(fontSize: 9.5),
      ],
    );
  }
}

class _FinishedChip extends StatelessWidget {
  const _FinishedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'tests.finished'.tr(),
        style: homeText(
          11.5,
          weight: FontWeight.w600,
          color: HomeColors.textDim,
        ),
      ),
    );
  }
}

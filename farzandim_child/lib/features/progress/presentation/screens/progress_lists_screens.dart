// "Barchasini ko‘rish" sahifalari: fanlar bo'yicha natija va barcha natijalar.
// `/progress/subjects`, `/progress/results`.

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/providers/progress_providers.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/result_row.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/subject_score_tile.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          math.max(12, insets.top - 6),
          16,
          insets.bottom + 24,
        ),
        children: [
          InnerPageHeader(title: title),
          const SizedBox(height: 16),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Text(
                'progress.noResults'.tr(),
                textAlign: TextAlign.center,
                style: homeText(14, color: HomeColors.textDim),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

/// Fanlar bo'yicha natija — 2 ustunli plitkalar.
class ProgressSubjectsScreen extends ConsumerWidget {
  const ProgressSubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = [...ref.watch(subjectScoresProvider)]
      ..sort((a, b) => b.percent.compareTo(a.percent));
    return _ListPage(
      title: 'progress.subjectsTitle'.tr(),
      children: [
        for (var i = 0; i < scores.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: SubjectScoreTile(score: scores[i])),
              const SizedBox(width: 9),
              Expanded(
                child: i + 1 < scores.length
                    ? SubjectScoreTile(score: scores[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Barcha natijalar — yangisi birinchi.
class ProgressResultsScreen extends ConsumerWidget {
  const ProgressResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(recentResultsProvider);
    return _ListPage(
      title: 'progress.allResultsTitle'.tr(),
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          ResultRow(result: results[i]),
        ],
      ],
    );
  }
}

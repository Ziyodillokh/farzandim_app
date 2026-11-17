// U08 (tarixdan): saqlangan mashq natijasi — o'sha fandagi undan oldingi
// natija bilan solishtiriladi. Tugmalar mashq oxiridagi U08 bilan bir xil.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/growth/growth_links.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_outcome.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({super.key, required this.resultId});

  final String resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(learningResultsProvider);
    final index = results.indexWhere((r) => r.id == resultId);
    if (index < 0) {
      return Scaffold(
        backgroundColor: GColors.bg,
        body: GScreen(
          top: GTopBar(
            leading: GTopBar.back(
              label: 'g5.common.back'.tr(),
              onPressed: () => context.pop(),
            ),
            title: 'g5.attempts.title'.tr(),
          ),
          children: [
            GNote(text: 'g5.attempts.notFound'.tr(), kind: GNoteKind.warn),
          ],
        ),
      );
    }
    final result = results[index];
    TestResult? previous;
    for (final r in results.skip(index + 1)) {
      if (r.subject == result.subject) {
        previous = r;
        break;
      }
    }
    final outcome = buildOutcome(
      correct: result.correct,
      total: result.total,
      previous: previous == null
          ? null
          : (correct: previous.correct, total: previous.total),
    );
    return Scaffold(
      backgroundColor: GColors.bg,
      body: PracticeResultView(
        result: result,
        outcome: outcome,
        previous: previous,
        topic: result.topic.of(context.locale.languageCode),
        onClose: () => context.pop(),
        onNextPractice: () => GrowthLinks.practice(context, result.subject),
        onKnowledgeMap: () => GrowthLinks.subjectMap(context, result.subject),
        onDonHistory: () => context.push('/don-history'),
      ),
    );
  }
}

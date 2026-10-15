// ─────────────────────────────────────────────────────────────────────
// QuizReviewScreen — javoblar tahlili (`/learn/review`, extra: TestResult)
// ─────────────────────────────────────────────────────────────────────
//
// Har savol: savol matni, variantlar (to'g'ri — yashil, bolaning xato
// javobi — qizil) va izoh. Savollar bankdan id bo'yicha olinadi; bank
// yangilanib savol topilmasa — qisqa izoh.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_feedback_card.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_option_tile.dart';
import 'package:farzandim_child/features/progress/presentation/widgets/result_row.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuizReviewScreen extends ConsumerWidget {
  const QuizReviewScreen({super.key, required this.result});

  final TestResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(questionBankProvider(result.subject));
    final lang = context.locale.languageCode;

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            final questions = bank.valueOrNull;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                growthTopInset(context),
                16,
                insets.bottom + 24,
              ),
              children: [
                InnerPageHeader(
                  title: 'learn.reviewTitle'.tr(),
                  subtitle:
                      '${resultTitle(context, result)} · ${formatResultDate(result.date)}',
                  trailing: ScorePill(result: result),
                  fallbackRoute: '/progress',
                ),
                const SizedBox(height: 18),
                if (!result.canReview)
                  _Note(text: 'learn.reviewUnavailable'.tr())
                else if (questions == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: HomeColors.primary,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < result.answers.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _ReviewItem(
                      number: i + 1,
                      answer: result.answers[i],
                      question: questions[result.answers[i].questionId],
                      lang: lang,
                    ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.number,
    required this.answer,
    required this.question,
    required this.lang,
  });

  final int number;
  final QuizAnswer answer;
  final QuizQuestion? question;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: homeCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'learn.questionN'.tr(namedArgs: {'n': '$number'}),
            style: homeText(
              12.5,
              weight: FontWeight.w600,
              color: HomeColors.textDim,
            ),
          ),
          const SizedBox(height: 6),
          if (q == null)
            Text(
              'learn.reviewMissing'.tr(),
              style: homeText(14, color: HomeColors.textDim),
            )
          else ...[
            Text(
              q.prompt.of(lang),
              style: homeText(16, weight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < q.options.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              QuizOptionTile(
                index: i,
                text: q.options[i].of(lang),
                state: i == q.answerIndex
                    ? OptionState.correct
                    : i == answer.selectedIndex
                    ? OptionState.wrong
                    : OptionState.dimmed,
              ),
            ],
            const SizedBox(height: 12),
            QuizFeedbackCard(
              isCorrect: answer.isCorrect,
              explanation: q.explanation.of(lang),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: homeText(14.5, color: HomeColors.textDim, height: 1.4),
      ),
    );
  }
}

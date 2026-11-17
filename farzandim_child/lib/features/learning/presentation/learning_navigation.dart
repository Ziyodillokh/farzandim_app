// Daily Learning sahifalariga o'tish — bir joyda (bosh sahifa, Testlar,
// Rivojlanish, kalendar va natija sahifasi shu yordamchilarni ishlatadi).

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class LearningRoutes {
  static const quiz = '/learn/quiz';
  static const review = '/learn/review';
  static const setup = '/learn/setup';
  static const calendar = '/learn/calendar';
}

/// Fan bo'yicha kunlik test.
void openSubjectQuiz(BuildContext context, Subject subject) {
  HapticFeedback.selectionClick();
  context.push(LearningRoutes.quiz, extra: subject);
}

/// "Boshlash": navbatdagi yechilmagan fan; hammasi bajarilgan bo'lsa —
/// natijalar; profil yo'q bo'lsa — fan tanlash.
void startDailyLearning(BuildContext context, WidgetRef ref) {
  final plan = ref.read(dailyPlanProvider);
  if (plan.isEmpty) {
    HapticFeedback.selectionClick();
    context.push(LearningRoutes.setup);
    return;
  }
  final next = plan.nextItem;
  if (next == null) {
    HapticFeedback.selectionClick();
    context.push(LearningRoutes.calendar);
    return;
  }
  openSubjectQuiz(context, next.subject);
}

/// Natijani ochish: javoblar saqlangan bo'lsa — tahlil sahifasi.
void openResultReview(BuildContext context, TestResult result) {
  HapticFeedback.selectionClick();
  context.push(LearningRoutes.review, extra: result);
}

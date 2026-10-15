// Growth sahifalari marshrutlari: Testlar, Rivojlanish va Daily Learning
// (kunlik test, javoblar tahlili, fan tanlash, kalendar).

import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/learning_navigation.dart';
import 'package:farzandim_child/features/learning/presentation/screens/daily_quiz_screen.dart';
import 'package:farzandim_child/features/learning/presentation/screens/learning_calendar_screen.dart';
import 'package:farzandim_child/features/learning/presentation/screens/learning_setup_screen.dart';
import 'package:farzandim_child/features/learning/presentation/screens/quiz_review_screen.dart';
import 'package:farzandim_child/features/progress/presentation/screens/progress_lists_screens.dart';
import 'package:farzandim_child/features/progress/presentation/screens/progress_screen.dart';
import 'package:farzandim_child/features/tests/presentation/screens/subject_tests_screen.dart';
import 'package:farzandim_child/features/tests/presentation/screens/tests_screen.dart';
import 'package:farzandim_child/features/tests/presentation/screens/tests_search_screen.dart';
import 'package:go_router/go_router.dart';

/// `kEnableContentLibrary` o'chiq bo'lsa yopiladigan Growth manzillari.
const growthContentPaths = {
  '/contests',
  '/tests/subject',
  '/tests/search',
  '/progress',
  '/progress/subjects',
  '/progress/results',
  LearningRoutes.quiz,
  LearningRoutes.review,
  LearningRoutes.calendar,
};

final growthRoutes = <RouteBase>[
  GoRoute(
    path: '/contests',
    pageBuilder: (context, state) => tabPage(state, const TestsScreen()),
  ),
  GoRoute(
    path: '/tests/subject',
    // Fan kaliti `extra`da keladi; yo'q bo'lsa (deep-link / tiklash) —
    // Testlar sahifasi.
    redirect: (context, state) {
      final key = state.extra;
      return key is String && key.isNotEmpty ? null : '/contests';
    },
    pageBuilder: (context, state) => slidePage(
      state,
      SubjectTestsScreen(subjectKey: (state.extra as String?) ?? ''),
    ),
  ),
  GoRoute(
    path: '/tests/search',
    pageBuilder: (context, state) =>
        slidePage(state, const TestsSearchScreen()),
  ),
  GoRoute(
    path: '/progress',
    pageBuilder: (context, state) => tabPage(state, const ProgressScreen()),
  ),
  GoRoute(
    path: '/progress/subjects',
    pageBuilder: (context, state) =>
        slidePage(state, const ProgressSubjectsScreen()),
  ),
  GoRoute(
    path: '/progress/results',
    pageBuilder: (context, state) =>
        slidePage(state, const ProgressResultsScreen()),
  ),
  GoRoute(
    path: LearningRoutes.quiz,
    // Fan `extra`da keladi; yo'q bo'lsa (deep-link / tiklash) — bosh sahifa.
    redirect: (context, state) => state.extra is Subject ? null : '/dashboard',
    pageBuilder: (context, state) =>
        sessionPage(state, DailyQuizScreen(subject: state.extra! as Subject)),
  ),
  GoRoute(
    path: LearningRoutes.review,
    redirect: (context, state) =>
        state.extra is TestResult ? null : '/progress/results',
    pageBuilder: (context, state) =>
        slidePage(state, QuizReviewScreen(result: state.extra! as TestResult)),
  ),
  GoRoute(
    path: LearningRoutes.setup,
    pageBuilder: (context, state) =>
        slidePage(state, const LearningSetupScreen()),
  ),
  GoRoute(
    path: LearningRoutes.calendar,
    pageBuilder: (context, state) =>
        slidePage(state, const LearningCalendarScreen()),
  ),
];

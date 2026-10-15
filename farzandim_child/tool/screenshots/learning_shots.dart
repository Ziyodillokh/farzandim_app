// Skrinshot harness'i uchun Daily Learning sahifalari, holatlari va
// harakatlari (SHOT_PAGE / SHOT_STATE).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_session.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/learning/presentation/screens/daily_quiz_screen.dart';
import 'package:farzandim_child/features/learning/presentation/screens/learning_calendar_screen.dart';
import 'package:farzandim_child/features/learning/presentation/screens/learning_setup_screen.dart';
import 'package:farzandim_child/features/learning/presentation/screens/quiz_review_screen.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_body.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_option_tile.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/quiz/quiz_result_view.dart';
import 'package:farzandim_child/features/gamification/presentation/screens/profile_screen.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const shotState = String.fromEnvironment('SHOT_STATE', defaultValue: 'fresh');

const learningPages = {
  'quiz',
  'quiz_selected',
  'quiz_checked',
  'result',
  'review',
  'setup',
  'setup_subjects',
  'calendar',
  'profile',
};

String? learningLocation(String page) => switch (page) {
  'quiz' || 'quiz_selected' || 'quiz_checked' => '/quiz',
  'result' => '/result',
  'review' => '/review',
  'setup' || 'setup_subjects' => '/setup',
  'calendar' => '/calendar',
  'profile' => '/profile',
  _ => null,
};

DateTime get _today => DateTime.now();

TestResult _result(
  Subject s,
  int correct, {
  int hoursAgo = 1,
  List<QuizAnswer> answers = const [],
}) {
  final now = _today;
  return TestResult(
    id: 'shot-${s.name}',
    subject: s,
    topic: const LocalizedText({
      'uz': 'Kasrlar',
      'ru': 'Дроби',
      'en': 'Fractions',
    }),
    correct: correct,
    total: 10,
    date: DateTime(now.year, now.month, now.day, 9 + hoursAgo),
    answers: answers,
    donEarned: donFor(correct, 10),
    durationSeconds: 155,
  );
}

final _mathAnswers = [
  for (var i = 1; i <= 6; i++)
    QuizAnswer(
      questionId: 'math-0$i',
      selectedIndex: i == 3 ? 3 : -1,
      isCorrect: i != 3,
    ),
];

/// Ko'rib chiqish uchun: javob indekslari bankdagi to'g'ri javobga moslanadi.
TestResult reviewResult(Map<String, int> correctById) => _result(
  Subject.math,
  5,
  answers: [
    for (final a in _mathAnswers)
      QuizAnswer(
        questionId: a.questionId,
        selectedIndex: a.isCorrect
            ? correctById[a.questionId] ?? 0
            : ((correctById[a.questionId] ?? 0) + 1) % 4,
        isCorrect: a.isCorrect,
      ),
  ],
);

List<TestResult> _storedFor(String state) => switch (state) {
  'partial' => [_result(Subject.math, 9, answers: _mathAnswers)],
  'done' => [
    _result(Subject.math, 9, answers: _mathAnswers),
    _result(Subject.english, 7, hoursAgo: 2),
    _result(Subject.native, 8, hoursAgo: 3),
  ],
  _ => const [],
};

class _FixedResults extends LearningResultsNotifier {
  @override
  Future<List<TestResult>> build() async => _storedFor(shotState);
}

/// Ulangan bola (Profil uchun).
class _FakePairing extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  _FakePairing()
    : super(
        const AppPairingState(
          status: PairingStatus.paired,
          parentUid: 'parent-1',
          childId: 'child-1',
          childName: 'Aziza Karimova',
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> learningOverrides() => [
  pairingStateProvider.overrideWith((ref) => _FakePairing()),
  childAvatarUrlProvider.overrideWith((ref, id) async => null),
  childDataStreamProvider.overrideWith(
    (ref, key) async => <String, dynamic>{'gender': 'female', 'age': 12},
  ),
  todayStepsProvider.overrideWith((ref) async => 6842),
  storedResultsProvider.overrideWith(_FixedResults.new),
  if (shotState == 'nosetup') ...[
    learningProfileProvider.overrideWithValue(null),
    needsLearningSetupProvider.overrideWithValue(true),
  ],
];

List<RouteBase> learningShotRoutes() => [
  GoRoute(
    path: '/quiz',
    builder: (_, __) => const DailyQuizScreen(subject: Subject.math),
  ),
  GoRoute(
    path: '/result',
    builder: (_, __) => Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: QuizResultView(
          result: _result(Subject.math, 8, answers: _mathAnswers),
          saving: false,
          saveFailed: false,
          onRetrySave: () {},
        ),
      ),
    ),
  ),
  GoRoute(path: '/review', builder: (_, __) => const _ReviewLoader()),
  GoRoute(
    path: '/setup',
    builder: (_, __) => const LearningSetupScreen(isOnboarding: true),
  ),
  GoRoute(
    path: '/calendar',
    builder: (_, __) => const LearningCalendarScreen(),
  ),
  GoRoute(
    path: '/profile',
    builder: (_, __) => const ProfileScreen(
      navigation: ChildBottomNavigation(showMiniPlayer: false),
    ),
  ),
];

/// Bank yuklangach to'g'ri javob indekslari bilan natija quriladi.
class _ReviewLoader extends ConsumerWidget {
  const _ReviewLoader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(questionBankProvider(Subject.math)).valueOrNull;
    if (bank == null) return const SizedBox.shrink();
    return QuizReviewScreen(
      result: reviewResult({
        for (final e in bank.entries) e.key: e.value.answerIndex,
      }),
    );
  }
}

/// Sahifa chizilgandan keyingi harakatlar (variant tanlash va h.k.).
Future<void> performLearningActions(WidgetTester tester, String page) async {
  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  switch (page) {
    case 'quiz_selected':
      await tester.tap(find.byType(QuizOptionTile).at(1));
      await settle();
    case 'quiz_checked':
      final body = tester.widget<QuizBody>(find.byType(QuizBody));
      final wrong = (body.session.current.answerIndex + 1) % 4;
      await tester.tap(find.byType(QuizOptionTile).at(wrong));
      await settle();
      await tester.tap(find.text('learn.check'.tr()));
      await settle();
    case 'setup_subjects':
      await tester.tap(find.text('7'));
      await settle();
      await tester.tap(find.text('learn.next'.tr()));
      await settle();
      for (final s in [Subject.math, Subject.english, Subject.native]) {
        await tester.tap(find.text(s.labelKey.tr()));
        await settle();
      }
  }
}

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
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/features/learning/domain/quiz_models.dart';
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

import '../../test/features/learning/fake_learning_repository.dart';

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

const _topic = LocalizedText({
  'uz': 'Kasrlar',
  'ru': 'Дроби',
  'en': 'Fractions',
});

TestResult _result(Subject s, int correct, {int daysAgo = 0, int hour = 10}) {
  final now = _today;
  return TestResult(
    id: 'shot-${s.name}-$daysAgo',
    subject: s,
    topic: _topic,
    correct: correct,
    total: 10,
    date: DateTime(now.year, now.month, now.day - daysAgo, hour),
    donEarned: correct * 2,
    durationSeconds: 155,
  );
}

const _profile = LearningProfile(
  grade: 7,
  subjects: [Subject.math, Subject.english, Subject.native],
);

/// Namunaviy tarix (oxirgi 2 hafta, har 7-kunda dam olish).
List<TestResult> _history() => [
  for (var d = 1; d <= 14; d++)
    if (d % 7 != 4)
      for (final (i, s) in _profile.subjects.indexed)
        _result(
          s,
          [9, 6, 8][i] - (d ~/ 7) + (d * 3 + i) % 3 - 1,
          daysAgo: d,
          hour: 17 + i,
        ),
];

List<TestResult> _todayFor(String state) => switch (state) {
  'partial' => [_result(Subject.math, 9)],
  'done' => [
    _result(Subject.math, 9),
    _result(Subject.english, 7, hour: 11),
    _result(Subject.native, 8, hour: 12),
  ],
  _ => const [],
};

FakeLearningRepository _repository() => FakeLearningRepository(
  profile: shotState == 'nosetup' ? null : _profile,
  results: [..._todayFor(shotState), ..._history()]
    ..sort((a, b) => b.date.compareTo(a.date)),
);

AttemptReview _review() => AttemptReview(
  result: _result(Subject.math, 5),
  items: [
    for (var i = 0; i < 4; i++)
      ReviewItem(
        question: QuizQuestion(
          id: 'q$i',
          difficulty: 1,
          topic: _topic,
          prompt: LocalizedText.same('${i + 1}/4 + 1/8 = ?'),
          options: [
            for (final o in ['3/8', '5/8', '7/8', '1']) LocalizedText.same(o),
          ],
        ),
        correctIndex: i % 4,
        explanation: LocalizedText.same(
          'Kasrlarni umumiy maxrajga keltiramiz.',
        ),
        selectedIndex: i == 2 ? 3 : i % 4,
        isCorrect: i != 2,
      ),
  ],
);

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
  learningRepositoryProvider.overrideWithValue(_repository()),
  attemptReviewProvider.overrideWith((ref, id) async => _review()),
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
        child: QuizResultView(result: _result(Subject.math, 8)),
      ),
    ),
  ),
  GoRoute(
    path: '/review',
    builder: (_, __) => QuizReviewScreen(result: _result(Subject.math, 5)),
  ),
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
      final correct = FakeLearningRepository.correctIndexOf(
        body.session.current.id,
      );
      final wrong = (correct + 1) % 4;
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

// 6-bosqich: K01–K06 (qiziqishlar, kasblar, haftalik maqsad, xavfsizlik
// darslari) va F01/F03/F04 (oila, SOS, qo'shimcha vaqt).

import 'package:farzandim_child/features/account/presentation/providers/child_repository_provider.dart';
import 'package:farzandim_child/features/learning/domain/localized_text.dart';
import 'package:farzandim_child/features/learning/domain/progress_models.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kelajak/kelajak_data.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/oila/family_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

class _FakeExtraTime implements ExtraTimeRepository {
  _FakeExtraTime(this.current);

  ExtraTimeRequest? current;
  final asked = <int>[];
  final cancelled = <String>[];

  @override
  Future<ExtraTimeRequest?> latest() async => current;

  @override
  Future<void> ask({required int minutes, String? reason}) async {
    asked.add(minutes);
    current = ExtraTimeRequest(
      id: 'u1',
      status: ExtraTimeStatus.pending,
      requestedAt: kG5Now,
      requestedMinutes: minutes,
      reason: reason,
    );
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    current = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TestResult _result(Subject subject, DateTime date) => TestResult(
  id: '${subject.name}-${date.millisecondsSinceEpoch}',
  subject: subject,
  topic: LocalizedText.same('t'),
  correct: 8,
  total: 10,
  date: date,
);

Future<void> _pump(
  WidgetTester tester,
  String location, {
  List<Override> extra = const [],
}) => pumpG5App(
  tester,
  routes: buildGrowthV5Routes(),
  initialLocation: location,
  overrides: [
    ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
    parentNameProvider.overrideWith((ref) async => 'Nilufar Karimova'),
    ...extra,
  ],
);

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ma\'lumotlar', () {
    test('hafta dushanbadan; maqsad faqat shu haftani va fanni sanaydi', () {
      final now = DateTime(2026, 11, 5, 10); // payshanba
      expect(weekStartOf(now), DateTime(2026, 11, 2));
      final results = [
        _result(Subject.math, DateTime(2026, 11, 2, 9)),
        _result(Subject.math, DateTime(2026, 11, 4, 18)),
        _result(Subject.english, DateTime(2026, 11, 3)),
        _result(Subject.math, DateTime(2026, 11, 1, 20)), // o'tgan hafta
      ];
      expect(
        goalProgress(
          const WeeklyGoal(target: 3, subject: Subject.math),
          results,
          now,
        ),
        2,
      );
      expect(goalProgress(const WeeklyGoal(target: 3), results, now), 3);
    });

    test('kasb tavsiyasi — profilning eng yuqori o\'lchami', () {
      expect(CareerField.recommended(['A', 'S']), CareerField.design);
      expect(CareerField.recommended(const []), CareerField.engineering);
      expect(CareerField.medicine.subjectFor(3), Subject.math);
      expect(CareerField.medicine.subjectFor(7), Subject.biology);
    });

    test('xavfsizlik darsi: oxirgi javob xavfli, qolganlari xavfsiz', () {
      expect(SafetyLesson.codes.safe, {'keep', 'tellAdult'});
      expect(SafetyLesson.codes.safe.contains('give'), isFalse);
    });

    test('so\'rov javobi: faqat ekran vaqti, holatlar', () {
      final r = ExtraTimeRequest.tryFromJson({
        'id': 'u1',
        'kind': 'SCREEN_TIME',
        'status': 'CANCELLED',
        'requestedMinutes': 10,
        'requestedAt': '2026-11-05T09:00:00.000Z',
      });
      expect(r?.status, ExtraTimeStatus.cancelled);
      expect(
        ExtraTimeRequest.tryFromJson({
          'id': 'u2',
          'kind': 'APP',
          'requestedAt': '2026-11-05T09:00:00.000Z',
        }),
        isNull,
      );
    });
  });

  testWidgets('K05: xavfli javob — izoh; ikkala xavfsiz — yakunlanadi', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.kelajakLesson('codes'));

    await tester.tap(find.text('Kodni aytaman'));
    await tester.pump();
    await tester.tap(find.text('Tekshirish'));
    await settleG5(tester);
    expect(
      find.text('Bitta javob xavfli boʻlishi mumkin. Yana bir oʻylab koʻr.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Kodni aytaman'));
    await tester.tap(find.text('Kodni bermayman'));
    await tester.tap(find.text('Ishonchli kattaga aytaman'));
    await tester.pump();
    await tester.tap(find.text('Tekshirish'));
    await settleG5(tester);
    expect(find.textContaining('Ikkalasi ham xavfsiz'), findsOneWidget);
    expect(find.text('Yakunlash'), findsOneWidget);
  });

  testWidgets('F04: so\'rov yuboriladi, kutilmoqda va bekor qilinadi', (
    tester,
  ) async {
    final repo = _FakeExtraTime(null);
    await _pump(
      tester,
      GrowthV5Routes.familyExtraTime,
      extra: [extraTimeRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.tap(find.text('15 daqiqa'));
    await tester.pump();
    await tester.tap(find.text('Qoʻshimcha vaqt soʻrash'));
    await settleG5(tester);
    expect(repo.asked, [15]);
    expect(find.text('Javob kutilmoqda · Nilufar Karimova'), findsOneWidget);

    await tester.tap(find.text('Soʻrovni bekor qilish'));
    await settleG5(tester);
    expect(repo.cancelled, ['u1']);
    expect(find.text('Javob kutilmoqda · Nilufar Karimova'), findsNothing);
  });

  testWidgets(
    'F01: mehmon akkauntda qo\'shimcha vaqt yo\'q (cheklov egasiniki)',
    (tester) async {
      await _pump(
        tester,
        GrowthV5Routes.family,
        extra: [
          activeGuestProvider.overrideWithValue(
            const DeviceAccount(childId: 'g', name: 'Jasur', owner: false),
          ),
        ],
      );
      expect(find.text('Nilufar Karimova'), findsOneWidget);
      expect(find.text('Xabar yozish'), findsOneWidget);
      await _toEnd(tester);
      expect(find.text('Ekran vaqti'), findsNothing);
      expect(
        find.text('Bu yerda faqat tasdiqlangan oila aʼzolari koʻrinadi.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('F01: qurilma egasida qo\'shimcha vaqt so\'rash bor', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.family);
    await _toEnd(tester);
    expect(find.text('Ekran vaqti'), findsOneWidget);
  });
}

Future<void> _toEnd(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
  await settleG5(tester);
}

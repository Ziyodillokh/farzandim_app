// H01–H10 · Bola ovozi: anonim so'rov, shaxsiy yordam, murojaatlar,
// yozishma va mutaxassis tayinlagan so'rov (soxta manbalar, tarmoqsiz).

import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/school/domain/psych_answer.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/ovoz/data/voice_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/learning/fake_learning_repository.dart';
import '../features/school/fake_school_repository.dart';
import 'fake_school_v5.dart';
import 'fake_voice.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

Future<
  ({
    FakeVoiceRepository voice,
    FakeSchoolRepository school,
    MemoryOutboxStore store,
  })
>
_pump(
  WidgetTester tester,
  String location, {
  FakeVoiceRepository? voice,
  List<PsychAssignmentSummary> psychAssignments = const [kPersonalSummary],
}) async {
  final v =
      voice ??
      FakeVoiceRepository(
        survey: kVoiceSurvey(),
        contact: kVoiceContact,
        requests: kVoiceRequests,
        details: kVoiceDetails,
      );
  final school = FakeSchoolRepository(
    today: kSchoolToday,
    psychAssignments: psychAssignments,
    psychTests: const [kPersonalTest],
    clock: () => kG5Now,
  );
  final store = MemoryOutboxStore();
  await pumpG5App(
    tester,
    routes: buildGrowthV5Routes(),
    initialLocation: location,
    overrides: [
      ...g5Overrides(
        learning: FakeLearningRepository(clock: () => kG5Now),
        school: school,
        schoolAccount: 'child-1',
      ),
      ...voiceOverrides(v, store: store),
    ],
  );
  return (voice: v, school: school, store: store);
}

void main() {
  setUpAll(setUpG5WidgetTests);

  testWidgets('H01: ikki eshik, oylik so\'rov va faol murojaatlar', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.voice);

    expect(find.text('Oylik anonim soʻrov'), findsOneWidget);
    expect(
      find.text('Noyabr soʻrovi ochiq · taxminan 2 daqiqa'),
      findsOneWidget,
    );
    expect(find.text('Psixologga yozish'), findsOneWidget);
    expect(find.text('3 ta faol'), findsOneWidget);
  });

  testWidgets('H01: mutaxassis yuborgan testlar — sinfga ham, shaxsan ham', (
    tester,
  ) async {
    await _pump(
      tester,
      GrowthV5Routes.voice,
      psychAssignments: const [kPersonalSummary, _classSummary],
    );

    expect(find.text('Tayinlangan soʻrov · 3 ta savol'), findsOneWidget);
    expect(find.text('Sinfing uchun soʻrov · 5 ta savol'), findsOneWidget);
    expect(find.text('Dilnoza opa yubordi'), findsNWidgets(2));

    await tester.tap(find.text('Tayinlangan soʻrov · 3 ta savol'));
    await settleG5(tester);

    expect(find.text('Kayfiyat va doʻstlar'), findsOneWidget);
  });

  testWidgets('H01: ochiq test yo\'q — ro\'yxat ko\'rinmaydi', (tester) async {
    await _pump(tester, GrowthV5Routes.voice, psychAssignments: const []);

    expect(find.textContaining('ta savol'), findsNothing);
    expect(find.text('Oylik anonim soʻrov'), findsOneWidget);
  });

  testWidgets('H02 → H03 → H09: o\'tkazilgan savol yuborilmaydi', (
    tester,
  ) async {
    final env = await _pump(tester, GrowthV5Routes.voiceSurvey);

    expect(find.text('Javoblaring ismingga bogʻlanmaydi.'), findsOneWidget);
    await tester.tap(find.text('Boshlash'));
    await settleG5(tester);

    // Javob tanlanmaguncha «Keyingi savol» yopiq.
    await tester.tap(find.text('Keyingi savol'));
    await settleG5(tester);
    expect(
      find.text('Maktabda oʻzingni xotirjam his qilasanmi?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Asosan ha'));
    await tester.pump();
    await tester.tap(find.text('Keyingi savol'));
    await settleG5(tester);
    await tester.tap(find.text('Oʻtkazib yuborish'));
    await settleG5(tester);
    await tester.tap(find.text('Ha, juda'));
    await tester.pump();
    await settleG5(tester);
    await tester.tap(find.text('Yakunlash'));
    await settleG5(tester);

    expect(env.voice.submittedSurveys.single.answers, {'q1': 4, 'q3': 5});
    expect(find.text('Rahmat!'), findsOneWidget);
    expect(find.text('Javoblaring anonim saqlandi.'), findsOneWidget);
    expect(find.text('Shaxsiy yordam soʻrash'), findsOneWidget);
  });

  testWidgets('H03: saqlanmasa «Rahmat» ko\'rsatilmaydi, qayta urinish bor', (
    tester,
  ) async {
    final voice = FakeVoiceRepository(survey: kVoiceSurvey(), offline: true);
    await _pump(tester, GrowthV5Routes.voiceSurveyRun, voice: voice);

    await tester.tap(find.text('Qisman'));
    await tester.pump();
    await tester.tap(find.text('Keyingi savol'));
    await settleG5(tester);
    await tester.tap(find.text('Oʻtkazib yuborish'));
    await settleG5(tester);
    await tester.tap(find.text('Oʻtkazib yuborish'));
    await settleG5(tester);

    expect(find.text('Rahmat!'), findsNothing);
    expect(find.textContaining('Saqlanmadi'), findsOneWidget);

    voice.offline = false;
    await tester.tap(find.text('Qayta urinish'));
    await settleG5(tester);
    expect(voice.submittedSurveys.single.answers, {'q1': 3});
    expect(find.text('Rahmat!'), findsOneWidget);
  });

  testWidgets('H04: psixolog, ish vaqti, o\'rinbosar va tayinlangan so\'rov', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.voiceHelp);

    expect(find.text('Dilnoza opa'), findsOneWidget);
    expect(find.text('Masʼul psixolog'), findsOneWidget);
    expect(find.text('Dushanba–juma · 09:00–17:00'), findsOneWidget);
    expect(find.textContaining('oʻrinbosar Kamola opa'), findsOneWidget);
    expect(find.text('Tayinlangan soʻrov · 3 ta savol'), findsOneWidget);
  });

  testWidgets(
    'H05 → H07: internet yo\'q — navbatda qoladi, qayta urinishda yuboriladi',
    (tester) async {
      final voice = FakeVoiceRepository(contact: kVoiceContact, offline: true);
      final env = await _pump(
        tester,
        GrowthV5Routes.voiceCompose,
        voice: voice,
      );

      await tester.enterText(find.byType(TextField), 'Menga yordam kerak');
      await tester.tap(find.byType(GSwitch));
      await tester.pump();
      await tester.tap(find.text('Yuborish'));
      await settleG5(tester);

      expect(find.text('Xabaring hali yuborilmadi'), findsOneWidget);
      expect(
        find.text(
          'Shoshilinch boʻlsa, hoziroq yaqiningdagi ishonchli kattaga ayt.',
        ),
        findsOneWidget,
      );
      expect(env.store.values.values.single, contains('Menga yordam kerak'));

      voice.offline = false;
      await tester.tap(find.text('Qayta urinish'));
      await settleG5(tester);

      expect(voice.created.single.urgent, isTrue);
      expect(env.store.values, isEmpty);
      expect(find.text('Murojaat qabul qilindi'), findsOneWidget);
      expect(find.text('Psixolog hali ochmagan'), findsOneWidget);
    },
  );

  testWidgets('H06: neytral sarlavhalar va holatlar', (tester) async {
    await _pump(tester, GrowthV5Routes.voiceRequests);

    expect(find.text('Murojaat · 3-noyabr'), findsOneWidget);
    expect(find.text('Qabul qilindi'), findsOneWidget);
    expect(find.text('Koʻrib chiqilmoqda'), findsOneWidget);
    expect(find.text('Javob keldi · 1 ta yangi xabar'), findsOneWidget);
    // Matn ro'yxatda ko'rinmaydi.
    expect(find.textContaining('xavotirdaman'), findsNothing);
  });

  testWidgets('H07: psixolog ochgan murojaat — «ko\'rib chiqmoqda»', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.voiceRequest('r2'));

    expect(find.text('Murojaat qabul qilindi'), findsOneWidget);
    expect(find.text('Psixolog koʻrib chiqmoqda'), findsOneWidget);
    expect(find.text('Psixolog hali ochmagan'), findsNothing);
  });

  testWidgets('H08: yozishma va javob yuborish', (tester) async {
    final env = await _pump(tester, GrowthV5Routes.voiceRequest('r1'));

    expect(find.text('Psixologning javobi · 28-oktabr, 10:24'), findsOneWidget);
    expect(find.textContaining('Seni tinglashga tayyorman'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ha, kelaman');
    await tester.tap(find.bySemanticsLabel('Yuborish'));
    await settleG5(tester);

    expect(env.voice.sentMessages.single, (
      requestId: 'r1',
      text: 'Ha, kelaman',
    ));
    expect(find.text('Ha, kelaman'), findsOneWidget);
  });

  testWidgets('H10: o\'tkazish mumkin, faqat javob berilganlar yuboriladi', (
    tester,
  ) async {
    final env = await _pump(tester, GrowthV5Routes.voicePersonal('p1'));

    expect(find.text('Dilnoza opa tayinlagan'), findsOneWidget);
    expect(
      find.text('Javoblaringni masʼul mutaxassis koʻradi.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Boshlash'));
    await settleG5(tester);

    await tester.tap(find.text('Savolni oʻtkazish'));
    await settleG5(tester);
    await tester.tap(find.text('Yolgʻiz oʻtiraman'));
    await tester.pump();
    await tester.tap(find.text('Keyingi savol'));
    await settleG5(tester);
    await tester.tap(find.text('Koʻpincha'));
    await tester.pump();
    await tester.tap(find.text('Yakunlash'));
    await settleG5(tester);

    final answers = env.school.submittedAnswers!;
    expect(answers.keys, unorderedEquals(['i2', 'i3']));
    expect((answers['i2']! as PsychSingleAnswer).key, 'b');
    expect((answers['i3']! as PsychLikertAnswer).value, 4);
    expect(
      find.text('Rahmat! Javoblaring mutaxassisga yuborildi.'),
      findsOneWidget,
    );
  });

  test('VoiceRequest parsing: bosqich, handler va xabarlar tartibi', () {
    final r = VoiceRequest.tryFromJson({
      'id': 'x',
      'urgency': 'URGENT',
      'stage': 'REPLIED',
      'createdAt': '2026-11-05T04:00:00.000Z',
      'handler': {'name': 'Kamola opa', 'isDeputy': true},
      'messages': [
        {
          'id': 'b',
          'author': 'STAFF',
          'text': 'Salom',
          'createdAt': '2026-11-05T06:00:00.000Z',
        },
        {
          'id': 'a',
          'author': 'CHILD',
          'text': 'Yordam',
          'createdAt': '2026-11-05T04:00:00.000Z',
        },
        {
          'id': 'c',
          'author': 'CHILD',
          'text': '  ',
          'createdAt': '2026-11-05T07:00:00.000Z',
        },
      ],
    })!;
    expect(r.urgent, isTrue);
    expect(r.stage, VoiceStage.replied);
    expect(r.handlerIsDeputy, isTrue);
    expect(r.messages.map((m) => m.id), ['a', 'b']);
  });
}

const _classSummary = PsychAssignmentSummary(
  assignmentId: 'c1',
  testId: 't-class',
  kind: PsychKind.emotional,
  title: 'Sinf kayfiyati',
  description: '',
  itemCount: 5,
  assignedByName: 'Dilnoza opa',
  estimatedMinutes: 4,
);

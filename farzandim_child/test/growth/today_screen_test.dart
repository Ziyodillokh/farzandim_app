// B01 · Bugun: kunlik reja holatlari, salomlashuv, aloqa ikonlari (G08),
// boshlash tugmasi, maktab kartasi.

import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/growth/bugun/widgets/contact_tiles.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/learning/fake_learning_repository.dart';
import '../features/school/fake_school_repository.dart';
import '../features/learning/learning_fixtures.dart';
import 'fake_school_v5.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

const _profile = LearningProfile(
  grade: 6,
  subjects: [Subject.math, Subject.english, Subject.native],
);

FakeLearningRepository _repo({
  LearningProfile? profile = _profile,
  bool englishDone = true,
}) => FakeLearningRepository(
  profile: profile,
  clock: () => kG5Now,
  results: [
    if (englishDone)
      result(Subject.english, 9, kG5Now.subtract(const Duration(hours: 1))),
  ],
);

void main() {
  setUpAll(setUpG5WidgetTests);

  testWidgets('reja: bajarilgan fan, navbatdagi fan va boshlash tugmasi', (
    tester,
  ) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(learning: _repo()),
    );

    expect(find.text('Xayrli tong,'), findsOneWidget);
    expect(find.text('Aziza!'), findsOneWidget);
    expect(find.text('480'), findsOneWidget);
    expect(find.text('Yana 2 ta fan'), findsOneWidget);
    expect(find.text('9 ta toʻgʻri · 10 savol'), findsOneWidget);
    expect(find.text('Navbatda'), findsOneWidget);
    expect(find.text('Matematikani boshlash'), findsOneWidget);
    // 2 ta fan × (10 × 2 + 10) — server qoidasidagi eng ko'p DON.
    expect(find.text('+60 DON gacha'), findsOneWidget);
  });

  testWidgets(
    'birinchi kirish: fanlar tanlanmagan — 15 daqiqalik reja taklifi',
    (tester) async {
      await pumpG5App(
        tester,
        routes: buildGrowthV5Routes(),
        initialLocation: GrowthV5Routes.today,
        overrides: g5Overrides(learning: _repo(profile: null)),
      );

      expect(find.text('Bugungi 15 daqiqa'), findsOneWidget);
      expect(find.text('Boshlash'), findsOneWidget);
    },
  );

  testWidgets('hamma fan bajarilgan: «Bugungi vazifa bajarildi»', (
    tester,
  ) async {
    final repo = FakeLearningRepository(
      profile: const LearningProfile(grade: 6, subjects: [Subject.english]),
      clock: () => kG5Now,
      results: [
        result(Subject.english, 9, kG5Now.subtract(const Duration(hours: 1))),
      ],
    );
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(learning: repo),
    );

    expect(find.text('Bugungi vazifa bajarildi'), findsOneWidget);
    expect(find.text('Yana mashq qilish'), findsOneWidget);
  });

  testWidgets('«Matematikani boshlash» mashqni ochadi', (tester) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(learning: _repo()),
    );

    await tester.ensureVisible(find.text('Matematikani boshlash'));
    await tester.tap(find.text('Matematikani boshlash'));
    await settleG5(tester);

    // push URL'ni o'zgartirmaydi (go_router) — ochilgan ekranni tekshiramiz.
    final practice = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(practice.subject, Subject.math);
    expect(find.text('1 + 2 = ?'), findsOneWidget);
  });

  testWidgets('maktabga ulanmagan bola: «Maktabga ulanish» kartasi', (
    tester,
  ) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(learning: _repo()),
    );

    await tester.scrollUntilVisible(
      find.text('Maktabga ulanish'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Shaxsiy mashq ochiq'), findsOneWidget);
  });

  testWidgets('ism yo\'q bo\'lsa «doʻstim» deb salomlashadi', (tester) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(learning: _repo(), childName: null),
    );

    expect(find.text('doʻstim!'), findsOneWidget);
  });

  testWidgets('320px va 1.3 shriftda toshib ketmaydi', (tester) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(learning: _repo()),
      size: const Size(320, 640),
      textScale: 1.3,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await settleG5(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'G08: aloqa sarlavhada — Ota-onam, Bola ovozi, bildirishnomalar',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpG5App(
        tester,
        routes: buildGrowthV5Routes(),
        initialLocation: GrowthV5Routes.today,
        overrides: [
          ...g5Overrides(
            learning: _repo(),
            unread: 2,
            school: FakeSchoolRepository(
              today: kSchoolToday,
              clock: () => kG5Now,
            ),
            schoolAccount: 'child-1',
          ),
          parentChatUnreadProvider.overrideWithValue(3),
        ],
      );

      expect(
        find.bySemanticsLabel('Ota-onam, 3 ta yangi xabar'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('^Bola ovozi')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Bildirishnomalar, 2 ta yangi'),
        findsOneWidget,
      );
      // Katta «Aloqa» kartalari B01 da endi yo'q.
      expect(find.text('Aloqa'), findsNothing);
      expect(find.text('Yozish'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('G08: 320px va 1.3 shriftda uchala ikon bilan toshib ketmaydi', (
    tester,
  ) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(
        learning: _repo(),
        unread: 2,
        school: FakeSchoolRepository(today: kSchoolToday, clock: () => kG5Now),
        schoolAccount: 'child-1',
      ),
      size: const Size(320, 640),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
  });
}

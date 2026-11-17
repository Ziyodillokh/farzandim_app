// I01–I09 · «Men»: profil, shaxsiy o'sish, DON tarixi, daraja va nishonlar,
// sozlamalar, ruxsatlar, bildirishnomalar, yordam, maxfiylik (soxta manbalar).

import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/men/data/men_device.dart';
import 'package:farzandim_child/growth/men/data/men_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/learning/fake_learning_repository.dart';
import '../features/school/fake_school_repository.dart';
import 'fake_men.dart';
import 'fake_school_v5.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

Future<FakeMenRepository> _pump(
  WidgetTester tester,
  String location, {
  FakeMenRepository? men,
}) async {
  final repo = men ?? kFakeMen();
  await pumpG5App(
    tester,
    routes: buildGrowthV5Routes(),
    initialLocation: location,
    overrides: [
      ...g5Overrides(
        learning: FakeLearningRepository(clock: () => kG5Now),
        school: FakeSchoolRepository(today: kSchoolToday, clock: () => kG5Now),
        schoolAccount: 'child-1',
      ),
      ...menOverrides(repo),
    ],
  );
  return repo;
}

void main() {
  setUpAll(setUpG5WidgetTests);

  test('DON darajasi: har 150 DON — yangi daraja', () {
    expect(donLevel(0), 1);
    expect(donLevel(149), 1);
    expect(donLevel(150), 2);
    expect(donLevel(480), 4);
    expect(donToNextLevel(480), 120);
    expect(donLevelProgress(480), closeTo(.2, 1e-9));
    expect(donLevel(-5), 1);
  });

  testWidgets('I01: profil, sinf, DON darajasi, seriya va ruxsatlar', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.me);

    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text('6-B sinf · 24-maktab'), findsOneWidget);
    expect(find.text('4-daraja'), findsOneWidget);
    expect(find.text('7 kun'), findsOneWidget);
    expect(find.text('2 ta yoqilgan'), findsOneWidget);
    expect(find.text('Til: Oʻzbekcha'), findsOneWidget);
  });

  testWidgets('I02: avvalgi hafta → bu hafta', (tester) async {
    await _pump(tester, GrowthV5Routes.meGrowth);

    expect(find.text('Avvalgi hafta'), findsOneWidget);
    expect(find.text('Bu hafta'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
    expect(find.text('68'), findsOneWidget);
    expect(find.text('+16'), findsOneWidget);
  });

  testWidgets('I02: birinchi hafta — boshlang\'ich nuqta', (tester) async {
    final men = kFakeMen()
      ..weekly = WeeklyActivity(
        current: WeekActivity(
          weekStart: DateTime(2026, 11, 2),
          sessions: 2,
          minutes: 18,
          activeDays: 2,
          streak: 2,
        ),
        firstWeek: true,
      );
    await _pump(tester, GrowthV5Routes.meGrowth, men: men);

    expect(find.text('Birinchi hafta — boshlangʻich nuqta'), findsOneWidget);
    expect(find.text('Avvalgi hafta'), findsNothing);
  });

  testWidgets('I03: tasdiqlangan balans va yozuvlar nomi', (tester) async {
    await _pump(tester, GrowthV5Routes.meDon);

    expect(find.text('480 DON'), findsOneWidget);
    expect(find.text('0 DON'), findsOneWidget);
    expect(find.text('Matematika mashqi'), findsOneWidget);
    expect(find.text('Qadamlar'), findsOneWidget);
    // Audiokitob yozuvi — audio / video yashirin paytda ko'rinmaydi.
    expect(find.text('Oʻrmon sirlari'), findsNothing);
    expect(find.text('+16'), findsOneWidget);
  });

  testWidgets('I06: daraja halqasi va nishonlar (olingan / qulf)', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.meLevel);

    expect(find.text('4-daraja'), findsOneWidget);
    expect(find.text('5-darajagacha 120 DON'), findsOneWidget);
    expect(find.bySemanticsLabel('7 kunlik seriya: Olingan'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Olimpiadachi: Hali olinmagan'),
      findsOneWidget,
    );
  });

  testWidgets('I04: matn o\'lchami tanlanadi va saqlanadi', (tester) async {
    await _pump(tester, GrowthV5Routes.meSettings);

    expect(
      find.text('Galaxy A15 · Akkaunting shu qurilmada ochiq.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Katta'));
    await settleG5(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GScreen).first),
    );
    expect(container.read(g5TextSizeProvider).valueOrNull, G5TextSize.large);
  });

  testWidgets('I05: holatlar va tafsilot shu yerda ochiladi', (tester) async {
    await _pump(tester, GrowthV5Routes.mePermissions);

    expect(find.text('Yoqilgan'), findsNWidgets(2));
    expect(find.text('Oʻchirilgan'), findsOneWidget);
    expect(find.text('Mavjud emas'), findsOneWidget);
    await tester.tap(find.text('Joylashuv'));
    await settleG5(tester);
    expect(
      find.text('Telefon joylashuvi: harakatlanganda va har 15 daqiqada.'),
      findsOneWidget,
    );
  });

  testWidgets('I07: kalit saqlanadi; saqlanmasa avvalgi holat qaytadi', (
    tester,
  ) async {
    final men = await _pump(tester, GrowthV5Routes.meNotifications);

    Finder toggle(String label) =>
        find.byWidgetPredicate((w) => w is GSwitch && w.semanticLabel == label);
    await tester.scrollUntilVisible(
      find.text('Matnni yashirish'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(toggle('Matnni yashirish'));
    await settleG5(tester);
    expect(men.saved.single.hideText, isFalse);

    men.failSave = true;
    await tester.scrollUntilVisible(
      find.text('Oila xabarlari'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(toggle('Oila xabarlari'));
    await settleG5(tester);
    expect(find.text('Saqlanmadi. Internetni tekshir.'), findsOneWidget);
    expect(men.prefs.familyMessages, isTrue);
  });

  testWidgets('I08: «Ishonchli katta kim?» ochiq, boshqasi bosilsa ochiladi', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.meHelp);

    expect(find.textContaining('Sen ishonadigan katta odam'), findsOneWidget);
    await tester.tap(find.text('Kira olmayapman'));
    await settleG5(tester);
    expect(find.textContaining('qayta ulashini soʻra'), findsOneWidget);
  });

  testWidgets('I09: rozilik sanasi; o\'chirish so\'rovi tasdiqdan keyin', (
    tester,
  ) async {
    final men = await _pump(tester, GrowthV5Routes.mePrivacy);

    expect(find.text('Ota-onang rozilik bergan · 3-sentabr'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Yuborish'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Yuborish'));
    await settleG5(tester);
    await tester.tap(find.text('Yuborish').last);
    await settleG5(tester);

    expect(men.deletion, isNotNull);
    expect(
      find.textContaining('Soʻrov qabul qilindi — ota-onang va maktab'),
      findsOneWidget,
    );
  });
}

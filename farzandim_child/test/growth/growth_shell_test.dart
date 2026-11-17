// Growth v5 karkasi: to'rt tab, tab almashishi, galereya va kichik ekran / katta shrift.

import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/bugun/today_screen.dart';
import 'package:farzandim_child/growth/dev/kit_gallery_screen.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/learning/fake_learning_repository.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

void main() {
  setUpAll(setUpG5WidgetTests);

  testWidgets('to\'rt tab ko\'rinadi va Bugun faol', (tester) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(
        learning: FakeLearningRepository(clock: () => kG5Now),
      ),
    );

    for (final label in ['Bugun', 'Oʻqish', 'Maktab', 'Men']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    final bar = tester.widget<GTabBar>(find.byType(GTabBar));
    expect(bar.currentIndex, 0);
  });

  testWidgets('Maktab tabi bosilsa /maktab ochiladi', (tester) async {
    final router = await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(
        learning: FakeLearningRepository(clock: () => kG5Now),
      ),
    );

    await tester.tap(
      find.descendant(of: find.byType(GTabBar), matching: find.text('Maktab')),
    );
    await settleG5(tester);

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      GrowthV5Routes.school,
    );
    expect(tester.widget<GTabBar>(find.byType(GTabBar)).currentIndex, 2);
  });

  testWidgets('galereya 320px va 1.3 shriftda toshib ketmaydi', (tester) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.kit,
      size: const Size(320, 640),
      textScale: 1.3,
    );

    expect(find.byType(KitGalleryScreen), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await settleG5(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('galereyadagi tanlovlar holatni o\'zgartiradi', (tester) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.kit,
    );

    final age = find.byType(GStepper);
    // ListView elementni faqat yaqinlashganda quradi; keyin yuqoriga olib
    // chiqamiz — dock ostida qolmasin.
    await tester.scrollUntilVisible(
      age,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(age);
    await settleG5(tester);
    await tester.tap(find.bySemanticsLabel('Yoshni oshirish'));
    await settleG5(tester);
    expect(tester.widget<GStepper>(age).value, 13);

    await tester.tap(find.text('Qiz'));
    await settleG5(tester);
    final gender = tester.widget<GSegmented<String>>(
      find.byWidgetPredicate(
        (w) => w is GSegmented<String> && w.options.contains('Qiz'),
      ),
    );
    expect(gender.selected, 'Qiz');
  });

  testWidgets('tab ildizidan ochilgan varaq menyu ustida turadi', (
    tester,
  ) async {
    await pumpG5App(
      tester,
      routes: buildGrowthV5Routes(),
      initialLocation: GrowthV5Routes.today,
      overrides: g5Overrides(
        learning: FakeLearningRepository(clock: () => kG5Now),
      ),
    );

    final context = tester.element(find.byType(TodayScreen));
    showGSheet<void>(
      context,
      builder: (_) => GButton(label: 'Varaqdagi tugma', onPressed: () {}),
    );
    await settleG5(tester);

    expect(find.text('Varaqdagi tugma').hitTestable(), findsOneWidget);
  });
}

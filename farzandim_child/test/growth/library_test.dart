// U11 kutubxona (guruhlar, qidiruv, filtrni tozalash), U12 audiokitob va
// U14 maqola — tarmoqsiz soxta ma'lumot va soxta pleyer bilan.

import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/oqish/library/audiobook_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:farzandim_child/growth/oqish/learn/learn_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'fake_library.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

Future<({FakeLibPlayer player, FakeLibArticles articles})> _pump(
  WidgetTester tester,
  String location,
) async {
  final player = FakeLibPlayer();
  final articles = FakeLibArticles();
  await pumpG5App(
    tester,
    routes: buildGrowthV5Routes(),
    initialLocation: location,
    overrides: [
      ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
      ...libraryOverrides(player: player, articles: articles),
    ],
  );
  return (player: player, articles: articles);
}

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Audio / video yashirin (egasi, 2026-11-07): kutubxona ochilmaydi.
  testWidgets('kutubxona havolasi O\'qish markaziga tushadi', (tester) async {
    await _pump(tester, GrowthV5Routes.library);
    expect(find.byType(AudiobookScreen), findsNothing);
    expect(find.text('Oʻrmon sirlari'), findsNothing);
    expect(find.byType(LearnScreen), findsOneWidget);
  }, skip: kShowAudioVideo);

  group('kutubxona (audio / video ko\'rinadigan paytda)', () {
    testWidgets('U11: guruhlar — seriya bitta qator, video va maqola', (
      tester,
    ) async {
      await _pump(tester, GrowthV5Routes.library);

      expect(find.text('Oʻrmon sirlari'), findsOneWidget);
      expect(find.text('2 bob · 42:00'), findsOneWidget);
      expect(find.text('Kasrlarni taqqoslash'), findsOneWidget);
      expect(find.text('Urugʻ qanday unib chiqadi?'), findsOneWidget);
    });

    testWidgets('U11: qidiruv natijasiz — «Filtrlarni tozalash»', (
      tester,
    ) async {
      await _pump(tester, GrowthV5Routes.library);

      await tester.enterText(find.byType(TextField), 'zzz');
      await settleG5(tester);
      expect(find.text('Hech narsa topilmadi'), findsOneWidget);

      await tester.tap(find.text('Filtrlarni tozalash'));
      await settleG5(tester);
      expect(find.text('Kasrlarni taqqoslash'), findsOneWidget);
    });

    testWidgets('U12: audiokitob ochiladi, «Tinglash» qismni ijro qiladi', (
      tester,
    ) async {
      final fakes = await _pump(tester, GrowthV5Routes.library);

      await tester.tap(find.text('Oʻrmon sirlari'));
      await settleG5(tester);
      expect(find.byType(AudiobookScreen), findsOneWidget);
      expect(find.text('1-bob'), findsWidgets);

      await tester.tap(find.text('Tinglash'));
      await settleG5(tester);
      expect(fakes.player.played, ['b1']);
      expect(find.text('Toʻxtatib turish'), findsOneWidget);
    });

    testWidgets(
      'U14: maqola o\'qildi deb belgilanadi, matn kattalashadi, xatcho\'p',
      (tester) async {
        final fakes = await _pump(tester, GrowthV5Routes.article('a1'));

        expect(find.text('Urugʻ qanday unib chiqadi?'), findsOneWidget);
        expect(find.text('Biologiya · 10–13 yosh · 1 daqiqa'), findsOneWidget);
        expect(fakes.articles.read, ['a1']);

        await tester.tap(find.bySemanticsLabel('Matnni kattalashtirish'));
        await settleG5(tester);
        await tester.tap(find.bySemanticsLabel('Saqlash'));
        await settleG5(tester);
        expect(find.bySemanticsLabel('Saqlangan'), findsOneWidget);
      },
    );
  }, skip: !kShowAudioVideo);
}

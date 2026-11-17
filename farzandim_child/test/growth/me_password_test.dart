// I04b · Parolni almashtirish: tekshiruvlar, noto'g'ri joriy parol, login
// berilmagan akkaunt va muvaffaqiyat (soxta repozitoriy, tarmoqsiz).

import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'fake_kirish.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

Future<FakeKirishRepository> _pump(
  WidgetTester tester, {
  KirishException? error,
}) async {
  final repo = FakeKirishRepository()..passwordError = error;
  await pumpG5App(
    tester,
    routes: buildGrowthV5Routes(),
    initialLocation: GrowthV5Routes.mePassword,
    overrides: [
      ...g5Overrides(learning: FakeLearningRepository(clock: () => kG5Now)),
      ...kirishOverrides(
        repo: repo,
        registry: AccountRegistry(MemoryAccountStore()),
      ),
    ],
  );
  await settleG5(tester);
  return repo;
}

Future<void> _fill(
  WidgetTester tester, {
  required String current,
  required String next,
  String? repeat,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), current);
  await tester.pump();
  await tester.enterText(fields.at(1), next);
  await tester.pump();
  await tester.enterText(fields.at(2), repeat ?? next);
  await tester.pump();
  await tester.tap(find.text('Saqlash'));
  await settleG5(tester);
}

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('parollar mos kelmasa — serverga yuborilmaydi', (tester) async {
    final repo = await _pump(tester);
    await _fill(
      tester,
      current: 'Eski2026x',
      next: 'Kitob2026y',
      repeat: 'Kitob2026z',
    );

    expect(find.text('Parollar bir xil emas'), findsOneWidget);
    expect(repo.passwordChanges, isEmpty);
  });

  testWidgets('joriy parol noto\'g\'ri', (tester) async {
    await _pump(
      tester,
      error: const KirishException(KirishError.invalidCredentials),
    );
    await _fill(tester, current: 'Eski2026x', next: 'Kitob2026y');

    expect(find.text('Joriy parol notoʻgʻri'), findsOneWidget);
  });

  testWidgets('login berilmagan akkaunt — kim berishi aytiladi', (
    tester,
  ) async {
    await _pump(tester, error: const KirishException(KirishError.noCredential));
    await _fill(tester, current: 'Eski2026x', next: 'Kitob2026y');

    expect(find.textContaining('login va parol yoʻq'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('muvaffaqiyat — parol almashadi', (tester) async {
    final repo = await _pump(tester);
    await _fill(tester, current: 'Eski2026x', next: 'Kitob2026y');

    expect(repo.passwordChanges, [('Eski2026x', 'Kitob2026y')]);
    expect(
      find.text(
        'Parol oʻzgartirildi. Boshqa qurilmalarda yangi parol bilan kir.',
      ),
      findsOneWidget,
    );
  });
}

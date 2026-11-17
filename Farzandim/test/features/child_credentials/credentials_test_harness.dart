// Kirish ma'lumotlari ekranini sinash uchun umumiy asos: HAQIQIY uz
// tarjimalari yuklanadi (matn va o'rin-bosarlar `{name}` aynan ekrandagidek
// tekshiriladi), clipboard va "Ulashish" kanalsiz almashtiriladi.

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
// Testda tarjimalarni to'g'ridan-to'g'ri yuklash uchun (ichki sinflar).
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_credentials/data/child_credentials_repository.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/child_credentials/presentation/screens/child_credentials_screen.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_credentials_repository.dart';

/// `setUpAll` ichida chaqiriladi: ilovadagi haqiqiy o'zbekcha matnlar.
void loadUzbekTranslations() {
  final json =
      jsonDecode(File('assets/translations/uz.json').readAsStringSync())
          as Map<String, dynamic>;
  Localization.load(const Locale('uz'), translations: Translations(json));
}

/// Kalit bo'yicha ekrandagi matn (o'rin-bosarlari bilan).
String t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

const kChildId = 'kid-1';
const kChildName = 'Aziza';

Child testChild() => Child(
  id: kChildId,
  name: kChildName,
  age: 9,
  gender: Gender.female,
  region: 'Toshkent',
  familyCode: '12345',
  createdAt: DateTime(2026, 10),
);

/// Ekran va uning atrofidagi kuzatuv vositalari.
class CredentialsHarness {
  CredentialsHarness(this.tester, this.repo);

  final WidgetTester tester;
  final FakeCredentialsRepository repo;

  /// Clipboard'ga yozilgan matnlar (tartib bilan); oxirgisi — hozirgi bufer.
  final List<String> clipboard = [];

  /// Buferda hozir turgan matn (yozilmagan bo'lsa `null`).
  String? get currentClipboard => clipboard.isEmpty ? null : clipboard.last;

  /// "Ulashish" oynasiga berilgan matnlar.
  final List<({String text, String? subject})> shared = [];

  /// Berilsa, "Ulashish" shuni otadi (platforma yo'q holati).
  Exception? shareError;

  /// Berilsa, buferga yozish shu platforma xatosi bilan yiqiladi.
  PlatformException? clipboardError;

  /// "Ulashish" oynasi natijasi: `true` — ilova tanlandi, `false` — oyna
  /// yopildi yoki natija noma'lum.
  bool shareResult = true;

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

/// Ekranni ochadi. [withChild] `false` — bola ro'yxatda yo'q (push'dan sovuq
/// start): ism "Bola" bo'lib qoladi.
Future<CredentialsHarness> pumpCredentialsScreen(
  WidgetTester tester,
  FakeCredentialsRepository repo, {
  bool withChild = true,
  bool settle = true,
}) async {
  final harness = CredentialsHarness(tester, repo);

  // Balandroq ekran: varaq tepasida fon (barrier) qolsin. Kenglik 800:
  // testda matn "Ahem" shriftida (har harf kvadrat) chiziladi — tor ekranda
  // haqiqiy shriftda sig'adigan matn ham toshib ketgandek ko'rinardi.
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(800, 1400);
  addTearDown(tester.view.reset);

  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          if (harness.clipboardError case final error?) throw error;
          final args = call.arguments as Map<Object?, Object?>;
          harness.clipboard.add(args['text']! as String);
        case 'Clipboard.getData':
          final text = harness.currentClipboard;
          return text == null ? null : <String, Object?>{'text': text};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  final router = GoRouter(
    initialLocation: AppRoutes.childCredentialsPath(kChildId),
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, _) => const Text('dashboard'),
      ),
      GoRoute(
        path: AppRoutes.childCredentialsPattern,
        builder: (_, state) =>
            ChildCredentialsScreen(childId: state.pathParameters['childId']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  final child = withChild ? testChild() : null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        childCredentialsRepositoryProvider.overrideWithValue(repo),
        childByIdProvider.overrideWith((ref, id) => child),
        childAvatarUrlProvider.overrideWith((ref, id) async => null),
        shareTextProvider.overrideWithValue((text, {subject}) async {
          harness.shared.add((text: text, subject: subject));
          if (harness.shareError case final error?) throw error;
          return harness.shareResult;
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return harness;
}

/// Toast taymerlarini tugatadi (aks holda test oxirida "Timer pending").
Future<void> drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Matnli tugmani bosadi va animatsiyalarni tugatadi.
Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Ochiq oynadagi (AlertDialog) matnli tugmani bosadi: tugma yorlig'i
/// ekrandagi boshqa tugma bilan bir xil bo'lishi mumkin ("Rad etish").
Future<void> tapInDialog(WidgetTester tester, String text) async {
  await tester.tap(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text)),
  );
  await tester.pumpAndSettle();
}

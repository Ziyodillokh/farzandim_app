// SchoolLinkScreen: 6 xonali raqamli o'quvchi kodi (bosh nol bilan) va 8
// belgili vasiy kodi bitta maydonda. Raqam kiritilganda raqamli klaviatura,
// harf paydo bo'lsa yoki "ABC" bosilsa — harfli; yopishtirilgan xabardan
// kod ajratiladi; yaroqsiz kod yuborilmaydi; xato maydon ostida chiqadi.
// QR: faqat Parvoz havolasi darrov yuboriladi, xom kod maydonga yoziladi va
// ota-ona "Ulanish"ni bosadi.

import 'package:dio/dio.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/invite_code.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/screens/school_link_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  /// Yuborilgan kodlar (haqiqiy repository kabi normallashtirilgan) —
  /// tartib bilan.
  final List<String> redeemed = [];

  /// Berilsa, `redeemInvite` shuni otadi.
  SchoolFailure? failure;

  @override
  Future<SchoolLinks> redeemInvite(String rawCode) async {
    redeemed.add(InviteCode.normalize(rawCode));
    final error = failure;
    if (error != null) throw error;
    return SchoolLinks.empty;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeSchoolRepository repo, {
  WidgetBuilder? scanner,
  String? location,
}) async {
  final router = GoRouter(
    initialLocation: location ?? AppRoutes.schoolLink,
    routes: [
      GoRoute(
        path: AppRoutes.schoolLink,
        builder: (_, state) => SchoolLinkScreen(
          scannerBuilder: scanner,
          initialCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: AppRoutes.school,
        builder: (_, _) => const Text('school-home'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [schoolRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Kamerasiz soxta skaner: tugma bosilganda [result] bilan yopiladi.
WidgetBuilder _fakeScanner(ScannedInvite? result) =>
    (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(result),
          child: const Text('fake-scan'),
        ),
      ),
    );

Future<void> _scan(WidgetTester tester) async {
  await tester.tap(find.text('school.link.scan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('fake-scan'));
  await tester.pumpAndSettle();
}

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

Finder get _submit => find.text('school.link.submit');

/// Muvaffaqiyatli ulanish toast'ining taymerini tugatadi.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('6 xonali kod: raqamli klaviatura, bosh nol yuboriladi', (
    tester,
  ) async {
    final repo = _FakeSchoolRepository();
    await _pump(tester, repo);

    // Bo'sh maydon — raqamli klaviatura (6 xonali kod asosiy yo'l).
    expect(_field(tester).keyboardType, TextInputType.number);

    await tester.enterText(find.byType(TextField), '042913');
    await tester.pump();

    expect(find.text('042913'), findsOneWidget);
    expect(_field(tester).keyboardType, TextInputType.number);

    await tester.tap(_submit);
    await tester.pumpAndSettle();

    // Kod satr bo'lib, bosh nol bilan ketadi.
    expect(repo.redeemed, ['042913']);
    expect(find.text('school-home'), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('8 belgili kod avvalgidek: katta harf, "XXXX-XXXX"', (
    tester,
  ) async {
    final repo = _FakeSchoolRepository();
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), 'abcd2345');
    await tester.pump();

    expect(find.text('ABCD-2345'), findsOneWidget);
    // Harf kirgach klaviatura harfli, almashtirgich yo'q.
    expect(_field(tester).keyboardType, TextInputType.visiblePassword);
    expect(find.text('ABC'), findsNothing);
    expect(find.text('123'), findsNothing);

    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(repo.redeemed, ['ABCD2345']);
    await _drain(tester);
  });

  testWidgets('"ABC" / "123" tugmasi klaviaturani almashtiradi', (
    tester,
  ) async {
    await _pump(tester, _FakeSchoolRepository());

    expect(find.text('ABC'), findsOneWidget);
    await tester.tap(find.text('ABC'));
    await tester.pump();

    expect(_field(tester).keyboardType, TextInputType.visiblePassword);
    expect(find.text('123'), findsOneWidget);

    await tester.tap(find.text('123'));
    await tester.pump();

    expect(_field(tester).keyboardType, TextInputType.number);
    expect(find.text('ABC'), findsOneWidget);
  });

  testWidgets('harf o`chirilgach tanlangan harfli klaviatura qoladi', (
    tester,
  ) async {
    await _pump(tester, _FakeSchoolRepository());

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();
    expect(_field(tester).keyboardType, TextInputType.visiblePassword);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // Foydalanuvchi harf yozgan edi — klaviatura birdan o'zgarmaydi.
    expect(_field(tester).keyboardType, TextInputType.visiblePassword);
    expect(find.text('123'), findsOneWidget);
  });

  testWidgets('6 raqamdan kam yoki 7 raqam — yuborilmaydi', (tester) async {
    final repo = _FakeSchoolRepository();
    await _pump(tester, repo);

    for (final text in ['04291', '0429133']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(_submit);
      await tester.pump();
    }

    expect(repo.redeemed, isEmpty);
    expect(find.text('school-home'), findsNothing);
  });

  testWidgets('yopishtirilgan xabardan kod ajratiladi', (tester) async {
    final repo = _FakeSchoolRepository();
    await _pump(tester, repo);

    await tester.enterText(
      find.byType(TextField),
      'Maktab kodi: 042 913. Muddati 24 soat.',
    );
    await tester.pump();

    expect(find.text('042913'), findsOneWidget);

    await tester.tap(_submit);
    await tester.pumpAndSettle();
    expect(repo.redeemed, ['042913']);
    await _drain(tester);
  });

  testWidgets('noto`g`ri kod xatosi maydon ostida, ekran yopilmaydi', (
    tester,
  ) async {
    final repo = _FakeSchoolRepository()
      ..failure = const SchoolFailure(SchoolFailureKind.inviteInvalid);
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(repo.redeemed, ['123456']);
    expect(find.text('school.errors.inviteInvalid'), findsOneWidget);
    expect(find.text('school-home'), findsNothing);

    // Yangi kiritish eski xatoni yo'qotadi.
    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(find.text('school.errors.inviteInvalid'), findsNothing);
  });

  testWidgets('urinishlar juda ko`p (429) — tegishli xabar', (tester) async {
    final repo = _FakeSchoolRepository()
      ..failure = const SchoolFailure(SchoolFailureKind.tooManyAttempts);
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), '654321');
    await tester.pump();
    await tester.tap(_submit);
    await tester.pumpAndSettle();

    expect(find.text('school.errors.tooManyAttempts'), findsOneWidget);
  });
  group('QR skaner', () {
    testWidgets('Parvoz havolasi darrov yuboriladi', (tester) async {
      final repo = _FakeSchoolRepository();
      await _pump(
        tester,
        repo,
        scanner: _fakeScanner((code: '042913', fromLink: true)),
      );

      await _scan(tester);

      expect(repo.redeemed, ['042913']);
      expect(find.text('school-home'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('xom kod faqat maydonga yoziladi — ota-ona tasdiqlaydi', (
      tester,
    ) async {
      final repo = _FakeSchoolRepository();
      await _pump(
        tester,
        repo,
        scanner: _fakeScanner((code: '042913', fromLink: false)),
      );

      await _scan(tester);

      // Begona QR noto'g'ri urinishlar limitini sarflamasin.
      expect(find.text('042913'), findsOneWidget);
      expect(repo.redeemed, isEmpty);
      expect(find.text('school-home'), findsNothing);

      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(repo.redeemed, ['042913']);
      await _drain(tester);
    });

    testWidgets('xom harfli kod: maydon va klaviatura mos, yuborilmaydi', (
      tester,
    ) async {
      final repo = _FakeSchoolRepository();
      await _pump(
        tester,
        repo,
        scanner: _fakeScanner((code: 'ABCD2345', fromLink: false)),
      );

      await _scan(tester);

      expect(find.text('ABCD-2345'), findsOneWidget);
      expect(_field(tester).keyboardType, TextInputType.visiblePassword);
      expect(repo.redeemed, isEmpty);
    });

    testWidgets('skaner natijasiz yopilsa hech narsa o`zgarmaydi', (
      tester,
    ) async {
      final repo = _FakeSchoolRepository();
      await _pump(tester, repo, scanner: _fakeScanner(null));

      await _scan(tester);

      expect(_field(tester).controller!.text, isEmpty);
      expect(repo.redeemed, isEmpty);
    });
  });

  testWidgets('"ABC" tugmasi kamida 48x48 dp va tugma sifatida o`qiladi', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _FakeSchoolRepository());

    final chip = find.byKey(const ValueKey('keyboard-toggle'));
    final size = tester.getSize(chip);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(chip),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'school.link.keyboardLetters',
      ),
    );
    semantics.dispose();
  });

  group('havola (deep link)', () {
    testWidgets(
      'kod maydonga yoziladi, izoh chiqadi — yuborishni ota-ona bosadi',
      (tester) async {
        final repo = _FakeSchoolRepository();
        await _pump(
          tester,
          repo,
          location: AppRoutes.schoolLinkPath(code: 'abcd-2345'),
        );

        expect(_field(tester).controller!.text, 'ABCD-2345');
        expect(find.text('school.link.fromLinkHint'), findsOneWidget);
        // Begona havola ota-onani o'zi bilmagan maktabga ulab qo'ymasin.
        expect(repo.redeemed, isEmpty);

        await tester.tap(_submit);
        await tester.pumpAndSettle();
        expect(repo.redeemed, ['ABCD2345']);
        await _drain(tester);
      },
    );

    testWidgets('yaroqsiz kod e`tiborsiz — maydon bo`sh, izoh yo`q', (
      tester,
    ) async {
      final repo = _FakeSchoolRepository();
      await _pump(tester, repo, location: '/school/link?code=<script>');

      expect(_field(tester).controller!.text, isEmpty);
      expect(find.text('school.link.fromLinkHint'), findsNothing);
    });
  });
}

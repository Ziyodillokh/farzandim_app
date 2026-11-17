// "Kirish ma'lumotlari" ekrani holatlari: berilmagan / berilgan (birinchi
// kirish kutilmoqda va faol) / yuklanmoqda / xato / bo'lim yo'q; login
// nusxalash; bolaning "parolni unutdim" so'rovlari (ro'yxat, rad etish,
// yuklash xatosi). Haqiqiy o'zbekcha matnlar bilan.

import 'dart:async';

import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/recovery_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'credentials_test_harness.dart';
import 'fake_credentials_repository.dart';

void main() {
  setUpAll(loadUzbekTranslations);

  group('holatlar', () {
    testWidgets('login berilmagan: tushuntirish va "Login va parol berish"', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository();
      await pumpCredentialsScreen(tester, repo);

      expect(find.text(t('childCredentials.title')), findsOneWidget);
      expect(find.text(kChildName), findsOneWidget);
      expect(find.text(t('childCredentials.none.title')), findsOneWidget);
      expect(
        find.text(t('childCredentials.none.body', {'name': kChildName})),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.none.action')), findsOneWidget);
      // Berilmagan holatda "yangilash" va login kartasi yo'q.
      expect(find.text(t('childCredentials.card.reset')), findsNothing);
      expect(find.text(t('childCredentials.card.login')), findsNothing);
    });

    testWidgets('berilgan, birinchi kirish kutilmoqda', (tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);

      expect(find.text('aziza.k24'), findsOneWidget);
      expect(
        find.text(t('childCredentials.card.statusPending')),
        findsOneWidget,
      );
      expect(
        find.text(t('childCredentials.card.pendingHint', {'name': kChildName})),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.card.statusActive')), findsNothing);
      expect(
        find.text(t('childCredentials.card.issuedByParent')),
        findsOneWidget,
      );
      // Bola hali kirmagan.
      expect(
        find.text(t('childCredentials.card.neverLoggedIn')),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.card.reset')), findsOneWidget);
      expect(find.text(t('childCredentials.none.action')), findsNothing);
      // Parol kartada hech qachon ko'rinmaydi.
      expect(find.text(repo.password), findsNothing);
    });

    testWidgets('berilgan, faol: oxirgi kirish ko`rinadi', (tester) async {
      final repo = FakeCredentialsRepository(stored: activeCredentials());
      await pumpCredentialsScreen(tester, repo);

      expect(
        find.text(t('childCredentials.card.statusActive')),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.card.statusPending')), findsNothing);
      expect(
        find.text(t('childCredentials.card.pendingHint', {'name': kChildName})),
        findsNothing,
      );
      expect(find.text(t('childCredentials.card.neverLoggedIn')), findsNothing);
      expect(find.text('05.10.2026, 17:45'), findsOneWidget);
      expect(find.text('01.10.2026, 09:00'), findsOneWidget);
    });

    testWidgets('maktab bergan login', (tester) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(issuedBy: CredentialsIssuer.school),
      );
      await pumpCredentialsScreen(tester, repo);

      expect(
        find.text(t('childCredentials.card.issuedBySchool')),
        findsOneWidget,
      );
      expect(
        find.text(t('childCredentials.card.issuedByParent')),
        findsNothing,
      );
    });

    testWidgets('bola ro`yxatda yo`q (push, sovuq start): ism "Bola"', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo, withChild: false);

      final fallback = t('childCredentials.fallbackChildName');
      expect(find.text(fallback), findsWidgets);
      expect(
        find.text(t('childCredentials.card.pendingHint', {'name': fallback})),
        findsOneWidget,
      );
    });

    testWidgets('yuklanmoqda: spinner, so`ng ma`lumot', (tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials())
        ..holdFetch = Completer<void>();
      await pumpCredentialsScreen(tester, repo, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('aziza.k24'), findsNothing);

      repo.holdFetch!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('aziza.k24'), findsOneWidget);
    });

    testWidgets('tarmoq xatosi: sabab va "Qayta urinish" ishlaydi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials())
        ..fetchError = const CredentialsFailure(CredentialsFailureKind.network);
      await pumpCredentialsScreen(tester, repo);

      expect(find.text(t('childCredentials.load.failedTitle')), findsOneWidget);
      expect(find.text(t('errors.noInternet')), findsOneWidget);
      expect(find.text('aziza.k24'), findsNothing);

      repo.fetchError = null;
      await tapText(tester, t('common.retry'));

      expect(find.text('aziza.k24'), findsOneWidget);
      expect(find.text(t('childCredentials.load.failedTitle')), findsNothing);
    });

    testWidgets('bo`lim yo`q (404 code`siz): xabar, qayta urinishsiz', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository()
        ..fetchError = const CredentialsFailure(
          CredentialsFailureKind.unavailable,
          statusCode: 404,
        );
      await pumpCredentialsScreen(tester, repo);

      expect(
        find.text(t('childCredentials.errors.unavailable')),
        findsOneWidget,
      );
      expect(find.text(t('common.retry')), findsNothing);
      expect(find.text(t('childCredentials.none.action')), findsNothing);
    });

    testWidgets('begona bola (403): ruxsat yo`q xabari', (tester) async {
      final repo = FakeCredentialsRepository()
        ..fetchError = const CredentialsFailure(
          CredentialsFailureKind.forbidden,
          statusCode: 403,
        );
      await pumpCredentialsScreen(tester, repo);

      expect(find.text(t('errors.forbidden')), findsOneWidget);
    });
  });

  group('login nusxalash va yangilash', () {
    testWidgets('login nusxalanadi, xabar chiqadi', (tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      final harness = await pumpCredentialsScreen(tester, repo);

      await tester.tap(find.byKey(const ValueKey('card-copy-login')));
      await tester.pump();

      expect(harness.clipboard, ['aziza.k24']);
      expect(find.text(t('childCredentials.card.loginCopied')), findsOneWidget);
      await drainToasts(tester);
    });

    testWidgets('pastga tortib yangilash holatni qayta o`qiydi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);
      expect(repo.credentialFetches, 1);

      // Server holati o'zgardi: bola kirdi.
      repo.stored = activeCredentials();
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
      await tester.pumpAndSettle();

      expect(repo.credentialFetches, 2);
      expect(
        find.text(t('childCredentials.card.statusActive')),
        findsOneWidget,
      );
    });

    testWidgets('yangilash xatosi: oldingi ma`lumot qoladi, xabar chiqadi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);

      repo.fetchError = const CredentialsFailure(
        CredentialsFailureKind.network,
      );
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1200);
      await tester.pumpAndSettle();

      expect(find.text('aziza.k24'), findsOneWidget);
      expect(find.text(t('errors.noInternet')), findsOneWidget);
      await drainToasts(tester);
    });
  });

  group('"parolni unutdim" so`rovlari', () {
    testWidgets('ochiq so`rov: kim, qachon, "Parolni tiklash" va "Rad etish"', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(),
        recovery: [openRecovery()],
      );
      await pumpCredentialsScreen(tester, repo);

      expect(find.text(t('childCredentials.recovery.title')), findsOneWidget);
      expect(
        find.text(
          t('childCredentials.recovery.tileTitle', {'name': kChildName}),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          t('childCredentials.recovery.requestedAt', {
            'time': '06.10.2026, 08:15',
          }),
        ),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.recovery.restore')), findsOneWidget);
      expect(find.text(t('childCredentials.recovery.reject')), findsOneWidget);
      // Ota-ona kanali: "maktab orqali" belgisi yo'q.
      expect(find.text(t('childCredentials.recovery.viaSchool')), findsNothing);
    });

    testWidgets('maktab kanalidagi so`rovda belgi bor', (tester) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(),
        recovery: [openRecovery(channel: RecoveryChannel.school)],
      );
      await pumpCredentialsScreen(tester, repo);

      expect(
        find.text(t('childCredentials.recovery.viaSchool')),
        findsOneWidget,
      );
    });

    testWidgets('so`rov yo`q — bo`lim ko`rinmaydi', (tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);

      expect(find.text(t('childCredentials.recovery.title')), findsNothing);
    });

    testWidgets('yopilgan (tiklangan) so`rov ko`rinmaydi', (tester) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(),
        recovery: const [
          RecoveryRequest(
            id: 'done',
            channel: RecoveryChannel.parent,
            status: RecoveryStatus.restored,
          ),
        ],
      );
      await pumpCredentialsScreen(tester, repo);

      expect(find.text(t('childCredentials.recovery.title')), findsNothing);
    });

    testWidgets(
      'rad etish: tasdiqlashdan keyin yopiladi, ro`yxat yangilanadi',
      (tester) async {
        final repo = FakeCredentialsRepository(
          stored: pendingCredentials(),
          recovery: [
            openRecovery(),
            openRecovery(id: 'r-2'),
          ],
        );
        await pumpCredentialsScreen(tester, repo);
        expect(
          find.text(t('childCredentials.recovery.reject')),
          findsNWidgets(2),
        );

        await tester.tap(
          find.text(t('childCredentials.recovery.reject')).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(t('childCredentials.recovery.rejectTitle')),
          findsOneWidget,
        );
        expect(
          find.text(t('childCredentials.recovery.rejectBody')),
          findsOneWidget,
        );

        await tapInDialog(tester, t('childCredentials.recovery.rejectConfirm'));

        expect(repo.calls, ['reject:r-1']);
        expect(
          find.text(t('childCredentials.recovery.reject')),
          findsOneWidget,
        );
        expect(
          find.text(t('childCredentials.recovery.rejected')),
          findsOneWidget,
        );
        await drainToasts(tester);
      },
    );

    testWidgets('rad etishni bekor qilish — so`rov yuborilmaydi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(),
        recovery: [openRecovery()],
      );
      await pumpCredentialsScreen(tester, repo);

      await tapText(tester, t('childCredentials.recovery.reject'));
      await tapInDialog(tester, t('common.cancel'));

      expect(repo.calls, isEmpty);
      expect(find.text(t('childCredentials.recovery.restore')), findsOneWidget);
    });

    testWidgets('rad etish xatosi: xabar chiqadi, so`rov qoladi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(),
        recovery: [openRecovery()],
      )..rejectError = const CredentialsFailure(CredentialsFailureKind.network);
      await pumpCredentialsScreen(tester, repo);

      await tapText(tester, t('childCredentials.recovery.reject'));
      await tapInDialog(tester, t('childCredentials.recovery.rejectConfirm'));

      expect(find.text(t('errors.noInternet')), findsOneWidget);
      expect(find.text(t('childCredentials.recovery.restore')), findsOneWidget);
      await drainToasts(tester);
    });

    testWidgets(
      'rad etayotganda so`rov allaqachon hal bo`lgan: ro`yxat yangilanadi',
      (tester) async {
        final repo = FakeCredentialsRepository(
          stored: pendingCredentials(),
          recovery: [openRecovery()],
        );
        await pumpCredentialsScreen(tester, repo);

        // Boshqa qurilma/xodim so'rovni hal qilib bo'lgan.
        repo
          ..recovery = const []
          ..rejectError = const CredentialsFailure(
            CredentialsFailureKind.requestGone,
            code: 'ALREADY_RESOLVED',
            statusCode: 409,
          );
        await tapText(tester, t('childCredentials.recovery.reject'));
        await tapInDialog(tester, t('childCredentials.recovery.rejectConfirm'));

        expect(
          find.text(t('childCredentials.errors.requestGone')),
          findsOneWidget,
        );
        expect(find.text(t('childCredentials.recovery.restore')), findsNothing);
        await drainToasts(tester);
      },
    );

    testWidgets('so`rovlar yuklanmadi: ekran ishlaydi, qayta urinish bor', (
      tester,
    ) async {
      final repo =
          FakeCredentialsRepository(
              stored: pendingCredentials(),
              recovery: [openRecovery()],
            )
            ..recoveryError = const CredentialsFailure(
              CredentialsFailureKind.server,
            );
      await pumpCredentialsScreen(tester, repo);

      expect(find.text('aziza.k24'), findsOneWidget);
      expect(
        find.text(t('childCredentials.recovery.loadFailed')),
        findsOneWidget,
      );

      repo.recoveryError = null;
      await tapText(tester, t('common.retry'));

      expect(
        find.text(t('childCredentials.recovery.loadFailed')),
        findsNothing,
      );
      expect(find.text(t('childCredentials.recovery.restore')), findsOneWidget);
    });

    testWidgets('"Qayta urinish" kamida 48x48 dp va tugma sifatida o`qiladi', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repo =
          FakeCredentialsRepository(
              stored: pendingCredentials(),
              recovery: [openRecovery()],
            )
            ..recoveryError = const CredentialsFailure(
              CredentialsFailureKind.server,
            );
      await pumpCredentialsScreen(tester, repo);

      final retry = find.byKey(const ValueKey('recovery-retry'));
      final size = tester.getSize(retry);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(retry),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label: t('common.retry'),
        ),
      );
      semantics.dispose();
    });

    testWidgets('so`rovlar bo`limi backend`da yo`q — jimgina yashiriladi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials())
        ..recoveryError = const CredentialsFailure(
          CredentialsFailureKind.unavailable,
          statusCode: 404,
        );
      await pumpCredentialsScreen(tester, repo);

      expect(find.text('aziza.k24'), findsOneWidget);
      expect(
        find.text(t('childCredentials.recovery.loadFailed')),
        findsNothing,
      );
    });
  });
}

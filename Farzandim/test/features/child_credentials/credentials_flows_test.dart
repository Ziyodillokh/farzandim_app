// Berish va yangilash oqimlari: login maydoni va qoidalari, band login (409),
// tarmoq xatosi, "Boshqa qurilmalardan chiqarish" (standart yoqilgan) va
// parol varag'i (nusxalash, ulashish, bir martalik ko'rsatish, yopishda
// tasdiq, parol hech qayerda saqlanmasligi). Haqiqiy o'zbekcha matnlar bilan.

import 'dart:async';

import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/issue_credentials_sheet.dart';
import 'package:farzandim/features/child_credentials/presentation/widgets/reset_credentials_sheet.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'credentials_test_harness.dart';
import 'fake_credentials_repository.dart';

const _password = 'k7m2xq9p';

Finder get _loginField => find.byType(TextField);
String _loginText(WidgetTester tester) =>
    tester.widget<TextField>(_loginField).controller!.text;

Future<void> _openIssueSheet(WidgetTester tester) =>
    tapText(tester, t('childCredentials.none.action'));

Future<void> _submitIssue(WidgetTester tester) =>
    tapText(tester, t('childCredentials.issue.submit'));

Finder get _revealTitle => find.text(t('childCredentials.reveal.title'));

/// Varaq ichidagi matn: ekrandagi tugma va varaq sarlavhasi ko'pincha bir xil
/// yozilgan ("Login va parol berish", "Parolni tiklash"), shu sabab varaq
/// turi bo'yicha qidiriladi.
Finder _inSheet<T extends Widget>(String text) =>
    find.descendant(of: find.byType(T), matching: find.text(text));

/// Yangilash varag'ining asosiy tugmasi: yorlig'i ekrandagi tugma va varaq
/// sarlavhasi bilan bir xil bo'lgani uchun varaq ichidan topiladi.
Future<void> _submitReset(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ResetCredentialsSheet),
      matching: find.byType(ParvozPrimaryButton),
    ),
  );
  await tester.pumpAndSettle();
}

/// Parol varag'ini "Tayyor" → "Yopish" bilan yopadi (nusxalanmagan holat).
Future<void> _closeRevealWithoutSaving(WidgetTester tester) async {
  await tapText(tester, t('childCredentials.reveal.done'));
  await tapInDialog(tester, t('childCredentials.reveal.confirmClose'));
}

void main() {
  setUpAll(loadUzbekTranslations);

  group('birinchi berish', () {
    testWidgets('loginsiz: parol varag`i ochiladi, ekran yangilanadi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository();
      await pumpCredentialsScreen(tester, repo);

      await _openIssueSheet(tester);
      expect(
        _inSheet<IssueCredentialsSheet>(t('childCredentials.issue.title')),
        findsOneWidget,
      );
      expect(
        find.text(t('childCredentials.issue.subtitle', {'name': kChildName})),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.issue.loginHelp')), findsOneWidget);

      await _submitIssue(tester);

      expect(repo.calls, ['issue:-']);
      // Parol varag'i: login, vaqtinchalik parol va ogohlantirish.
      expect(_revealTitle, findsOneWidget);
      expect(find.text('aziza.k24'), findsWidgets);
      expect(find.text(_password), findsOneWidget);
      expect(find.text(t('childCredentials.reveal.warnTitle')), findsOneWidget);
      // Qurilmalardan chiqarilmagan: qayta ulash eslatmasi yo'q.
      expect(
        find.text(t('childCredentials.reveal.signedOutNote')),
        findsNothing,
      );

      await _closeRevealWithoutSaving(tester);

      // Varaq yopildi, parol ketdi; ekran endi berilgan loginni ko'rsatadi.
      expect(_revealTitle, findsNothing);
      expect(find.text(_password), findsNothing);
      expect(
        find.text(t('childCredentials.card.statusPending')),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.none.action')), findsNothing);
    });

    testWidgets('o`z logini kichik harfga o`tkazilib yuboriladi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository();
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      await tester.enterText(_loginField, 'Aziza.K24');
      await tester.pump();
      expect(_loginText(tester), 'aziza.k24');

      await _submitIssue(tester);

      expect(repo.calls, ['issue:aziza.k24']);
      expect(_revealTitle, findsOneWidget);
    });

    testWidgets('login qoidasi buzilsa: xabar chiqadi, tugma ishlamaydi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository();
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      // Qisqa: yozayotganda qizil xato yo'q, lekin yuborib bo'lmaydi.
      await tester.enterText(_loginField, 'ab');
      await tester.pump();
      expect(find.text(t('childCredentials.login.tooShort')), findsNothing);
      await tester.tap(find.text(t('childCredentials.issue.submit')));
      await tester.pump();
      expect(repo.calls, isEmpty);

      final cases = {
        '1abc': 'childCredentials.login.badStart',
        'ab cd': 'childCredentials.login.badChars',
        'ab-cd': 'childCredentials.login.badChars',
        'a' * 25: 'childCredentials.login.tooLong',
      };
      for (final entry in cases.entries) {
        await tester.enterText(_loginField, entry.key);
        await tester.pump();
        expect(find.text(t(entry.value)), findsOneWidget, reason: entry.key);
        await tester.tap(find.text(t('childCredentials.issue.submit')));
        await tester.pump();
        expect(repo.calls, isEmpty, reason: entry.key);
      }

      // To'g'rilansa xato yo'qoladi va yuborish mumkin.
      await tester.enterText(_loginField, 'aziza_k');
      await tester.pump();
      expect(find.text(t('childCredentials.login.badChars')), findsNothing);
      expect(find.text(t('childCredentials.login.tooLong')), findsNothing);
      await tapText(tester, t('childCredentials.issue.submit'));
      expect(repo.calls, ['issue:aziza_k']);
    });

    testWidgets('band login (409): xato maydon ostida, varaq yopilmaydi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository()
        ..issueError = const CredentialsFailure(
          CredentialsFailureKind.loginTaken,
          code: 'LOGIN_TAKEN',
          statusCode: 409,
        );
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      await tester.enterText(_loginField, 'aziza.k24');
      await tester.pump();
      await _submitIssue(tester);

      expect(
        find.text(t('childCredentials.errors.loginTaken')),
        findsOneWidget,
      );
      expect(find.byType(IssueCredentialsSheet), findsOneWidget);
      expect(_revealTitle, findsNothing);

      // Loginni o'zgartirsa eski xato yo'qoladi; server endi qabul qiladi.
      repo.issueError = null;
      await tester.enterText(_loginField, 'aziza.k25');
      await tester.pump();
      expect(find.text(t('childCredentials.errors.loginTaken')), findsNothing);
      await _submitIssue(tester);

      expect(repo.calls, ['issue:aziza.k24', 'issue:aziza.k25']);
      expect(_revealTitle, findsOneWidget);
    });

    testWidgets('tarmoq xatosi: sabab ko`rinadi, qayta urinish mumkin', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository()
        ..issueError = const CredentialsFailure(CredentialsFailureKind.network);
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      await _submitIssue(tester);
      expect(find.text(t('errors.noInternet')), findsOneWidget);
      expect(_revealTitle, findsNothing);

      repo.issueError = null;
      await _submitIssue(tester);
      expect(_revealTitle, findsOneWidget);
      expect(repo.calls, ['issue:-', 'issue:-']);
    });

    testWidgets('server yozilgan loginni rad etdi (400): login haqida xabar', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository()
        ..issueError = const CredentialsFailure(
          CredentialsFailureKind.validation,
          statusCode: 400,
        );
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      await tester.enterText(_loginField, 'aziza.k24');
      await tester.pump();
      await _submitIssue(tester);

      expect(
        find.text(t('childCredentials.login.invalidFormat')),
        findsOneWidget,
      );
    });

    testWidgets('boshqa xatolar o`z xabari bilan (429, 500)', (tester) async {
      final repo = FakeCredentialsRepository()
        ..issueError = const CredentialsFailure(
          CredentialsFailureKind.tooManyAttempts,
        );
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      await _submitIssue(tester);
      expect(find.text(t('childCredentials.errors.tooMany')), findsOneWidget);

      repo.issueError = const CredentialsFailure(CredentialsFailureKind.server);
      await _submitIssue(tester);
      expect(find.text(t('childCredentials.errors.server')), findsOneWidget);
      expect(find.text(t('childCredentials.errors.tooMany')), findsNothing);
    });

    testWidgets('band holatda: ikki marta bosish bitta so`rov, bekor yo`q', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository()..holdIssue = Completer<void>();
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      await tester.tap(find.text(t('childCredentials.issue.submit')));
      await tester.pump();
      await tester.tap(find.byType(CircularProgressIndicator).first);
      await tester.pump(const Duration(milliseconds: 100));
      // "Bekor qilish" band paytda ishlamaydi.
      await tester.tap(find.text(t('common.cancel')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.calls, ['issue:-']);
      expect(find.byType(IssueCredentialsSheet), findsOneWidget);

      repo.holdIssue!.complete();
      await tester.pumpAndSettle();
      expect(_revealTitle, findsOneWidget);
      expect(repo.calls, ['issue:-']);
    });

    testWidgets('bekor qilish: so`rov yuborilmaydi', (tester) async {
      final repo = FakeCredentialsRepository();
      await pumpCredentialsScreen(tester, repo);
      await _openIssueSheet(tester);

      await tapText(tester, t('common.cancel'));

      expect(repo.calls, isEmpty);
      expect(find.byType(IssueCredentialsSheet), findsNothing);
      expect(find.text(t('childCredentials.none.action')), findsOneWidget);
    });
  });

  group('parolni yangilash', () {
    testWidgets('"Boshqa qurilmalardan chiqarish" standart yoqilgan', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);

      await tapText(tester, t('childCredentials.card.reset'));

      expect(find.text(t('childCredentials.reset.title')), findsWidgets);
      expect(
        find.text(t('childCredentials.reset.subtitle', {'name': kChildName})),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.reset.signOut')), findsOneWidget);
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isTrue);
      // Oqibat aniq yozilgan: ulangan telefon ham chiqadi, qayta ulash kerak.
      expect(find.text(t('childCredentials.reset.signOutOn')), findsOneWidget);
      expect(find.text(t('childCredentials.reset.signOutOff')), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('standart: signOutDevices=true va qayta ulash eslatmasi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);
      await tapText(tester, t('childCredentials.card.reset'));

      await _submitReset(tester);

      expect(repo.calls, ['reset:true']);
      expect(_revealTitle, findsOneWidget);
      expect(find.text(_password), findsOneWidget);
      expect(
        find.text(t('childCredentials.reveal.signedOutNote')),
        findsOneWidget,
      );
    });

    testWidgets('o`chirilsa: signOutDevices=false, eslatma yo`q', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);
      await tapText(tester, t('childCredentials.card.reset'));

      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isFalse);
      expect(find.text(t('childCredentials.reset.signOutOff')), findsOneWidget);
      expect(find.text(t('childCredentials.reset.signOutOn')), findsNothing);

      await _submitReset(tester);

      expect(repo.calls, ['reset:false']);
      expect(_revealTitle, findsOneWidget);
      expect(
        find.text(t('childCredentials.reveal.signedOutNote')),
        findsNothing,
      );
    });

    testWidgets('qator bosilsa ham almashadi', (tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);
      await tapText(tester, t('childCredentials.card.reset'));

      await tapText(tester, t('childCredentials.reset.signOut'));
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isFalse);
      await tapText(tester, t('childCredentials.reset.signOut'));
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isTrue);
    });

    testWidgets('xato: varaq yopilmaydi, qayta urinish mumkin', (tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials())
        ..resetError = const CredentialsFailure(CredentialsFailureKind.network);
      await pumpCredentialsScreen(tester, repo);
      await tapText(tester, t('childCredentials.card.reset'));

      await _submitReset(tester);
      expect(find.text(t('errors.noInternet')), findsOneWidget);
      expect(_revealTitle, findsNothing);

      repo.resetError = null;
      await _submitReset(tester);

      expect(_revealTitle, findsOneWidget);
      expect(repo.calls, ['reset:true', 'reset:true']);
    });

    testWidgets('bekor qilish: so`rov yuborilmaydi', (tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      await pumpCredentialsScreen(tester, repo);
      await tapText(tester, t('childCredentials.card.reset'));

      await tapText(tester, t('common.cancel'));

      expect(repo.calls, isEmpty);
      expect(find.text(t('childCredentials.reset.signOut')), findsNothing);
    });

    testWidgets('yangilashdan keyin bola holati qayta o`qiladi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(stored: activeCredentials());
      await pumpCredentialsScreen(tester, repo);
      expect(
        find.text(t('childCredentials.card.statusActive')),
        findsOneWidget,
      );

      await tapText(tester, t('childCredentials.card.reset'));
      await _submitReset(tester);
      await _closeRevealWithoutSaving(tester);

      // Server mustChangePassword=true qildi: endi birinchi kirish kutilmoqda.
      expect(
        find.text(t('childCredentials.card.statusPending')),
        findsOneWidget,
      );
      expect(find.text(t('childCredentials.card.statusActive')), findsNothing);
    });
  });

  group('parolni tiklash (bolaning so`rovi)', () {
    testWidgets('"Parolni tiklash" yangilash varag`ini ochadi (yoqilgan)', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(),
        recovery: [openRecovery()],
      );
      await pumpCredentialsScreen(tester, repo);

      await tapText(tester, t('childCredentials.recovery.restore'));

      // Sarlavha va tugma ikkalasi ham "Parolni tiklash"; oddiy
      // "Parolni yangilash" varaqda yo'q.
      expect(
        _inSheet<ResetCredentialsSheet>(
          t('childCredentials.reset.recoverTitle'),
        ),
        findsNWidgets(2),
      );
      expect(
        _inSheet<ResetCredentialsSheet>(t('childCredentials.reset.title')),
        findsNothing,
      );
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch)).value, isTrue);
      expect(find.text(t('childCredentials.reset.signOutOn')), findsOneWidget);
    });

    testWidgets('tiklangach parol ko`rsatiladi, so`rov ro`yxatdan ketadi', (
      tester,
    ) async {
      final repo = FakeCredentialsRepository(
        stored: pendingCredentials(),
        recovery: [openRecovery()],
      );
      await pumpCredentialsScreen(tester, repo);

      await tapText(tester, t('childCredentials.recovery.restore'));
      await _submitReset(tester);

      expect(repo.calls, ['reset:true']);
      expect(_revealTitle, findsOneWidget);
      expect(find.text(_password), findsOneWidget);

      await _closeRevealWithoutSaving(tester);

      // Server so'rovni "tiklandi" qildi — ro'yxat qayta o'qildi.
      expect(find.text(t('childCredentials.recovery.title')), findsNothing);
      expect(find.text(t('childCredentials.recovery.restore')), findsNothing);
    });
  });

  group('parol varag`i', () {
    Future<CredentialsHarness> openReveal(
      WidgetTester tester, {
      bool withChild = true,
    }) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      final harness = await pumpCredentialsScreen(
        tester,
        repo,
        withChild: withChild,
      );
      await tapText(tester, t('childCredentials.card.reset'));
      await _submitReset(tester);
      expect(_revealTitle, findsOneWidget);
      return harness;
    }

    testWidgets('login va parol alohida nusxalanadi', (tester) async {
      final harness = await openReveal(tester);

      await tester.tap(find.byKey(const ValueKey('reveal-copy-login')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reveal-copy-password')));
      await tester.pump();

      expect(harness.clipboard, ['aziza.k24', _password]);
      expect(find.text(t('childCredentials.reveal.copied')), findsOneWidget);
      await drainToasts(tester);
    });

    testWidgets('"Matnni nusxalash": login, parol va ism bir matnda', (
      tester,
    ) async {
      final harness = await openReveal(tester);

      await tester.ensureVisible(
        find.text(t('childCredentials.reveal.copyAll')),
      );
      await tester.tap(find.text(t('childCredentials.reveal.copyAll')));
      await tester.pump();

      final text = harness.clipboard.single;
      expect(text, contains(kChildName));
      expect(text, contains('Login: aziza.k24'));
      expect(text, contains(_password));
      await drainToasts(tester);
    });

    testWidgets('ulashish: matn va mavzu uzatiladi', (tester) async {
      final harness = await openReveal(tester);

      await tester.ensureVisible(find.text(t('childCredentials.reveal.share')));
      await tester.tap(find.text(t('childCredentials.reveal.share')));
      await tester.pump();

      expect(harness.shared, hasLength(1));
      final shared = harness.shared.single;
      expect(shared.subject, t('childCredentials.reveal.shareSubject'));
      expect(
        shared.text,
        t('childCredentials.reveal.shareMessage', {
          'name': kChildName,
          'login': 'aziza.k24',
          'password': _password,
        }),
      );
      // Ulashilgan bo'lsa yopishda tasdiq so'ralmaydi.
      await tapText(tester, t('childCredentials.reveal.done'));
      expect(_revealTitle, findsNothing);
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsNothing,
      );
    });

    testWidgets('ulashish ishlamasa: xabar, parol ko`rinib turadi', (
      tester,
    ) async {
      final harness = await openReveal(tester);
      harness.shareError = Exception('platforma yo`q');

      await tester.ensureVisible(find.text(t('childCredentials.reveal.share')));
      await tester.tap(find.text(t('childCredentials.reveal.share')));
      await tester.pump();
      await tester.pump();

      expect(find.text(t('errors.generic')), findsOneWidget);
      expect(find.text(_password), findsOneWidget);
      await drainToasts(tester);

      // Ulashish bo'lmadi — parol saqlangan hisoblanmaydi: yopishda so'raydi.
      await tapText(tester, t('childCredentials.reveal.done'));
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsOneWidget,
      );
      expect(find.text(_password), findsOneWidget);
    });

    testWidgets('nusxalangach "Tayyor" tasdiqsiz yopadi', (tester) async {
      await openReveal(tester);

      await tester.tap(find.byKey(const ValueKey('reveal-copy-password')));
      await tester.pump();
      await drainToasts(tester);
      await tapText(tester, t('childCredentials.reveal.done'));

      expect(_revealTitle, findsNothing);
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsNothing,
      );
      expect(find.text(_password), findsNothing);
    });

    testWidgets('nusxalamasdan yopish tasdiq so`raydi; "Orqaga" qoldiradi', (
      tester,
    ) async {
      await openReveal(tester);

      await tapText(tester, t('childCredentials.reveal.done'));
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsOneWidget,
      );
      expect(
        find.text(t('childCredentials.reveal.confirmBody')),
        findsOneWidget,
      );

      await tapInDialog(tester, t('childCredentials.reveal.confirmStay'));
      expect(_revealTitle, findsOneWidget);
      expect(find.text(_password), findsOneWidget);

      await tapText(tester, t('childCredentials.reveal.done'));
      await tapInDialog(tester, t('childCredentials.reveal.confirmClose'));
      expect(_revealTitle, findsNothing);
      expect(find.text(_password), findsNothing);
    });

    testWidgets('fon bosilsa yoki pastga tortilsa yopilmaydi', (tester) async {
      await openReveal(tester);

      // Varaq tepasidagi fon (barrier).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(_revealTitle, findsOneWidget);

      await tester.fling(_revealTitle, const Offset(0, 600), 2000);
      await tester.pumpAndSettle();
      expect(_revealTitle, findsOneWidget);
      expect(find.text(_password), findsOneWidget);
    });

    testWidgets('orqaga tugmasi (Android) tasdiq so`raydi', (tester) async {
      await openReveal(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsOneWidget,
      );
      expect(_revealTitle, findsOneWidget);
    });

    testWidgets('yopilgach parol hech qayerda qolmaydi', (tester) async {
      final container = (await openReveal(tester)).container;

      await _closeRevealWithoutSaving(tester);

      expect(find.text(_password), findsNothing);
      for (final element in container.getAllProviderElements().toList()) {
        final state = container.read(element.provider);
        expect(state, isNot(isA<IssuedCredentials>()));
        expect(
          '$state',
          isNot(contains(_password)),
          reason: '${element.provider}',
        );
      }
    });

    testWidgets('faqat login nusxalansa — yopishda tasdiq so`raydi', (
      tester,
    ) async {
      final harness = await openReveal(tester);

      await tester.tap(find.byKey(const ValueKey('reveal-copy-login')));
      await tester.pump();
      await drainToasts(tester);
      expect(harness.clipboard, ['aziza.k24']);

      await tapText(tester, t('childCredentials.reveal.done'));

      // Login saqlandi, parol esa yo'q: bir martalik parol yo'qolmasin.
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsOneWidget,
      );
      expect(_revealTitle, findsOneWidget);
      expect(find.text(_password), findsOneWidget);

      // Orqaga tugmasi ham xuddi shunday.
      await tapInDialog(tester, t('childCredentials.reveal.confirmStay'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsOneWidget,
      );
    });

    testWidgets('login, so`ng parol nusxalansa — endi tasdiqsiz yopiladi', (
      tester,
    ) async {
      await openReveal(tester);

      await tester.tap(find.byKey(const ValueKey('reveal-copy-login')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reveal-copy-password')));
      await tester.pump();
      await drainToasts(tester);
      await tapText(tester, t('childCredentials.reveal.done'));

      expect(_revealTitle, findsNothing);
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsNothing,
      );
    });

    testWidgets('"Matnni nusxalash" (parol bor matn) saqlangan hisoblanadi', (
      tester,
    ) async {
      await openReveal(tester);

      await tester.ensureVisible(
        find.text(t('childCredentials.reveal.copyAll')),
      );
      await tester.tap(find.text(t('childCredentials.reveal.copyAll')));
      await tester.pump();
      await drainToasts(tester);
      await tapText(tester, t('childCredentials.reveal.done'));

      expect(_revealTitle, findsNothing);
    });

    testWidgets('ulashish oynasi yopilsa (ilova tanlanmasa) — saqlanmagan', (
      tester,
    ) async {
      final harness = await openReveal(tester);
      harness.shareResult = false;

      await tester.ensureVisible(find.text(t('childCredentials.reveal.share')));
      await tester.tap(find.text(t('childCredentials.reveal.share')));
      await tester.pump();
      await tester.pump();
      expect(harness.shared, hasLength(1));

      await tapText(tester, t('childCredentials.reveal.done'));

      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsOneWidget,
      );
      expect(find.text(_password), findsOneWidget);
    });

    testWidgets('nusxalab bo`lmasa: xabar, saqlangan hisoblanmaydi', (
      tester,
    ) async {
      final harness = await openReveal(tester);
      harness.clipboardError = PlatformException(code: 'unavailable');

      await tester.tap(find.byKey(const ValueKey('reveal-copy-password')));
      await tester.pump();
      await tester.pump();

      expect(find.text(t('errors.generic')), findsOneWidget);
      expect(harness.clipboard, isEmpty);
      await drainToasts(tester);

      await tapText(tester, t('childCredentials.reveal.done'));
      expect(
        find.text(t('childCredentials.reveal.confirmTitle')),
        findsOneWidget,
      );
      expect(find.text(_password), findsOneWidget);
    });

    testWidgets('bola ismi noma`lum: yuboriladigan matnda "Bola" yo`q', (
      tester,
    ) async {
      final harness = await openReveal(tester, withChild: false);
      final fallback = t('childCredentials.fallbackChildName');
      // Sarlavhada umumiy nom bor.
      expect(
        find.text(t('childCredentials.reveal.subtitle', {'name': fallback})),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(t('childCredentials.reveal.share')));
      await tester.tap(find.text(t('childCredentials.reveal.share')));
      await tester.pump();
      await tester.pump();

      // Lekin bolaga ketadigan matn ismsiz.
      final text = harness.shared.single.text;
      expect(
        text,
        t('childCredentials.reveal.shareMessageNoName', {
          'login': 'aziza.k24',
          'password': _password,
        }),
      );
      expect(text, isNot(contains(fallback)));
      expect(text, contains(_password));
    });

    testWidgets('"Matnni nusxalash" ham ismsiz matnni nusxalaydi', (
      tester,
    ) async {
      final harness = await openReveal(tester, withChild: false);

      await tester.ensureVisible(
        find.text(t('childCredentials.reveal.copyAll')),
      );
      await tester.tap(find.text(t('childCredentials.reveal.copyAll')));
      await tester.pump();

      expect(
        harness.clipboard.single,
        t('childCredentials.reveal.shareMessageNoName', {
          'login': 'aziza.k24',
          'password': _password,
        }),
      );
      await drainToasts(tester);
    });
  });

  group('nusxalangan parol buferdan tozalanadi', () {
    Future<CredentialsHarness> openReveal(WidgetTester tester) async {
      final repo = FakeCredentialsRepository(stored: pendingCredentials());
      final harness = await pumpCredentialsScreen(tester, repo);
      await tapText(tester, t('childCredentials.card.reset'));
      await _submitReset(tester);
      return harness;
    }

    /// Fake vaqtni oldinga suradi va tozalash mikrovazifalari tugashini kutadi.
    Future<void> elapse(WidgetTester tester, Duration duration) async {
      await tester.pump(duration);
      await tester.pump();
      await tester.pump();
    }

    Future<void> copyPassword(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('reveal-copy-password')));
      await tester.pump();
    }

    testWidgets('~90 s dan keyin, hamon shu matn turgan bo`lsa', (
      tester,
    ) async {
      final harness = await openReveal(tester);

      await copyPassword(tester);
      expect(harness.currentClipboard, _password);

      await elapse(tester, const Duration(seconds: 89));
      expect(harness.currentClipboard, _password);

      await elapse(tester, const Duration(seconds: 2));
      expect(harness.currentClipboard, isEmpty);
    });

    testWidgets('boshqa narsa nusxalangan bo`lsa tegilmaydi', (tester) async {
      final harness = await openReveal(tester);

      await copyPassword(tester);
      // Ota-ona keyin boshqa matn nusxaladi.
      harness.clipboard.add('boshqa matn');
      await elapse(tester, const Duration(seconds: 95));

      expect(harness.currentClipboard, 'boshqa matn');
    });

    testWidgets('varaq yopilganda tozalanmaydi — faqat vaqt tugagach', (
      tester,
    ) async {
      final harness = await openReveal(tester);

      await copyPassword(tester);
      await tapText(tester, t('childCredentials.reveal.done'));
      expect(_revealTitle, findsNothing);
      // Yopib, boshqa ilovaga o'tib yopishtirishi mumkin: bufer hali to'la.
      expect(harness.currentClipboard, _password);
      await elapse(tester, const Duration(seconds: 60));
      expect(harness.currentClipboard, _password);

      await elapse(tester, const Duration(seconds: 31));
      expect(harness.currentClipboard, isEmpty);
    });

    testWidgets('login nusxalansa bufer tozalanmaydi', (tester) async {
      final harness = await openReveal(tester);

      await tester.tap(find.byKey(const ValueKey('reveal-copy-login')));
      await tester.pump();
      await elapse(tester, const Duration(minutes: 5));

      expect(harness.currentClipboard, 'aziza.k24');
    });

    testWidgets('yangi nusxa tozalash vaqtini qayta boshlaydi', (tester) async {
      final harness = await openReveal(tester);

      await copyPassword(tester);
      await elapse(tester, const Duration(seconds: 60));
      await copyPassword(tester);

      // Birinchi nusxadan 100 s o'tdi, ikkinchisidan 40 s: hali turibdi.
      await elapse(tester, const Duration(seconds: 40));
      expect(harness.currentClipboard, _password);

      await elapse(tester, const Duration(seconds: 51));
      expect(harness.currentClipboard, isEmpty);
    });
  });
}

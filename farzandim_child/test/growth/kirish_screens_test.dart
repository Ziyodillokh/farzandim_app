// A01–A12 · Kirish: login/parol, birinchi sozlash, tiklash, profil, maktab
// kodi, ulanish holati, tuzatish, akkaunt tanlash va sessiya yopildi
// (soxta manbalar, tarmoqsiz).

import 'dart:async';
import 'dart:convert';

import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/link_screens.dart';
import 'package:farzandim_child/growth/kirish/login_screen.dart';
import 'package:farzandim_child/growth/kirish/profile_screen.dart';
import 'package:farzandim_child/growth/kirish/recovery_screens.dart';
import 'package:farzandim_child/growth/kirish/school_code_screens.dart';
import 'package:farzandim_child/growth/kirish/setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/learning/fake_learning_repository.dart';
import 'fake_kirish.dart';
import 'g5_overrides.dart';
import 'g5_test_app.dart';

Future<
  ({
    FakeKirishRepository repo,
    AccountRegistry registry,
    FakeOwnerPairing pairing,
    GoRouter router,
  })
>
_pump(
  WidgetTester tester,
  String location, {
  FakeKirishRepository? repo,
  AccountRegistry? registry,
  FakeDeviceKey? deviceKey,
  bool ownerPaired = false,
  List<Override> overrides = const [],
}) async {
  final r = repo ?? FakeKirishRepository();
  final reg = registry ?? AccountRegistry(MemoryAccountStore());
  final pairing = FakeOwnerPairing(paired: ownerPaired);
  final router = await pumpG5App(
    tester,
    routes: [...buildGrowthV5Routes(), GoRouteSplash.route],
    initialLocation: location,
    overrides: [
      ...g5Overrides(
        learning: FakeLearningRepository(clock: () => kG5Now),
        pairing: () => pairing,
      ),
      ...kirishOverrides(repo: r, registry: reg, deviceKey: deviceKey),
      ...overrides,
    ],
  );
  return (repo: r, registry: reg, pairing: pairing, router: router);
}

const _ticketKey = 'g5_recovery_ticket_v1';

/// A04 ni qurilmada saqlangan chipta bilan ochadi. Ekran ilova chizilgandan
/// keyin ochiladi — so'rash taymeri soxta vaqtda (`tester.pump`) yuradi.
Future<({FakeKirishRepository repo, MemoryAccountStore store})>
_openRecoveryStatus(WidgetTester tester, {FakeKirishRepository? repo}) async {
  final r = repo ?? FakeKirishRepository();
  final store = MemoryAccountStore()
    ..values[_ticketKey] = jsonEncode(
      FakeKirishRepository.recoveryTicket.toJson(),
    );
  final env = await _pump(
    tester,
    GrowthV5Routes.kirishLogin,
    repo: r,
    overrides: [recoveryTicketStoreProvider.overrideWithValue(store)],
  );
  unawaited(env.router.push(GrowthV5Routes.kirishRecoveryStatus));
  await settleG5(tester);
  expect(find.byType(KirishRecoveryStatusScreen), findsOneWidget);
  return (repo: r, store: store);
}

/// Ilova holatini ketma-ket o'zgartiradi (AppLifecycleListener tartibi).
Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

/// Yozib bo'lmaydigan ombor (Keychain / Keystore xatosi).
class _BrokenTicketStore implements AccountStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String? value) async =>
      throw StateError('keystore');
}

/// A09 ni vaqtinchalik parol bilan kirilgandek ochadi (A02 dan keyingi holat).
Future<FakeKirishRepository> _openSetup(WidgetTester tester) async {
  final env = await _pump(tester, GrowthV5Routes.kirishLogin);
  unawaited(
    env.router.push(
      GrowthV5Routes.kirishSetup,
      extra: const SetupArgs(
        setupToken: 'setup-1',
        login: 'jasur.k07',
        childName: 'Jasur',
      ),
    ),
  );
  await settleG5(tester);
  expect(find.byType(KirishSetupScreen), findsOneWidget);
  return env.repo;
}

/// A09: yangi parolni ikki marta yozib, «Davom etish».
Future<void> _submitPassword(WidgetTester tester, String password) async {
  await tester.enterText(find.byType(TextField).first, password);
  // Kuch ko'rsatkichi qatori keyingi kadrda maydonlar orasiga qo'shiladi.
  await tester.pump();
  await tester.enterText(find.byType(TextField).last, password);
  await tester.tap(find.text('Davom etish'));
  await settleG5(tester);
}

/// Splash o'rniga oddiy belgi (yo'naltirishni tekshirish uchun).
abstract final class GoRouteSplash {
  static final route = GoRoute(
    path: '/splash',
    builder: (_, _) => const Scaffold(body: Text('SPLASH')),
  );
}

void main() {
  setUpAll(setUpG5WidgetTests);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('modellar', () {
    test('parol qoidasi va kuchi', () {
      expect(isStrongEnough('abc12345'), isTrue);
      expect(isStrongEnough('abcdefgh'), isFalse);
      expect(isStrongEnough('1234567'), isFalse);
      expect(isStrongEnough('aziza.k24', login: 'aziza.k24'), isFalse);
      expect(passwordStrength(''), 0);
      expect(passwordStrength('abc12345'), 2);
      expect(passwordStrength('Abc12345xyz!'), 3);
    });

    test(
      'parol siyosati server bilan bir xil (Unicode harf, 64 belgi, 72 bayt)',
      () {
        // Har qanday alifbo harfi — server `\p{L}`.
        expect(passwordIssue('Парол1234'), isNull);
        expect(isStrongEnough('Парольчик1'), isTrue);
        expect(passwordStrength('парол1234'), 2);
        expect(passwordIssue('12345678'), PasswordIssue.needsLetter);
        expect(passwordIssue('abcdefgh'), PasswordIssue.needsDigit);
        expect(passwordIssue('Abcde12'), PasswordIssue.tooShort);
        // Uzunlik — Unicode belgilar soni (emoji UTF-16 da 2 birlik).
        expect(passwordIssue('a1${'\u{1F600}' * 5}'), PasswordIssue.tooShort);
        expect(
          passwordIssue('AZIZA.K24', login: 'aziza.k24'),
          PasswordIssue.sameAsLogin,
        );
        // 64 belgi.
        expect(passwordIssue('${'a' * 63}1'), isNull);
        expect(passwordIssue('${'a' * 64}1'), PasswordIssue.tooLong);
        // 72 bayt (bcrypt): kirill harfi 2 bayt — 64 belgidan kam bo'lsa ham.
        expect(passwordIssue('${'ш' * 35}1'), isNull);
        expect(passwordIssue('${'ш' * 36}1'), PasswordIssue.tooLong);
      },
    );

    test('server sababi → PasswordIssue', () {
      expect(PasswordIssue.fromWire('TOO_SHORT'), PasswordIssue.tooShort);
      expect(PasswordIssue.fromWire('TOO_LONG'), PasswordIssue.tooLong);
      expect(PasswordIssue.fromWire('NEEDS_LETTER'), PasswordIssue.needsLetter);
      expect(PasswordIssue.fromWire('NEEDS_DIGIT'), PasswordIssue.needsDigit);
      expect(
        PasswordIssue.fromWire('SAME_AS_LOGIN'),
        PasswordIssue.sameAsLogin,
      );
      expect(PasswordIssue.fromWire('TOO_COMMON'), PasswordIssue.tooCommon);
      expect(
        PasswordIssue.fromWire('SAME_AS_CURRENT'),
        PasswordIssue.sameAsCurrent,
      );
      expect(PasswordIssue.fromWire('SOMETHING_NEW'), isNull);
      expect(PasswordIssue.fromWire(null), isNull);
    });

    test('ulanish holati: maktab nomi faqat tasdiqlangach', () {
      final review = LinkStatus.fromJson({
        'student': {'status': 'UNDER_REVIEW', 'schoolName': '24-maktab'},
        'parent': {'status': 'PENDING'},
      });
      expect(review.student, StudentLinkState.underReview);
      expect(review.schoolName, isNull);
      final ok = LinkStatus.fromJson({
        'student': {
          'status': 'CONFIRMED',
          'schoolName': '24-maktab',
          'className': '6-B',
        },
        'parent': {'status': 'CONFIRMED'},
      });
      expect(ok.schoolName, '24-maktab');
      expect(ok.parent, ParentLinkState.confirmed);
      // Ota-ona kiritdi, telefoni maktabda yo'q — xodim tekshiradi.
      expect(
        LinkStatus.fromJson({
          'student': {'status': 'UNDER_REVIEW'},
          'parent': {'status': 'UNDER_REVIEW'},
        }).parent,
        ParentLinkState.underReview,
      );
    });

    test('kirish natijasi: sozlash yoki sessiya (asosiy qurilma)', () {
      expect(
        LoginResult.tryFromJson({
          'status': 'SETUP_REQUIRED',
          'setupToken': 't',
          'child': {'id': 'c', 'name': 'Aziza'},
        }),
        isA<LoginNeedsSetup>(),
      );
      final ok = LoginResult.tryFromJson({
        'status': 'OK',
        'accessToken': 'a',
        'refreshToken': 'r',
        'sessionId': 's',
        'deviceRole': 'MAIN',
        'child': {'id': 'c', 'name': 'Aziza'},
      });
      expect((ok! as LoginOk).session.role, DeviceRole.main);
      final withIds = ChildSession.tryFromJson({
        'status': 'OK',
        'accessToken': 'a',
        'refreshToken': 'r',
        'child': {'id': 'c', 'name': 'Aziza', 'parentId': 'p1'},
        'user': {'id': 'u1'},
      });
      expect(withIds?.parentId, 'p1');
      expect(withIds?.userId, 'u1');
    });

    test('sessiya yopilish sababi: server kodi → A12 matni', () {
      expect(closedReasonFromWire('RECOVERED'), SessionClosedReason.recovered);
      expect(
        closedReasonFromWire('PERMISSIONS_CHANGED'),
        SessionClosedReason.permissions,
      );
      expect(
        closedReasonFromWire('SIGNED_IN_ELSEWHERE'),
        SessionClosedReason.signedInElsewhere,
      );
      expect(closedReasonFromWire('SIGNED_OUT'), SessionClosedReason.signedOut);
      expect(closedReasonFromWire(null), SessionClosedReason.other);
      expect(closedReasonFromWire('NEW_CODE'), SessionClosedReason.other);
    });

    test('tiklash holati: server kanali chiptadagidan ustun', () {
      final status = RecoveryStatus.tryFromJson({
        'status': 'RECEIVED',
        'channel': 'PARENT',
        'createdAt': '2026-11-09T09:00:00.000Z',
        'restoredAt': null,
        'signedOutAt': null,
      });
      expect(status?.state, RecoveryState.received);
      expect(status?.channel, RecoveryChannel.parent);
      expect(
        RecoveryStatus.tryFromJson({
          'status': 'RESTORED',
          'createdAt': '2026-11-09T09:00:00.000Z',
        })?.channel,
        isNull,
      );
    });

    test('hasPendingRecoveryTicket: chipta saqlangan bo\'lsa true', () async {
      final store = MemoryAccountStore();
      expect(await hasPendingRecoveryTicket(store: store), isFalse);

      store.values[_ticketKey] = jsonEncode(
        FakeKirishRepository.recoveryTicket.toJson(),
      );
      expect(await hasPendingRecoveryTicket(store: store), isTrue);

      // Buzilgan yozuv — chipta yo'q hisoblanadi (yiqilmaydi).
      store.values[_ticketKey] = '{buzilgan';
      expect(await hasPendingRecoveryTicket(store: store), isFalse);
      expect(
        await hasPendingRecoveryTicket(store: _BrokenTicketStore()),
        isFalse,
      );

      // Odatiy ombor — secure storage.
      FlutterSecureStorage.setMockInitialValues({
        _ticketKey: jsonEncode(FakeKirishRepository.recoveryTicket.toJson()),
      });
      expect(await hasPendingRecoveryTicket(), isTrue);
    });

    test('tiklash chiptasi: bir xil so\'rov — teng (holat kaliti)', () {
      final a = FakeKirishRepository.recoveryTicket;
      final b = RecoveryTicket(
        requestId: a.requestId,
        pollToken: a.pollToken,
        channel: RecoveryChannel.school,
        createdAt: DateTime(2026, 11, 6),
      );
      expect(b, a);
      expect(b.hashCode, a.hashCode);
      expect(
        RecoveryTicket(
          requestId: a.requestId,
          pollToken: 'boshqa',
          channel: a.channel,
          createdAt: a.createdAt,
        ),
        isNot(a),
      );
    });

    test(
      'akkauntlar: mehmondan chiqish tokenlarni o\'chiradi, egasi qoladi',
      () async {
        final store = MemoryAccountStore();
        final reg = AccountRegistry(store);
        await reg.upsert(
          const DeviceAccount(childId: 'o', name: 'Aziza', owner: true),
          activate: true,
        );
        await reg.upsert(
          const DeviceAccount(childId: 'g', name: 'Jasur', owner: false),
          activate: true,
        );
        expect(reg.activeGuest?.childId, 'g');
        await guestTokenStorage(
          'g',
        ).saveTokens(accessToken: 'a', refreshToken: 'r');
        await reg.signOutGuest('g', notice: SessionClosedReason.recovered);
        expect(reg.activeGuest, isNull);
        expect(reg.active?.childId, 'o');
        expect(reg.closedNotice, SessionClosedReason.recovered);
        expect(await guestTokenStorage('g').readRefreshToken(), isNull);

        final reloaded = AccountRegistry(store);
        await reloaded.load();
        expect(reloaded.accounts.single.childId, 'o');
      },
    );
  });

  testWidgets('A01: til va «Boshlash» → A02', (tester) async {
    await _pump(tester, GrowthV5Routes.kirish);

    expect(find.text('Xush kelibsan!'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    await tester.tap(find.text('Boshlash'));
    await settleG5(tester);
    expect(find.byType(KirishLoginScreen), findsOneWidget);
  });

  testWidgets(
    'A02: noto\'g\'ri parol — boshqa akkaunt haqida hech narsa yo\'q',
    (tester) async {
      final repo = FakeKirishRepository(
        loginError: const KirishException(KirishError.invalidCredentials),
      );
      await _pump(tester, GrowthV5Routes.kirishLogin, repo: repo);

      await tester.enterText(find.byType(TextField).first, 'aziza.k24');
      await tester.enterText(find.byType(TextField).last, 'xato1234');
      await tester.tap(find.text('Kirish'));
      await settleG5(tester);

      expect(repo.logins.single, 'aziza.k24');
      expect(find.text('Login yoki parol notoʻgʻri'), findsOneWidget);
    },
  );

  testWidgets('A02: 5 xatodan keyin — vaqt bilan cheklov', (tester) async {
    final repo = FakeKirishRepository(
      loginError: const KirishException(
        KirishError.locked,
        retryAfter: Duration(minutes: 15),
      ),
    );
    await _pump(tester, GrowthV5Routes.kirishLogin, repo: repo);

    await tester.enterText(find.byType(TextField).first, 'aziza.k24');
    await tester.enterText(find.byType(TextField).last, 'xato1234');
    await tester.tap(find.text('Kirish'));
    await settleG5(tester);

    expect(find.textContaining('Juda koʻp urinish'), findsOneWidget);
  });

  testWidgets('A02 → A09: birinchi kirishda yangi parol; mehmon akkaunt', (
    tester,
  ) async {
    final repo = FakeKirishRepository(
      loginResult: const LoginNeedsSetup(
        setupToken: 'setup-1',
        childName: 'Jasur',
      ),
    );
    final env = await _pump(tester, GrowthV5Routes.kirishLogin, repo: repo);

    await tester.enterText(find.byType(TextField).first, 'jasur.k07');
    await tester.enterText(find.byType(TextField).last, 'vaqtin12');
    await tester.tap(find.text('Kirish'));
    await settleG5(tester);
    expect(find.byType(KirishSetupScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'yangiParol7');
    // Kuch ko'rsatkichi qatori keyingi kadrda maydonlar orasiga qo'shiladi.
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'boshqaParol7');
    await tester.tap(find.text('Davom etish'));
    await settleG5(tester);
    expect(find.text('Parollar bir xil emas'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'yangiParol7');
    await tester.tap(find.text('Davom etish'));
    await settleG5(tester);

    expect(repo.setups.single, 'yangiParol7');
    // Qurilmada egasi yo'q, lekin server SECONDARY dedi → mehmon akkaunt.
    expect(env.registry.activeGuest?.childId, 'child-9');
    expect(env.registry.activeGuest?.login, 'jasur.k07');
    expect(
      await guestTokenStorage('child-9').readAccessToken(),
      'access-child-9',
    );
  });

  group('A09: parol qoidalari', () {
    testWidgets('kirillcha parol o\'tadi; uzun va login — so\'rovsiz', (
      tester,
    ) async {
      final repo = await _openSetup(tester);

      // 37 belgi, lekin 73 bayt.
      await _submitPassword(tester, '${'ш' * 36}1');
      expect(
        find.text('Parol juda uzun — qisqaroq parol tanla'),
        findsOneWidget,
      );
      await _submitPassword(tester, 'JASUR.K07');
      expect(find.text('Parol login bilan bir xil boʻlmasin'), findsOneWidget);
      expect(repo.setups, isEmpty);

      await _submitPassword(tester, 'Парол1234');
      expect(repo.setups, ['Парол1234']);
    });

    testWidgets('server WEAK_PASSWORD sababi aniq matn bilan', (tester) async {
      final repo = await _openSetup(tester);
      const weak = 'Kamida 8 belgi, harf va raqam boʻlsin';
      for (final (issue, text) in const [
        (
          PasswordIssue.sameAsCurrent,
          'Yangi parol vaqtinchalik parol bilan bir xil boʻlmasin',
        ),
        (
          PasswordIssue.tooCommon,
          'Bu parolni koʻpchilik ishlatadi — boshqasini tanla',
        ),
        (PasswordIssue.tooLong, 'Parol juda uzun — qisqaroq parol tanla'),
        (PasswordIssue.sameAsLogin, 'Parol login bilan bir xil boʻlmasin'),
        (PasswordIssue.needsDigit, weak),
        (null, weak),
      ]) {
        repo.setupError = KirishException(
          KirishError.weakPassword,
          passwordIssue: issue,
        );
        await _submitPassword(tester, 'Kitob2026');
        expect(find.text(text), findsOneWidget, reason: '$issue');
      }
      expect(find.text('Saqlanmadi. Qayta urinib koʻr.'), findsNothing);
    });

    testWidgets('boshqa 400 — «zaif parol» emas, umumiy xato', (tester) async {
      final repo = await _openSetup(tester);
      repo.setupError = const KirishException(KirishError.validation);

      await _submitPassword(tester, 'Kitob2026');

      expect(find.text('Saqlanmadi. Qayta urinib koʻr.'), findsOneWidget);
      expect(find.text('Kamida 8 belgi, harf va raqam boʻlsin'), findsNothing);
    });
  });

  testWidgets('A02: asosiy qurilma — bola qurilma egasi bo\'ladi → A06', (
    tester,
  ) async {
    final repo = FakeKirishRepository(
      loginResult: LoginOk(
        FakeKirishRepository.session(childId: 'child-7', role: DeviceRole.main),
      ),
    );
    final env = await _pump(tester, GrowthV5Routes.kirishLogin, repo: repo);

    await tester.enterText(find.byType(TextField).first, 'aziza.k24');
    await tester.enterText(find.byType(TextField).last, 'parol1234');
    await tester.runAsync(() async {
      await tester.tap(find.text('Kirish'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleG5(tester);

    expect(env.pairing.restored, ['child-7']);
    expect(env.registry.owner?.childId, 'child-7');
    expect(await TokenStorage().readAccessToken(), 'access-child-7');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('childId'), 'child-7');
    expect(find.byType(KirishProfileScreen), findsOneWidget);
  });

  testWidgets('A06: jins tanlanmaguncha yopiq; sinf → yosh; saqlanadi → A05', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      GrowthV5Routes.kirishProfile,
      ownerPaired: true,
    );

    expect(find.text('Jinsingni tanla'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('6-sinf'));
    await tester.pump();
    expect(find.text('12'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Qiz'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Qiz'));
    await tester.pump();
    await tester.tap(find.text('Davom etish'));
    await settleG5(tester);

    final saved = env.repo.profiles.single;
    expect(saved.age, 12);
    expect(saved.gender, 'female');
    expect(saved.language, EducationLanguage.uz);
    expect(find.byType(KirishSchoolCodeScreen), findsOneWidget);
  });

  testWidgets('A05: kod xato — nom aytilmaydi; cheklov → A11', (tester) async {
    final repo = FakeKirishRepository(
      linkError: const KirishException(KirishError.codeInvalid),
    );
    await _pump(
      tester,
      GrowthV5Routes.kirishCode,
      repo: repo,
      ownerPaired: true,
    );

    await tester.enterText(find.byType(TextField).first, '047215');
    await tester.pump();
    await settleG5(tester);
    expect(repo.codes.single, '047215');
    expect(find.text('Kod ishlamadi. Tekshirib, qayta kirit'), findsOneWidget);

    repo.linkError = const KirishException(
      KirishError.locked,
      retryAfter: Duration(minutes: 15),
    );
    await tester.enterText(find.byType(TextField).first, '111111');
    await tester.pump();
    await settleG5(tester);
    expect(find.byType(KirishLockedScreen), findsOneWidget);
    expect(find.text('Urinishlar vaqtincha cheklandi'), findsOneWidget);
    // Cheklov shu bolaga yozildi — qurilmadagi boshqa bolaga emas.
    expect(await codeLockUntil('child-1'), isNotNull);
    expect(await codeLockUntil('child-2'), isNull);
  });

  testWidgets('A05: so\'rov ketayotganda kod ikkinchi marta yuborilmaydi', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repo = FakeKirishRepository(
      linkResult: const LinkStatus(
        student: StudentLinkState.underReview,
        parent: ParentLinkState.pending,
      ),
    )..linkGate = gate;
    await _pump(
      tester,
      GrowthV5Routes.kirishCode,
      repo: repo,
      ownerPaired: true,
    );

    await tester.enterText(find.byType(TextField).first, '047215');
    await tester.pump();
    expect(repo.codes, ['047215']);
    // So'rov yo'lda: maydon faqat o'qiladi.
    final field = tester.widget<GCodeField>(find.byType(GCodeField));
    expect(field.enabled, isFalse);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);

    // Kod yana «to'ldi» (masalan avtomatik to'ldirish) — yangi so'rov yo'q.
    field.onCompleted!('047215');
    await tester.pump();
    expect(repo.codes, ['047215']);

    gate.complete();
    await settleG5(tester);
    expect(repo.codes, ['047215']);
    expect(find.byType(KirishLinkStatusScreen), findsOneWidget);
  });

  testWidgets('A05: so\'rovlar chegarasi — A11 emas, keyinroq urinish', (
    tester,
  ) async {
    final repo = FakeKirishRepository(
      linkError: const KirishException(KirishError.rateLimited),
    );
    await _pump(
      tester,
      GrowthV5Routes.kirishCode,
      repo: repo,
      ownerPaired: true,
    );

    await tester.enterText(find.byType(TextField).first, '047215');
    await tester.pump();
    await settleG5(tester);

    expect(find.byType(KirishLockedScreen), findsNothing);
    expect(
      find.text('Juda koʻp soʻrov. Birozdan keyin qayta urin.'),
      findsOneWidget,
    );
    expect(await codeLockUntil('child-1'), isNull);
  });

  testWidgets('A07: tekshiruvda — maktab nomi yo\'q; tasdiqlangach — bor', (
    tester,
  ) async {
    final repo = FakeKirishRepository(
      status: const LinkStatus(
        student: StudentLinkState.underReview,
        parent: ParentLinkState.pending,
      ),
    );
    await _pump(
      tester,
      GrowthV5Routes.kirishStatus,
      repo: repo,
      ownerPaired: true,
    );
    expect(find.text('Tekshiruvda'), findsOneWidget);
    expect(find.textContaining('24-maktab'), findsNothing);
    expect(find.text('Shaxsiy mashqni boshlash'), findsOneWidget);
  });

  testWidgets('A07: tasdiqlangan — «To\'g\'rimi?» va maktabga o\'tish', (
    tester,
  ) async {
    final repo = FakeKirishRepository(
      status: const LinkStatus(
        student: StudentLinkState.confirmed,
        parent: ParentLinkState.confirmed,
        schoolName: '24-maktab',
        className: '6-B',
      ),
    );
    await _pump(
      tester,
      GrowthV5Routes.kirishStatus,
      repo: repo,
      ownerPaired: true,
    );
    expect(find.textContaining('24-maktab · 6-B'), findsOneWidget);
    expect(find.text('Maktabga oʻtish'), findsOneWidget);
    expect(find.text('Tuzatish soʻrash'), findsOneWidget);
  });

  testWidgets('A08: xato bo\'lsa qayta yuborishda o\'sha so\'rov id', (
    tester,
  ) async {
    final repo = FakeKirishRepository()
      ..correctionError = const KirishException(KirishError.network);
    await _pump(
      tester,
      GrowthV5Routes.kirishCorrection,
      repo: repo,
      ownerPaired: true,
    );

    await tester.tap(find.text('Soʻrov yuborish'));
    await settleG5(tester);
    expect(find.text('Yuborilmadi'), findsOneWidget);

    repo.correctionError = null;
    await tester.tap(find.text('Qayta urinish'));
    await settleG5(tester);
    expect(repo.corrections.toSet(), hasLength(1));
    expect(find.textContaining('Qabul qilindi'), findsOneWidget);
  });

  testWidgets('A03 → A04: so\'rov qabul qilindi, tekshiruv kutilmoqda', (
    tester,
  ) async {
    await _pump(tester, GrowthV5Routes.kirishRecovery);

    await tester.enterText(find.byType(TextField).first, 'aziza.k24');
    await tester.tap(find.text('Maktab orqali'));
    await tester.pump();
    await tester.tap(find.text('Tiklashni soʻrash'));
    await settleG5(tester);

    expect(find.text('Soʻrov qabul qilindi'), findsOneWidget);
    expect(find.text('Tekshiruv kutilmoqda'), findsOneWidget);
    expect(find.text('Maktab tekshiradi'), findsOneWidget);
  });

  group('A03 / A04: tiklash', () {
    testWidgets('limit — «Qayta urinish» yo\'q, login o\'zgarmaguncha yopiq', (
      tester,
    ) async {
      final repo = FakeKirishRepository()
        ..recoveryError = const KirishException(KirishError.rateLimited);
      await _pump(tester, GrowthV5Routes.kirishRecovery, repo: repo);

      await tester.enterText(find.byType(TextField).first, 'aziza.k24');
      await tester.tap(find.text('Tiklashni soʻrash'));
      await settleG5(tester);

      expect(find.textContaining('Soʻrovlar soni tugadi'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsNothing);
      final submit = find.widgetWithText(GButton, 'Tiklashni soʻrash');
      expect(tester.widget<GButton>(submit).onPressed, isNull);
      await tester.tap(submit);
      await settleG5(tester);
      expect(repo.recoveries, ['aziza.k24']);

      // Boshqa login — yana yuborsa bo'ladi.
      await tester.enterText(find.byType(TextField).first, 'aziza.k25');
      await tester.pump();
      expect(tester.widget<GButton>(submit).onPressed, isNotNull);
      expect(find.textContaining('Soʻrovlar soni tugadi'), findsNothing);
    });

    testWidgets('internet yo\'q — «Qayta urinish» bilan qayta yuboriladi', (
      tester,
    ) async {
      final repo = FakeKirishRepository()
        ..recoveryError = const KirishException(KirishError.network);
      await _pump(tester, GrowthV5Routes.kirishRecovery, repo: repo);

      await tester.enterText(find.byType(TextField).first, 'aziza.k24');
      await tester.tap(find.text('Tiklashni soʻrash'));
      await settleG5(tester);
      expect(find.text('Internet yoʻq — soʻrov yuborilmadi'), findsOneWidget);

      repo.recoveryError = null;
      await tester.tap(find.text('Qayta urinish'));
      await settleG5(tester);
      expect(repo.recoveries, hasLength(2));
      expect(find.byType(KirishRecoveryStatusScreen), findsOneWidget);
    });

    testWidgets('chipta saqlanmasa ham A04 shu chipta bilan ochiladi', (
      tester,
    ) async {
      final env = await _pump(
        tester,
        GrowthV5Routes.kirishRecovery,
        overrides: [
          recoveryTicketStoreProvider.overrideWithValue(_BrokenTicketStore()),
        ],
      );

      await tester.enterText(find.byType(TextField).first, 'aziza.k24');
      await tester.tap(find.text('Tiklashni soʻrash'));
      await settleG5(tester);

      expect(find.byType(KirishRecoveryStatusScreen), findsOneWidget);
      expect(find.text('Soʻrov qabul qilindi'), findsOneWidget);
      expect(find.text('Tekshiruv kutilmoqda'), findsOneWidget);
      expect(env.repo.statusChecks, 1);
    });

    testWidgets('A04: RECEIVED — har 20 soniyada so\'raladi, tiklangach '
        'to\'xtaydi', (tester) async {
      final env = await _openRecoveryStatus(tester);
      final repo = env.repo;
      expect(find.text('Tekshiruv kutilmoqda'), findsOneWidget);
      expect(repo.statusChecks, 1);

      await tester.pump(kRecoveryPollInterval);
      await tester.pump();
      expect(repo.statusChecks, 2);

      repo.recovery = RecoveryStatus(
        state: RecoveryState.restored,
        createdAt: DateTime(2026, 11, 5, 9, 41),
        restoredAt: DateTime(2026, 11, 5, 9, 55),
      );
      await tester.pump(kRecoveryPollInterval);
      await tester.pump();
      expect(repo.statusChecks, 3);
      expect(
        find.text('Yangi vaqtinchalik parolni ota-onangdan yoki maktabdan ol.'),
        findsOneWidget,
      );

      await tester.pump(kRecoveryPollInterval * 3);
      await tester.pump();
      expect(repo.statusChecks, 3);
    });

    testWidgets('A04: fonda so\'ralmaydi, ilovaga qaytganda darhol '
        'yangilanadi', (tester) async {
      final env = await _openRecoveryStatus(tester);
      expect(env.repo.statusChecks, 1);

      await _lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump(kRecoveryPollInterval * 3);
      expect(env.repo.statusChecks, 1);

      await _lifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      expect(env.repo.statusChecks, 2);
    });

    testWidgets('A04: 404 — chipta o\'chiriladi, «faol emas», A03 ga qaytish', (
      tester,
    ) async {
      final env = await _openRecoveryStatus(
        tester,
        repo: FakeKirishRepository()
          ..statusError = const KirishException(KirishError.notFound),
      );

      expect(
        find.text('Bu soʻrov endi faol emas. Kerak boʻlsa, yangisini yubor.'),
        findsOneWidget,
      );
      expect(find.text('Tekshiruv kutilmoqda'), findsNothing);
      expect(env.store.values, isEmpty);

      // So'rash to'xtadi.
      await tester.pump(kRecoveryPollInterval * 3);
      expect(env.repo.statusChecks, 1);

      await tester.tap(find.text('Yangi soʻrov yuborish'));
      await settleG5(tester);
      expect(find.byType(KirishRecoveryScreen), findsOneWidget);
    });
  });

  testWidgets('A10: kalitli mehmon akkaunt barmoq izi bilan ochiladi', (
    tester,
  ) async {
    final reg = AccountRegistry(MemoryAccountStore());
    await reg.upsert(
      const DeviceAccount(
        childId: 'child-1',
        name: 'Aziza Karimova',
        owner: true,
      ),
      activate: true,
    );
    await reg.upsert(
      const DeviceAccount(
        childId: 'child-2',
        name: 'Jasur Karimov',
        owner: false,
        deviceKey: true,
        login: 'jasur.k07',
      ),
    );
    await reg.activate('child-1');
    final key = FakeDeviceKey();
    await _pump(
      tester,
      GrowthV5Routes.kirishAccounts,
      registry: reg,
      deviceKey: key,
      ownerPaired: true,
    );
    await tester.runAsync(
      () => guestTokenStorage(
        'child-2',
      ).saveTokens(accessToken: 'a', refreshToken: 'r'),
    );

    expect(find.text('Kim kiryapti?'), findsOneWidget);
    expect(find.text('Kalit bilan'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Jasur Karimov'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settleG5(tester);

    expect(key.asked, 1);
    expect(reg.activeGuest?.childId, 'child-2');
  });

  testWidgets('A12: sabab bilan; «Qayta kirish» → A02', (tester) async {
    final reg = AccountRegistry(MemoryAccountStore());
    await reg.upsert(
      const DeviceAccount(childId: 'child-1', name: 'Aziza', owner: true),
      activate: true,
    );
    await reg.ownerClosed(notice: SessionClosedReason.recovered);
    final env = await _pump(tester, GrowthV5Routes.kirishClosed, registry: reg);

    expect(find.text('Bu qurilmada chiqildi'), findsOneWidget);
    expect(find.textContaining('boshqa qurilmada tiklandi'), findsOneWidget);
    await tester.tap(find.text('Qayta kirish'));
    await settleG5(tester);

    expect(reg.closedNotice, isNull);
    expect(env.pairing.sessionNoticeCleared, isTrue);
    expect(find.byType(KirishLoginScreen), findsOneWidget);
  });
}

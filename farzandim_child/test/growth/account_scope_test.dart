// Bir qurilmada bir nechta akkaunt: ro'yxat qoidalari, sessiyani joylash
// (egasining o'zi qayta kirishi), server signallarini faqat o'z akkauntiga
// qo'llash va ikki konteyner (egasining xizmatlari mehmon paytida ham tirik).

import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/data/session_close.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_kirish.dart';

const _owner = DeviceAccount(
  childId: 'o',
  name: 'Aziza',
  owner: true,
  login: 'aziza.k24',
  deviceKey: true,
  sessionId: 'sid-o',
);
const _guest = DeviceAccount(
  childId: 'g',
  name: 'Jasur',
  owner: false,
  login: 'jasur.k07',
  sessionId: 'sid-g',
);

Future<AccountRegistry> _registry({bool guestActive = false}) async {
  final reg = AccountRegistry(MemoryAccountStore());
  await reg.upsert(_owner, activate: true);
  await reg.upsert(_guest, activate: guestActive);
  if (!guestActive) await reg.activate('o');
  return reg;
}

class _ThrowingStore implements AccountStore {
  final writes = <String>[];

  @override
  Future<String?> read(String key) async => throw StateError('keystore');

  @override
  Future<void> write(String key, String? value) async => writes.add(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ro\'yxat', () {
    test('egasi mehmonga aylanmaydi; kalit va login saqlanadi', () async {
      final reg = await _registry();
      await reg.upsert(
        const DeviceAccount(
          childId: 'o',
          name: 'Aziza',
          owner: false,
          sessionId: 'sid-new',
        ),
      );
      final owner = reg.owner!;
      expect(owner.childId, 'o');
      expect(owner.deviceKey, isTrue);
      expect(owner.login, 'aziza.k24');
      expect(owner.sessionId, 'sid-new');
    });

    test('mehmon egaga aylansa mehmon tokenlari o\'chiriladi', () async {
      final reg = await _registry();
      await guestTokenStorage(
        'g',
      ).saveTokens(accessToken: 'a', refreshToken: 'r');
      await reg.upsert(
        const DeviceAccount(childId: 'g', name: 'Jasur', owner: true),
      );
      expect(reg.owner?.childId, 'g');
      expect(reg.accountById('o'), isNull);
      expect(await guestTokenStorage('g').readRefreshToken(), isNull);
    });

    test('egasi yo\'q bo\'lsa ownerClosed hech narsa qilmaydi', () async {
      final reg = AccountRegistry(MemoryAccountStore());
      await reg.ownerClosed(notice: SessionClosedReason.recovered);
      expect(reg.closedNotice, isNull);
    });

    test('A12 sababi faqat yopilgan akkaunt faol bo\'lsa', () async {
      final reg = await _registry();
      // Mehmon faol emas — egasi ishlayapti, xabar ko'rsatilmaydi.
      await reg.signOutGuest('g', notice: SessionClosedReason.recovered);
      expect(reg.accountById('g'), isNull);
      expect(reg.closedNotice, isNull);
      // Allaqachon chiqarilgan akkaunt — takroriy signal hech narsa qilmaydi.
      await reg.signOutGuest('g', notice: SessionClosedReason.other);
      expect(reg.closedNotice, isNull);

      final active = await _registry(guestActive: true);
      await active.signOutGuest('g', notice: SessionClosedReason.signedOut);
      expect(active.closedNotice, SessionClosedReason.signedOut);
      expect(active.active?.childId, 'o');
    });

    test('o\'qib bo\'lmagan ro\'yxat diskka bo\'sh yozilmaydi', () async {
      final store = _ThrowingStore();
      final reg = AccountRegistry(store);
      await reg.load();
      await reg.upsert(_guest, activate: true);
      expect(store.writes, isEmpty);
      expect(reg.activeGuest?.childId, 'g');
    });

    test('login bo\'yicha topish va qayta kirish belgisi', () async {
      final reg = await _registry();
      expect(reg.accountByLogin(' Jasur.K07 ')?.childId, 'g');
      reg.beginReauth('g');
      expect(reg.isReauthenticating('g'), isTrue);
      reg.endReauth('g');
      expect(reg.isReauthenticating('g'), isFalse);
    });
  });

  group('sessiyani joylash', () {
    test(
      'egasining o\'zi qayta kirdi — egasi qoladi, tokenlar odatiy kalitlarda',
      () async {
        SharedPreferences.setMockInitialValues({
          'parentUid': 'parent-1',
          'childId': 'o',
          'childName': 'Aziza',
        });
        final reg = await _registry();
        final pairing = FakeOwnerPairing(paired: true);
        final placement = await placeSessionWith(
          registry: reg,
          ownerPairing: pairing,
          session: FakeKirishRepository.session(childId: 'o', name: 'Aziza'),
          login: 'aziza.k24',
        );

        expect(placement, SessionPlacement.ownerInPlace);
        expect(reg.owner?.childId, 'o');
        expect(reg.owner?.deviceKey, isTrue);
        expect(reg.owner?.sessionId, 'sid-o');
        expect(reg.activeGuest, isNull);
        expect(await TokenStorage().readAccessToken(), 'access-o');
        expect(await guestTokenStorage('o').readAccessToken(), isNull);
        // Juftlash buzilmagan — qayta tiklash shart emas.
        expect(pairing.restored, isEmpty);
      },
    );

    test('qurilmada egasi bor — server MAIN desa ham mehmon', () async {
      SharedPreferences.setMockInitialValues({
        'parentUid': 'parent-1',
        'childId': 'o',
      });
      final reg = await _registry();
      final placement = await placeSessionWith(
        registry: reg,
        ownerPairing: FakeOwnerPairing(paired: true),
        session: FakeKirishRepository.session(
          childId: 'b',
          name: 'Bobur',
          role: DeviceRole.main,
        ),
        login: 'bobur.r11',
      );
      expect(placement, SessionPlacement.rebuilding);
      expect(reg.activeGuest?.childId, 'b');
      expect(reg.owner?.childId, 'o');
      // Mehmonning yozishmalari (SOS, oila) o'z ota-onasiga boradi.
      final guestState = GuestPairingNotifier(reg.activeGuest!, reg).state;
      expect(guestState.parentUid, 'parent-1');
      expect(await guestTokenStorage('b').readAccessToken(), 'access-b');
      expect(await TokenStorage().readAccessToken(), isNull);
    });

    test('yangi ega: ota-onasi aniqlanmasa joylanmaydi', () async {
      final reg = AccountRegistry(MemoryAccountStore());
      const session = ChildSession(
        accessToken: 'a',
        refreshToken: 'r',
        childId: 'n',
        childName: 'Nodira',
        role: DeviceRole.main,
      );
      await expectLater(
        placeSessionWith(
          registry: reg,
          ownerPairing: FakeOwnerPairing(),
          session: session,
          login: 'nodira.s12',
          fetchParentId: (_, _) async => null,
        ),
        throwsA(
          isA<KirishException>().having(
            (e) => e.error,
            'error',
            KirishError.network,
          ),
        ),
      );
      expect(await TokenStorage().readAccessToken(), isNull);
      expect(reg.owner, isNull);
    });
  });

  group('server signallari faqat o\'z akkauntiga', () {
    test('mehmonning child:unpaired — egasiga tegmaydi', () async {
      final reg = await _registry(guestActive: true);
      final pairing = _CountingPairing();
      await handleChildUnpaired(
        {'childId': 'g', 'reason': 'RECOVERED'},
        guest: _guest,
        registry: reg,
        pairing: pairing,
        pairedChildId: 'g',
      );
      expect(reg.accountById('g'), isNull);
      expect(reg.owner?.childId, 'o');
      expect(reg.closedNotice, SessionClosedReason.recovered);
      expect(pairing.unpaired, 0);
    });

    test('boshqa bolaning child:unpaired — e\'tiborsiz', () async {
      final reg = await _registry();
      final pairing = _CountingPairing();
      await handleChildUnpaired(
        {'childId': 'g'},
        guest: null,
        registry: reg,
        pairing: pairing,
        pairedChildId: 'o',
      );
      expect(reg.owner?.childId, 'o');
      expect(pairing.unpaired, 0);
    });

    test('egasining session:closed — uzadi; qayta kirishda — yo\'q', () async {
      final reg = await _registry();
      final pairing = _CountingPairing();
      reg.beginReauth('o');
      await handleSessionClosed(
        {
          'sessionIds': ['sid-o'],
          'reason': 'SIGNED_OUT',
        },
        guest: null,
        registry: reg,
        pairing: pairing,
      );
      expect(reg.owner?.childId, 'o');
      expect(pairing.unpaired, 0);

      reg.endReauth('o');
      await handleSessionClosed(
        {
          'sessionIds': ['sid-x', 'sid-o'],
          'reason': 'PERMISSIONS_CHANGED',
        },
        guest: null,
        registry: reg,
        pairing: pairing,
      );
      expect(reg.owner, isNull);
      expect(reg.closedNotice, SessionClosedReason.permissions);
      expect(pairing.unpaired, 1);
    });

    test('mehmonning session:closed — faqat mehmon chiqadi', () async {
      final reg = await _registry(guestActive: true);
      final pairing = _CountingPairing();
      await handleSessionClosed(
        {
          'sessionIds': ['sid-o'],
          'reason': 'RECOVERED',
        },
        guest: _guest,
        registry: reg,
        pairing: pairing,
      );
      // Boshqa (egasining) sessiyasi — mehmon konteyneri unga javob bermaydi.
      expect(reg.activeGuest?.childId, 'g');

      await handleSessionClosed(
        {
          'sessionIds': ['sid-g'],
          'reason': 'SIGNED_IN_ELSEWHERE',
        },
        guest: _guest,
        registry: reg,
        pairing: pairing,
      );
      expect(reg.accountById('g'), isNull);
      expect(reg.owner?.childId, 'o');
      expect(reg.closedNotice, SessionClosedReason.signedInElsewhere);
      expect(pairing.unpaired, 0);
    });
  });

  group('ikki konteyner', () {
    testWidgets(
      'mehmon o\'z tokenlarida; egasining xizmatlari almashganda ham tirik',
      (tester) async {
        final reg = await tester.runAsync(() => _registry(guestActive: true));
        var ownerStarts = 0;
        final ownerService = Provider<int>((ref) => ++ownerStarts);
        final seen = <String>[];

        await tester.pumpWidget(
          AccountScope(
            registry: reg!,
            overrides: [
              pairingStateProvider.overrideWith(
                (ref) => FakeOwnerPairing(paired: true),
              ),
            ],
            ownerServices: [ownerService],
            child: Consumer(
              builder: (context, ref, _) {
                seen.add(ref.watch(tokenStorageProvider).keyPrefix);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(seen.last, guestTokenScope('g'));
        expect(ownerStarts, 1);

        await tester.runAsync(() => reg.activate('o'));
        await tester.pump();
        await tester.pump();
        expect(seen.last, '');
        // Egasining konteyneri yangidan qurilmadi — xizmatlar qayta
        // ishga tushmadi.
        expect(ownerStarts, 1);
      },
    );

    testWidgets('sessiya hodisasi faqat o\'z akkauntini chiqaradi', (
      tester,
    ) async {
      final reg = await tester.runAsync(() => _registry(guestActive: true));
      await tester.pumpWidget(
        AccountScope(
          registry: reg!,
          overrides: [
            pairingStateProvider.overrideWith(
              (ref) => FakeOwnerPairing(paired: true),
            ),
          ],
          ownerServices: const [],
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(pairingStateProvider);
              return Text('${state.childId}', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );
      expect(find.text('g'), findsOneWidget);

      // Egasining hodisasi mehmonni chiqarmaydi.
      SessionEvents.notifyRevoked(scope: '');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(reg.activeGuest?.childId, 'g');

      SessionEvents.notifyRevoked(
        reason: 'RECOVERED',
        scope: guestTokenScope('g'),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();
      expect(reg.accountById('g'), isNull);
      expect(reg.closedNotice, SessionClosedReason.recovered);
      // UI egasining konteyneriga qaytdi (soxta egasi — `child-1`).
      expect(find.text('child-1'), findsOneWidget);
    });
  });
}

class _CountingPairing extends StateNotifier<AppPairingState>
    implements PairingNotifier {
  _CountingPairing() : super(const AppPairingState());

  var unpaired = 0;

  @override
  Future<void> unpair() async => unpaired++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:farzandim_child/core/auth/token_memory.dart';
import 'package:farzandim_child/core/auth/token_pair.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/fake_auth_backend.dart' show fakeJwt;
import 'secure_storage_fake.dart';

const _combinedKey = 'auth.tokens.v2';
const _legacyAccess = 'jwt_access_token';
const _legacyRefresh = 'jwt_refresh_token';
const _marker = 'auth.tokens_present.v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageFake disk;
  late TokenMemory memory;

  TokenStorage storage({String prefix = ''}) =>
      TokenStorage(keyPrefix: prefix, memory: memory);

  setUp(() {
    disk = SecureStorageFake.install();
    SharedPreferences.setMockInitialValues({});
    memory = TokenMemory();
    TokenStorage.missingRecheckDelay = Duration.zero;
  });

  group('saqlash', () {
    test('both tokens go to ONE combined key', () async {
      await storage().saveTokens(accessToken: 'a1', refreshToken: 'r1');

      expect(disk.combined(), containsPair('access', 'a1'));
      expect(disk.combined(), containsPair('refresh', 'r1'));
      expect(disk.raw(_legacyAccess), isNull);
      expect(disk.raw(_legacyRefresh), isNull);
      expect(await storage().readAccessToken(), 'a1');
      expect(await storage().readRefreshToken(), 'r1');
    });

    test('legacy two-key tokens are read and migrated', () async {
      disk = SecureStorageFake.install({
        _legacyAccess: 'old-a',
        _legacyRefresh: 'old-r',
      });

      expect(await storage().readRefreshToken(), 'old-r');
      expect(await storage().readAccessToken(), 'old-a');
      expect(disk.combined(), containsPair('refresh', 'old-r'));
      expect(disk.raw(_legacyAccess), isNull);
      expect(disk.raw(_legacyRefresh), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_marker), isTrue);
    });

    test('guest accounts keep their own keys', () async {
      await storage().saveTokens(accessToken: 'o', refreshToken: 'or');
      await storage(prefix: 'acct_g_').saveTokens(
        accessToken: 'g',
        refreshToken: 'gr',
      );

      expect(disk.combined('acct_g_'), containsPair('access', 'g'));
      expect(await storage().readAccessToken(), 'o');
      await storage(prefix: 'acct_g_').clear();
      expect(await storage(prefix: 'acct_g_').readRefreshToken(), isNull);
      expect(await storage().readRefreshToken(), 'or');
    });

    test('clear removes the combined key, legacy keys and the marker', () async {
      disk = SecureStorageFake.install({_legacyRefresh: 'old-r'});
      await storage().saveTokens(accessToken: 'a', refreshToken: 'r');
      await storage().clear();

      expect(disk.raw(_combinedKey), isNull);
      expect(disk.raw(_legacyRefresh), isNull);
      expect(storage().cachedPair, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_marker), isNull);
    });
  });

  group('xotira', () {
    test('requests read secure storage once per isolate', () async {
      disk = SecureStorageFake.install({
        _combinedKey: const TokenPair(accessToken: 'a', refreshToken: 'r')
            .encode(),
      });

      final tokens = await Future.wait([
        for (var i = 0; i < 5; i++) storage().accessTokenForRequest(),
      ]);
      for (var i = 0; i < 5; i++) {
        await TokenStorage(memory: memory).accessTokenForRequest();
      }

      expect(tokens, everyElement('a'));
      expect(disk.readsOf(_combinedKey), 1);
    });

    test('an older stored pair never replaces a newer cached one', () async {
      final newer = TokenPair(accessToken: fakeJwt(200), refreshToken: 'r2');
      final older = TokenPair(accessToken: fakeJwt(100), refreshToken: 'r1');
      await storage().saveTokens(
        accessToken: newer.accessToken,
        refreshToken: newer.refreshToken,
      );
      disk[_combinedKey] = older.encode(); // boshqa isolate eskisini yozdi

      await storage().reload();

      expect(storage().cachedPair, newer);
    });

    test('a newer stored pair (other isolate refreshed) is adopted', () async {
      await storage().saveTokens(
        accessToken: fakeJwt(100),
        refreshToken: 'r1',
      );
      final newer = TokenPair(accessToken: fakeJwt(200), refreshToken: 'r2');
      disk[_combinedKey] = newer.encode();

      await storage().reload();

      expect(storage().cachedPair, newer);
    });
  });

  group('noma\'lum o\'qish', () {
    test('sticky null keeps the cached token and is not "missing"', () async {
      await storage().saveTokens(accessToken: 'a', refreshToken: 'r');
      disk.stickyNull = true;

      expect(await storage().accessTokenForRequest(), 'a');
      expect(await storage().isSessionDefinitelyMissing(), isFalse);
      expect(storage().cachedPair?.refreshToken, 'r');
    });

    test('a failing read is unknown, never "missing"', () async {
      await storage().saveTokens(accessToken: 'a', refreshToken: 'r');
      disk.failReads = true;

      expect(await storage().isSessionDefinitelyMissing(), isFalse);
      expect(await storage().readAccessToken(), 'a');
      expect(await storage().hasValidSession(), isTrue);
    });

    test('a failing first read sends no token instead of throwing', () async {
      disk.failReads = true;

      expect(await storage().accessTokenForRequest(), isNull);
      await expectLater(storage().readAccessToken(), throwsA(anything));
    });

    test('corrupt combined key is unknown, not missing', () async {
      disk = SecureStorageFake.install({_combinedKey: '{buzilgan'});

      expect(await storage().isSessionDefinitelyMissing(), isFalse);
    });
  });

  group('isSessionDefinitelyMissing', () {
    test('true only after two clean empty reads without the marker', () async {
      expect(await storage().isSessionDefinitelyMissing(), isTrue);
      // yangi + 2 eski kalit, ikki marta.
      expect(disk.readsOf(_combinedKey), 2);
      expect(disk.readsOf(_legacyRefresh), 2);
    });

    test('tokens appearing before the second read count as present', () async {
      disk.onRead = (key, count) {
        if (key == _combinedKey && count == 2) {
          disk[_combinedKey] = const TokenPair(
            accessToken: 'a',
            refreshToken: 'r',
          ).encode();
        }
      };

      expect(await storage().isSessionDefinitelyMissing(), isFalse);
    });

    test('the "tokens saved" marker vetoes an empty secure storage', () async {
      SharedPreferences.setMockInitialValues({_marker: true});

      expect(await storage().isSessionDefinitelyMissing(), isFalse);
    });
  });

  test('a read racing clear() cannot bring the session back', () async {
    await storage().saveTokens(accessToken: 'a', refreshToken: 'r');

    final clearing = storage().clear();
    await storage().accessTokenForRequest(); // o'chirishdan oldin o'qishi mumkin
    await clearing;
    await Future<void>.delayed(Duration.zero);

    expect(storage().cachedPair, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_marker), isNull);
    expect(await storage().isSessionDefinitelyMissing(), isTrue);
  });

  test('clearIfCurrent keeps a newer pair written meanwhile', () async {
    await storage().saveTokens(accessToken: 'a1', refreshToken: 'r1');
    disk[_combinedKey] = const TokenPair(
      accessToken: 'a2',
      refreshToken: 'r2',
    ).encode();

    expect(await storage().clearIfCurrent('r1'), isFalse);
    expect(await storage().readRefreshToken(), 'r2');
    expect(await storage().clearIfCurrent('r2'), isTrue);
    expect(await storage().readRefreshToken(), isNull);
  });
}

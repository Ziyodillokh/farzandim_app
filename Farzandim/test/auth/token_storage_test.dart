// TokenStorage — "o'zidan login'ga chiqib ketish"ga qarshi kafolatlar:
// xotira keshi, atomik juftlik, Keystore xatosi/null'da sessiya saqlanishi.

import 'dart:async';
import 'dart:convert';

import 'package:farzandim/core/auth/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/memory_token_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryBackend backend;
  late TokenStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TokenStorage.resetCacheForTest();
    backend = MemoryBackend();
    storage = TokenStorage(backend: backend);
  });

  Future<bool?> marker() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(TokenStorage.kTokensPresentKey);
  }

  group('saqlash va o`qish', () {
    test(
      'saqlangan juftlik keshdan o`qiladi (xotiraga qayta murojaat yo`q)',
      () async {
        await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
        backend.failReads = true;

        expect(await storage.readAccessToken(), 'A1');
        expect(await storage.readRefreshToken(), 'R1');
        expect(backend.reads, 0);
        expect(await marker(), isTrue);
      },
    );

    test('juftlik bitta kalitda va eski ikki kalitda yoziladi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');

      final pair = jsonDecode(backend.store['jwt_tokens_v2']!) as Map;
      expect(pair, {'a': 'A1', 'r': 'R1'});
      expect(backend.store['jwt_access_token'], 'A1');
      expect(backend.store['jwt_refresh_token'], 'R1');
    });

    test('yangi jarayon (kesh bo`sh) juftlik kalitidan o`qiydi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      TokenStorage.resetCacheForTest();

      expect(await TokenStorage(backend: backend).readRefreshToken(), 'R1');
      expect(await TokenStorage(backend: backend).readAccessToken(), 'A1');
    });

    test(
      'eski versiya (faqat ikki kalit) o`qiladi va belgi qo`yiladi',
      () async {
        backend.store['jwt_access_token'] = 'oldA';
        backend.store['jwt_refresh_token'] = 'oldR';

        expect(await storage.reload(), TokenReadResult.found);
        expect(await storage.readAccessToken(), 'oldA');
        expect(await storage.readRefreshToken(), 'oldR');
        expect(await marker(), isTrue);
      },
    );
  });

  group('yangilash (refresh javobi)', () {
    test('ikkala token bitta yozuvda yangilanadi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');

      await storage.updateTokens(accessToken: 'A2', refreshToken: 'R2');

      final pair = jsonDecode(backend.store['jwt_tokens_v2']!) as Map;
      expect(pair, {'a': 'A2', 'r': 'R2'});
      TokenStorage.resetCacheForTest();
      expect(await storage.readRefreshToken(), 'R2');
    });

    test('yozish xato bersa ham kesh yangi juftda qoladi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      backend.failWrites = true;

      await storage.updateTokens(accessToken: 'A2', refreshToken: 'R2');

      expect(await storage.readAccessToken(), 'A2');
      expect(await storage.readRefreshToken(), 'R2');
    });

    test('faqat access kelsa refresh saqlanib qoladi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');

      await storage.updateTokens(accessToken: 'A2');

      final pair = jsonDecode(backend.store['jwt_tokens_v2']!) as Map;
      expect(pair, {'a': 'A2', 'r': 'R1'});
    });
  });

  group('reload', () {
    test('sekin o`qish yangi saqlangan tokenni bosib ketmaydi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      TokenStorage.resetCacheForTest();
      final gate = Completer<void>();
      backend.readGate = gate.future;

      // Ishga tushishdagi o'qish eski juftni o'qiyapti (sekin Keystore)...
      final pending = storage.readRefreshToken();
      // ...shu payt yangi juft saqlandi (refresh / qayta kirish).
      await storage.saveTokens(accessToken: 'A2', refreshToken: 'R2');
      gate.complete();

      expect(await pending, 'R2');
      expect(await storage.readAccessToken(), 'A2');
    });

    test('bir vaqtdagi o`qishlar bitta murojaat bilan bajariladi', () async {
      backend.store['jwt_tokens_v2'] = jsonEncode({'a': 'A1', 'r': 'R1'});

      final results = await Future.wait([
        storage.readAccessToken(),
        storage.readRefreshToken(),
        storage.readAccessToken(),
      ]);

      expect(results, ['A1', 'R1', 'A1']);
      expect(backend.reads, 1);
    });

    test('buzilgan juftlik — eski kalitlardan o`qiladi', () async {
      backend.store['jwt_tokens_v2'] = '{buzilgan';
      backend.store['jwt_access_token'] = 'A1';
      backend.store['jwt_refresh_token'] = 'R1';

      expect(await storage.reload(), TokenReadResult.found);
      expect(await storage.readRefreshToken(), 'R1');
    });

    test('o`qish xatosi keshni o`zgartirmaydi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      backend.failReads = true;

      expect(await storage.reload(), TokenReadResult.failed);
      expect(await storage.readRefreshToken(), 'R1');
    });

    test('yuklangan keshni "doim null" o`qish o`chirmaydi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      backend.nullReads = true;

      expect(await storage.reload(), TokenReadResult.absent);
      expect(await storage.readRefreshToken(), 'R1');
    });

    test('xotirada yangiroq juftlik bo`lsa kesh yangilanadi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      backend.store['jwt_tokens_v2'] = jsonEncode({'a': 'A2', 'r': 'R2'});

      expect(await storage.reload(), TokenReadResult.found);
      expect(await storage.readRefreshToken(), 'R2');
    });
  });

  group('sessiya bormi (startup)', () {
    test('yangi o`rnatish — sessiya aniq yo`q', () async {
      expect(await storage.isSessionDefinitelyMissing(), isTrue);
      expect(await storage.hasValidSession(), isFalse);
    });

    test('Keystore null qaytarsa ham belgi bor — chiqarilmaydi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      TokenStorage.resetCacheForTest();
      backend.nullReads = true;

      expect(await storage.hasValidSession(), isTrue);
    });

    test('Keystore buzilgan (ketma-ket o`qilmadi) — oxiri login', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      backend.failReads = true;
      final results = <bool>[];

      for (var start = 0; start < TokenStorage.maxUnreadableStarts; start++) {
        TokenStorage.resetCacheForTest();
        results.add(await storage.isSessionDefinitelyMissing());
      }

      expect(results, [
        ...List.filled(TokenStorage.maxUnreadableStarts - 1, false),
        true,
      ]);
      expect(await marker(), isNull);
    });

    test('o`qish tiklansa hisoblagich nolga qaytadi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      backend.nullReads = true;
      TokenStorage.resetCacheForTest();
      expect(await storage.isSessionDefinitelyMissing(), isFalse);

      backend.nullReads = false;
      TokenStorage.resetCacheForTest();
      expect(await storage.isSessionDefinitelyMissing(), isFalse);

      backend.nullReads = true;
      TokenStorage.resetCacheForTest();
      expect(await storage.isSessionDefinitelyMissing(), isFalse);
      expect(await marker(), isTrue);
    });

    test('belgi yo`q, o`qish xato — noma`lum, chiqarilmaydi', () async {
      backend.failReads = true;

      expect(await storage.isSessionDefinitelyMissing(), isFalse);
    });

    test(
      'belgi yo`q (eski o`rnatish), tokenlar xotirada — sessiya bor',
      () async {
        backend.store['jwt_tokens_v2'] = jsonEncode({'a': 'A1', 'r': 'R1'});

        expect(await storage.hasValidSession(), isTrue);
        expect(await marker(), isTrue);
      },
    );

    test('o`chirish xato bersa ham logout tugaydi', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');
      backend.failDeletes = true;

      await storage.clear();

      expect(await storage.readRefreshToken(), isNull);
      expect(await marker(), isNull);
    });

    test('logout (clear) dan keyin sessiya aniq yo`q', () async {
      await storage.saveTokens(accessToken: 'A1', refreshToken: 'R1');

      await storage.clear();

      expect(backend.store, isEmpty);
      expect(await marker(), isNull);
      expect(await storage.readRefreshToken(), isNull);
      TokenStorage.resetCacheForTest();
      expect(await storage.isSessionDefinitelyMissing(), isTrue);
    });
  });
}

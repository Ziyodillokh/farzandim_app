// Til sinxronizatsiyasi: `PUT /users/me {language}` ulangandan keyin va til
// almashganda; shu hisobga yozilgan til qayta yuborilmaydi; xato bo'lsa
// keyingi safar qayta uriniladi. Hisob — bola foydalanuvchisi: qayta
// ulanganda (yangi foydalanuvchi, o'sha `childId`) til qayta yoziladi.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farzandim_child/features/account/data/language_sync_service.dart';
import 'package:farzandim_child/features/account/presentation/providers/language_sync_provider.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/fake_http_adapter.dart';

/// Server: [isOnline] bo'lmasa javob kelmaydi; so'rovlar yoziladi.
class _Server {
  bool isOnline = true;
  final requests = <RequestOptions>[];

  List<Object?> get languages => [
    for (final r in requests) (r.data as Map)['language'],
  ];

  Dio dio() =>
      Dio(BaseOptions(baseUrl: 'https://api.test/api'))
        ..httpClientAdapter = _SwitchableAdapter(this);
}

class _SwitchableAdapter implements HttpClientAdapter {
  _SwitchableAdapter(this.server);

  final _Server server;
  final _ok = FakeHttpAdapter((o) => (200, {'id': 'u1', 'language': 'ru'}));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (!server.isOnline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    server.requests.add(options);
    return _ok.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Server server;
  late LanguageSyncService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = _Server();
    service = LanguageSyncService(server.dio());
  });

  test('birinchi marta yoziladi, takrorida so\'rov yo\'q', () async {
    expect(
      await service.sync(account: 'child-1', language: 'ru'),
      LanguageSyncResult.written,
    );
    expect(
      await service.sync(account: 'child-1', language: 'ru'),
      LanguageSyncResult.unchanged,
    );

    expect(server.requests.single.method, 'PUT');
    expect(server.requests.single.path, '/users/me');
    expect(server.languages, ['ru']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSyncedLanguageKey), 'child-1:ru');
  });

  test('til yoki hisob o\'zgarsa qayta yoziladi', () async {
    await service.sync(account: 'child-1', language: 'ru');
    await service.sync(account: 'child-1', language: 'uz');
    // Boshqa bolaga qayta ulangan — yangi hisobda til hali standart.
    await service.sync(account: 'child-2', language: 'uz');

    expect(server.languages, ['ru', 'uz', 'uz']);
  });

  test('server bilmaydigan til yuborilmaydi', () async {
    expect(
      await service.sync(account: 'child-1', language: 'de'),
      LanguageSyncResult.failed,
    );
    expect(
      await service.sync(account: '', language: 'ru'),
      LanguageSyncResult.failed,
    );
    expect(
      await service.sync(account: 'child-1', language: 'EN'),
      LanguageSyncResult.written,
    );

    expect(server.languages, ['en']);
  });

  test('oflayn — eslab qolinmaydi, keyingi safar qayta yuboriladi', () async {
    server.isOnline = false;
    expect(
      await service.sync(account: 'child-1', language: 'ru'),
      LanguageSyncResult.failed,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSyncedLanguageKey), isNull);

    server.isOnline = true;
    expect(
      await service.sync(account: 'child-1', language: 'ru'),
      LanguageSyncResult.written,
    );
    expect(server.languages, ['ru']);
  });

  test(
    'parallel chaqiruvlar ketma-ket bajariladi — oxirgi til yutadi',
    () async {
      await Future.wait([
        service.sync(account: 'child-1', language: 'ru'),
        service.sync(account: 'child-1', language: 'ru'),
        service.sync(account: 'child-1', language: 'en'),
      ]);

      expect(server.languages, ['ru', 'en']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kSyncedLanguageKey), 'child-1:en');
    },
  );

  group('languageAccountOf — hisob bola foydalanuvchisi bo\'yicha', () {
    AppPairingState paired({String? userId}) => AppPairingState(
      status: PairingStatus.paired,
      parentUid: 'parent-1',
      childId: 'child-1',
      currentUserId: userId,
    );

    test('ulanmagan — hisob yo\'q', () {
      expect(languageAccountOf(const AppPairingState()), isNull);
      expect(
        languageAccountOf(const AppPairingState(status: PairingStatus.pairing)),
        isNull,
      );
    });

    test('qayta ulanish (yangi foydalanuvchi, o\'sha bola) — yangi hisob', () {
      final first = languageAccountOf(paired(userId: 'user-1'));
      final again = languageAccountOf(paired(userId: 'user-2'));
      expect(first, 'user-1');
      expect(again, 'user-2');
    });

    test('foydalanuvchi id\'si yo\'q eski ulanish — childId', () {
      expect(languageAccountOf(paired()), 'child-1');
      expect(languageAccountOf(paired(userId: '  ')), 'child-1');
    });

    test(
      'qayta ulangandan keyin ruscha til yangi hisobga qayta yoziladi',
      () async {
        final first = languageAccountOf(paired(userId: 'user-1'))!;
        final again = languageAccountOf(paired(userId: 'user-2'))!;
        await service.sync(account: first, language: 'ru');
        await service.sync(account: again, language: 'ru');

        expect(server.languages, ['ru', 'ru']);
      },
    );
  });

  group('languageSyncProvider', () {
    final account = StateProvider<String?>((ref) => null);

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          languageSyncServiceProvider.overrideWithValue(service),
          languageSyncAccountProvider.overrideWith((ref) => ref.watch(account)),
        ],
      );
      addTearDown(c.dispose);
      // `main.dart` kabi — doim kuzatiladi.
      c.listen(languageSyncProvider, (_, _) {});
      return c;
    }

    /// Provider darhol qayta quriladi, so'ng navbatdagi so'rovlar tugaydi
    /// (bo'sh hisob — navbat oxiridagi so'rovsiz belgi).
    Future<void> settle(ProviderContainer c) {
      c.read(languageSyncProvider);
      return service.sync(account: '', language: '');
    }

    test('til aniqlanmaguncha yoki ulanmaguncha yuborilmaydi', () async {
      final c = container();
      c.read(account.notifier).state = 'child-1';
      await settle(c);
      expect(server.requests, isEmpty);

      c.read(account.notifier).state = null;
      c.read(appLanguageProvider.notifier).state = 'ru';
      await settle(c);
      expect(server.requests, isEmpty);
    });

    test('ulangandan keyin va til almashganda yoziladi', () async {
      final c = container();
      c.read(appLanguageProvider.notifier).state = 'ru';
      c.read(account.notifier).state = 'child-1';
      await settle(c);
      expect(server.languages, ['ru']);

      c.read(appLanguageProvider.notifier).state = 'en';
      await settle(c);
      expect(server.languages, ['ru', 'en']);
    });

    test('yozilganda maktab matnlari uchun versiya oshadi', () async {
      final c = container();
      c.read(appLanguageProvider.notifier).state = 'ru';
      c.read(account.notifier).state = 'user-1';
      await settle(c);
      expect(c.read(syncedLanguageRevisionProvider), 1);

      // Shu til qayta yuborilmaydi — versiya o'zgarmaydi.
      c.invalidate(languageSyncProvider);
      await settle(c);
      expect(c.read(syncedLanguageRevisionProvider), 1);

      c.read(appLanguageProvider.notifier).state = 'en';
      await settle(c);
      expect(c.read(syncedLanguageRevisionProvider), 2);
    });

    test('xato bo\'lsa qayta urinish (invalidate) tilni yozadi', () async {
      final c = container();
      server.isOnline = false;
      c.read(appLanguageProvider.notifier).state = 'ru';
      c.read(account.notifier).state = 'user-1';
      await settle(c);
      expect(server.requests, isEmpty);
      expect(c.read(syncedLanguageRevisionProvider), 0);

      server.isOnline = true;
      c.invalidate(languageSyncProvider);
      await settle(c);
      expect(server.languages, ['ru']);
      expect(c.read(syncedLanguageRevisionProvider), 1);
    });
  });
}

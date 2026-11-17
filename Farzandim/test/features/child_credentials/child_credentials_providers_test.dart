// Kirish ma'lumotlari provayderlari va amallari: muvaffaqiyatda holat va
// so'rovlar qayta o'qiladi; qurilmalardan chiqarilganda bolalar ro'yxati
// yangilanadi; xato tipli natija bo'lib qaytadi; ochiq bo'lmagan so'rovlar
// ko'rinmaydi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/child_credentials/data/child_credentials_repository.dart';
import 'package:farzandim/features/child_credentials/data/credentials_failure.dart';
import 'package:farzandim/features/child_credentials/data/models/child_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/issued_credentials.dart';
import 'package:farzandim/features/child_credentials/data/models/recovery_request.dart';
import 'package:farzandim/features/child_credentials/presentation/providers/child_credentials_providers.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository extends ChildCredentialsRepository {
  _FakeRepository() : super(dio: Dio());

  int credentialFetches = 0;
  int recoveryFetches = 0;
  final List<String> calls = [];

  /// Berilsa, yozuv amallari shuni otadi.
  CredentialsFailure? failure;

  /// Berilsa, `issueCredentials` dastur xatosini (`Error`) otadi.
  Error? crash;

  ChildCredentials? stored = const ChildCredentials(
    login: 'aziza.k24',
    issuedBy: CredentialsIssuer.parent,
    mustChangePassword: true,
  );

  List<RecoveryRequest> recovery = const [
    RecoveryRequest(
      id: 'open',
      channel: RecoveryChannel.parent,
      status: RecoveryStatus.received,
    ),
    RecoveryRequest(
      id: 'closed',
      channel: RecoveryChannel.parent,
      status: RecoveryStatus.restored,
    ),
  ];

  @override
  Future<ChildCredentials?> fetchCredentials(String childId) async {
    credentialFetches++;
    return stored;
  }

  @override
  Future<List<RecoveryRequest>> fetchRecoveryRequests(String childId) async {
    recoveryFetches++;
    return recovery;
  }

  @override
  Future<IssuedCredentials> issueCredentials(
    String childId, {
    String? login,
  }) async {
    calls.add('issue:$childId:${login ?? '-'}');
    if (crash case final error?) throw error;
    final error = failure;
    if (error != null) throw error;
    return IssuedCredentials(
      login: login ?? 'aziza.k24',
      temporaryPassword: 'k7m2xq9p',
    );
  }

  @override
  Future<IssuedCredentials> resetCredentials(
    String childId, {
    required bool signOutDevices,
  }) async {
    calls.add('reset:$childId:$signOutDevices');
    final error = failure;
    if (error != null) throw error;
    return const IssuedCredentials(
      login: 'aziza.k24',
      temporaryPassword: 'p4s9wxz2',
    );
  }

  @override
  Future<void> rejectRecoveryRequest(String childId, String requestId) async {
    calls.add('reject:$childId:$requestId');
    final error = failure;
    if (error != null) throw error;
  }
}

void main() {
  late _FakeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeRepository();
    container = ProviderContainer(
      overrides: [childCredentialsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  ChildCredentialsActions actions() =>
      container.read(childCredentialsActionsProvider);

  /// Provayderlarni tirik ushlab turadi (ekran ochiq turganidek).
  void listenBoth(String childId) {
    container
      ..listen(childCredentialsProvider(childId), (_, _) {})
      ..listen(childRecoveryRequestsProvider(childId), (_, _) {});
  }

  group('holat provayderlari', () {
    test('kirish ma`lumotlari repositorydan o`qiladi', () async {
      final credentials = await container.read(
        childCredentialsProvider('kid-1').future,
      );
      expect(credentials!.login, 'aziza.k24');
      expect(credentials.isFirstLoginPending, isTrue);
    });

    test('berilmagan bola → null', () async {
      repo.stored = null;
      expect(
        await container.read(childCredentialsProvider('kid-1').future),
        isNull,
      );
    });

    test('faqat ochiq so`rovlar ko`rinadi', () async {
      final requests = await container.read(
        childRecoveryRequestsProvider('kid-1').future,
      );
      expect(requests.map((r) => r.id), ['open']);
    });
  });

  group('issue / reset', () {
    test('birinchi berish: parol natijada, holat qayta o`qiladi', () async {
      listenBoth('kid-1');
      await container.read(childCredentialsProvider('kid-1').future);
      await container.read(childRecoveryRequestsProvider('kid-1').future);
      expect(repo.credentialFetches, 1);
      expect(repo.recoveryFetches, 1);

      final result = await actions().issue('kid-1', login: 'aziza.k24');

      expect(result.isSuccess, isTrue);
      expect(result.data!.temporaryPassword, 'k7m2xq9p');
      expect(repo.calls, ['issue:kid-1:aziza.k24']);
      await container.read(childCredentialsProvider('kid-1').future);
      await container.read(childRecoveryRequestsProvider('kid-1').future);
      expect(repo.credentialFetches, 2);
      expect(repo.recoveryFetches, 2);
    });

    test(
      'yangilash: signOutDevices yoqilsa bolalar ro`yxati yangilanadi',
      () async {
        final before = container.read(childrenRefreshTickProvider);

        final result = await actions().reset('kid-1', signOutDevices: true);

        expect(result.isSuccess, isTrue);
        expect(result.data!.temporaryPassword, 'p4s9wxz2');
        expect(repo.calls, ['reset:kid-1:true']);
        expect(container.read(childrenRefreshTickProvider), before + 1);
      },
    );

    test('yangilash: signOutDevices o`chiq — ro`yxat tegilmaydi', () async {
      final before = container.read(childrenRefreshTickProvider);

      final result = await actions().reset('kid-1', signOutDevices: false);

      expect(result.isSuccess, isTrue);
      expect(repo.calls, ['reset:kid-1:false']);
      expect(container.read(childrenRefreshTickProvider), before);
    });

    test('xato: tipli natija, holat qayta o`qilmaydi', () async {
      listenBoth('kid-1');
      await container.read(childCredentialsProvider('kid-1').future);
      repo.failure = const CredentialsFailure(
        CredentialsFailureKind.loginTaken,
        code: 'LOGIN_TAKEN',
        statusCode: 409,
      );

      final result = await actions().issue('kid-1', login: 'band.login');

      expect(result.isSuccess, isFalse);
      expect(result.failure!.kind, CredentialsFailureKind.loginTaken);
      expect(result.data, isNull);
      expect(repo.credentialFetches, 1);
    });

    test('yangilash xatosida bolalar ro`yxati yangilanmaydi', () async {
      repo.failure = const CredentialsFailure(CredentialsFailureKind.network);
      final before = container.read(childrenRefreshTickProvider);

      final result = await actions().reset('kid-1', signOutDevices: true);

      expect(result.failure!.kind, CredentialsFailureKind.network);
      expect(container.read(childrenRefreshTickProvider), before);
    });

    test(
      'login yaroqsiz yoki band — server holati o`zgarmagan, qayta o`qilmaydi',
      () async {
        listenBoth('kid-1');
        await container.read(childCredentialsProvider('kid-1').future);

        for (final kind in [
          CredentialsFailureKind.validation,
          CredentialsFailureKind.loginTaken,
        ]) {
          repo.failure = CredentialsFailure(kind);
          final result = await actions().issue('kid-1', login: 'aziza.k24');
          expect(result.failure!.kind, kind);
        }

        expect(repo.credentialFetches, 1);
      },
    );

    test('boshqa xatolarda holat qayta o`qiladi', () async {
      // So'rov serverda bajarilgan bo'lishi mumkin (javob yo'qolgan): ekran
      // holatni qayta o'qiydi.
      listenBoth('kid-1');
      await container.read(childCredentialsProvider('kid-1').future);
      var expected = 1;

      for (final kind in [
        CredentialsFailureKind.network,
        CredentialsFailureKind.server,
        CredentialsFailureKind.tooManyAttempts,
        CredentialsFailureKind.notFound,
        CredentialsFailureKind.forbidden,
        CredentialsFailureKind.sessionExpired,
        CredentialsFailureKind.unknown,
      ]) {
        repo.failure = CredentialsFailure(kind);
        final result = await actions().issue('kid-1');
        expect(result.failure!.kind, kind);
        await container.read(childCredentialsProvider('kid-1').future);
        expected++;
        expect(repo.credentialFetches, expected, reason: kind.name);
      }
    });

    test('dastur xatosi (Error) yashirilmaydi: chaqiruvchiga yetadi', () async {
      repo.crash = StateError('kutilmagan');

      await expectLater(actions().issue('kid-1'), throwsStateError);
    });

    test('Dio xatosi ham CredentialsFailure bo`lib qaytadi', () async {
      final repoWithDio = _DioFailingRepository();
      final c = ProviderContainer(
        overrides: [
          childCredentialsRepositoryProvider.overrideWithValue(repoWithDio),
        ],
      );
      addTearDown(c.dispose);

      final result = await c
          .read(childCredentialsActionsProvider)
          .reset('kid-1', signOutDevices: true);

      expect(result.failure!.kind, CredentialsFailureKind.tooManyAttempts);
    });
  });

  group('rejectRecovery', () {
    test('muvaffaqiyat: so`rovlar ro`yxati qayta o`qiladi', () async {
      listenBoth('kid-1');
      await container.read(childRecoveryRequestsProvider('kid-1').future);

      final result = await actions().rejectRecovery('kid-1', 'open');

      expect(result.isSuccess, isTrue);
      expect(repo.calls, ['reject:kid-1:open']);
      await container.read(childRecoveryRequestsProvider('kid-1').future);
      expect(repo.recoveryFetches, 2);
    });

    test(
      'server xatosi: ro`yxat qayta o`qiladi (so`rov hal bo`lgan)',
      () async {
        listenBoth('kid-1');
        await container.read(childRecoveryRequestsProvider('kid-1').future);
        repo.failure = const CredentialsFailure(
          CredentialsFailureKind.notFound,
        );

        final result = await actions().rejectRecovery('kid-1', 'open');

        expect(result.failure!.kind, CredentialsFailureKind.notFound);
        await container.read(childRecoveryRequestsProvider('kid-1').future);
        expect(repo.recoveryFetches, 2);
      },
    );

    test('tarmoq xatosi: ro`yxat tegilmaydi', () async {
      listenBoth('kid-1');
      await container.read(childRecoveryRequestsProvider('kid-1').future);
      repo.failure = const CredentialsFailure(CredentialsFailureKind.network);

      final result = await actions().rejectRecovery('kid-1', 'open');

      expect(result.failure!.kind, CredentialsFailureKind.network);
      expect(repo.recoveryFetches, 1);
    });
  });
}

class _DioFailingRepository extends ChildCredentialsRepository {
  _DioFailingRepository() : super(dio: Dio());

  @override
  Future<IssuedCredentials> resetCredentials(
    String childId, {
    required bool signOutDevices,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 429,
      ),
    );
  }
}

// Erta ketish provayderlari (soxta repository bilan): ro'yxat login'ga
// bog'langan, yangi so'rov `Result` qaytaradi, muvaffaqiyat va 409 da faqat
// ochiq ro'yxat qayta so'raladi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_early_exit_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  Exception? requestError;
  int listFetches = 0;
  int linkFetches = 0;
  final List<String> requests = [];

  @override
  Future<SchoolLinks> fetchLinks() async {
    linkFetches++;
    return SchoolLinks.empty;
  }

  @override
  Future<List<EarlyExitRequest>> fetchEarlyExits() async {
    listFetches++;
    return [
      EarlyExitRequest.fromJson(const {
        'id': 'e-1',
        'studentId': 'st-1',
        'date': '2026-10-20',
        'time': '13:30',
        'reason': 'Shifokor',
        'pickupBy': 'Onasi',
        'status': 'PENDING',
        'studentName': 'Karimov Aziz',
        'requestedByMe': true,
      }),
    ];
  }

  @override
  Future<EarlyExitRequest> requestEarlyExit({
    required String studentId,
    required String time,
    required String reason,
    required String pickupBy,
  }) async {
    requests.add('$studentId|$time|$reason|$pickupBy');
    final error = requestError;
    if (error != null) throw error;
    return EarlyExitRequest.fromJson({
      'id': 'e-2',
      'studentId': studentId,
      'time': time,
      'status': 'PENDING',
    });
  }
}

void main() {
  late _FakeSchoolRepository repo;

  ProviderContainer makeContainer({bool signedIn = true}) {
    final container = ProviderContainer(
      overrides: [
        schoolRepositoryProvider.overrideWithValue(repo),
        schoolSignedInProvider.overrideWithValue(signedIn),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Ekran ochiq: ro'yxat va bog'lanishlar tinglanadi.
  Future<void> openList(ProviderContainer container) async {
    final list = container.listen(schoolEarlyExitsProvider, (_, _) {});
    final links = container.listen(schoolLinksProvider, (_, _) {});
    addTearDown(list.close);
    addTearDown(links.close);
    await container.read(schoolEarlyExitsProvider.future);
    await container.read(schoolLinksProvider.future);
  }

  Future<void> settle(ProviderContainer container) async {
    await container.pump();
    await pumpEventQueue();
  }

  setUp(() => repo = _FakeSchoolRepository());

  group('schoolEarlyExitsProvider', () {
    test('ro`yxat yuklanadi', () async {
      final container = makeContainer();
      final sub = container.listen(schoolEarlyExitsProvider, (_, _) {});
      addTearDown(sub.close);

      final list = await container.read(schoolEarlyExitsProvider.future);
      expect(list.single.isPending, isTrue);
      expect(repo.listFetches, 1);
    });

    test('kirilmagan — so`rovsiz xato', () async {
      final container = makeContainer(signedIn: false);
      final sub = container.listen(schoolEarlyExitsProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(schoolEarlyExitsProvider.future),
        throwsA(const SchoolFailure(SchoolFailureKind.sessionExpired)),
      );
      expect(repo.listFetches, 0);
    });
  });

  group('EarlyExitActionsNotifier.request', () {
    /// So'rov yuboradi; xato xabari (`null` — muvaffaqiyat).
    Future<String?> send(ProviderContainer container) async {
      final result = await container
          .read(earlyExitActionsProvider.notifier)
          .request(
            studentId: 'st-1',
            time: '13:30',
            reason: 'Shifokor',
            pickupBy: 'Onasi',
          );
      await settle(container);
      return result.error;
    }

    test('muvaffaqiyat → ochiq ro`yxat yangilanadi', () async {
      final container = makeContainer();
      await openList(container);

      expect(await send(container), isNull);
      expect(repo.requests, ['st-1|13:30|Shifokor|Onasi']);
      expect(repo.listFetches, 2);
      expect(repo.linkFetches, 1);
    });

    test('409 (bugun kutilayotgan so`rov bor) → xabar + yangilash', () async {
      repo.requestError = const SchoolFailure(
        SchoolFailureKind.earlyExitPending,
      );
      final container = makeContainer();
      await openList(container);

      // easy_localization testda yuklanmagan — `.tr()` kalitni qaytaradi.
      expect(await send(container), 'school.errors.earlyExitPending');
      expect(repo.listFetches, 2);
      expect(repo.linkFetches, 2);
      expect(
        container.read(earlyExitActionsProvider).error,
        const SchoolFailure(SchoolFailureKind.earlyExitPending),
      );
    });

    test('tarmoq xatosi → xabar, ro`yxatlar qayta so`ralmaydi', () async {
      repo.requestError = const SchoolFailure(SchoolFailureKind.network);
      final container = makeContainer();
      await openList(container);

      expect(await send(container), 'errors.noInternet');
      expect(repo.listFetches, 1);
      expect(repo.linkFetches, 1);
    });

    test('ekran yopiq — ro`yxat qayta yaratilmaydi', () async {
      final container = makeContainer();

      expect(await send(container), isNull);
      expect(repo.listFetches, 0);
    });
  });
}

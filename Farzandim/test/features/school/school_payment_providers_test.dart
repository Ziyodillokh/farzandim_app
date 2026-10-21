// To'lov provayderlari (soxta repository bilan): eslatmalar va so'rovlar
// login'ga bog'langan; "To'laganman, tekshiring" `Result` qaytaradi,
// muvaffaqiyat va 409 da ikkala ochiq ro'yxat qayta so'raladi.

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  Exception? createError;
  bool openVerification = false;
  int paymentFetches = 0;
  int verificationFetches = 0;
  final List<String> created = [];

  @override
  Future<List<SchoolPaymentReminder>> fetchPayments() async {
    paymentFetches++;
    return [
      SchoolPaymentReminder.fromJson({
        'id': 'p-1',
        'schoolId': 's-1',
        'schoolName': '12-maktab',
        'nextDate': '2026-11-05',
        'prepaidMonths': 1,
        'paused': false,
        'children': const [
          {'id': 'st-1', 'name': 'Karimov Aziz', 'className': '7-A'},
        ],
        'openVerification': openVerification,
      }),
    ];
  }

  @override
  Future<List<PaymentVerification>> fetchVerifications() async {
    verificationFetches++;
    return const [];
  }

  @override
  Future<PaymentVerification> createVerification({
    required String paymentReminderId,
    required String message,
  }) async {
    created.add('$paymentReminderId|$message');
    final error = createError;
    if (error != null) throw error;
    openVerification = true;
    return PaymentVerification.fromJson({
      'id': 'v-1',
      'paymentReminderId': paymentReminderId,
      'message': message,
      'status': 'OPEN',
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

  /// To'lovlar ekrani ochiq: ikkala ro'yxat tinglanadi va yuklanadi.
  Future<void> openScreen(ProviderContainer container) async {
    final payments = container.listen(schoolPaymentsProvider, (_, _) {});
    final history = container.listen(schoolVerificationsProvider, (_, _) {});
    addTearDown(payments.close);
    addTearDown(history.close);
    await container.read(schoolPaymentsProvider.future);
    await container.read(schoolVerificationsProvider.future);
  }

  /// So'rov yuboradi; xato xabari (`null` — muvaffaqiyat).
  Future<String?> verify(ProviderContainer container) async {
    final result = await container
        .read(paymentActionsProvider.notifier)
        .requestVerification(paymentReminderId: 'p-1', message: 'To`ladim');
    await container.pump();
    await pumpEventQueue();
    return result.error;
  }

  setUp(() => repo = _FakeSchoolRepository());

  test('eslatmalar va so`rovlar yuklanadi', () async {
    final container = makeContainer();
    await openScreen(container);

    final payments = container.read(schoolPaymentsProvider).requireValue;
    expect(payments.single.nextDate, '2026-11-05');
    expect(payments.single.children.single.className, '7-A');
    expect(container.read(schoolVerificationsProvider).requireValue, isEmpty);
  });

  test('kirilmagan — so`rovsiz xato', () async {
    final container = makeContainer(signedIn: false);
    final sub = container.listen(schoolPaymentsProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(schoolPaymentsProvider.future),
      throwsA(const SchoolFailure(SchoolFailureKind.sessionExpired)),
    );
    expect(repo.paymentFetches, 0);
  });

  test('muvaffaqiyat → tugma "tekshirilmoqda" holatiga o`tadi', () async {
    final container = makeContainer();
    await openScreen(container);

    expect(await verify(container), isNull);
    expect(repo.created, ['p-1|To`ladim']);
    expect(repo.paymentFetches, 2);
    expect(repo.verificationFetches, 2);
    final payments = container.read(schoolPaymentsProvider).requireValue;
    expect(payments.single.openVerification, isTrue);
  });

  test('409 (ochiq so`rov bor) → xabar + ro`yxatlar yangilanadi', () async {
    repo.createError = const SchoolFailure(SchoolFailureKind.verificationOpen);
    final container = makeContainer();
    await openScreen(container);

    // easy_localization testda yuklanmagan — `.tr()` kalitni qaytaradi.
    expect(await verify(container), 'school.errors.verificationOpen');
    expect(repo.paymentFetches, 2);
    expect(repo.verificationFetches, 2);
  });

  test('tarmoq xatosi → xabar, ro`yxatlar qayta so`ralmaydi', () async {
    repo.createError = const SchoolFailure(SchoolFailureKind.network);
    final container = makeContainer();
    await openScreen(container);

    expect(await verify(container), 'errors.noInternet');
    expect(repo.paymentFetches, 1);
    expect(repo.verificationFetches, 1);
  });

  test('ekran yopiq — ro`yxatlar qayta yaratilmaydi', () async {
    final container = makeContainer();
    expect(await verify(container), isNull);
    expect(repo.paymentFetches, 0);
    expect(repo.verificationFetches, 0);
  });
}

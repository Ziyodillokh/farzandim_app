// Ilova ochiq turganda maktab push'i kelsa (`refreshForSchoolPush`), faqat
// shu turga tegishli OCHIQ ekran ma'lumoti qayta so'raladi (soxta
// repository bilan): davomat push'i — davomat, erta ketish — ro'yxat va
// davomat, e'lon — o'qilmaganlar soni, to'lov — eslatmalar, javob —
// eslatmalar va so'rovlar, School Mode — bog'lanishlar. Eslatma va
// maktabga aloqasiz push'lar hech narsani so'ramaydi.

import 'package:dio/dio.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_early_exit_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Har so'rov turi necha marta chaqirilganini sanaydi.
class _CountingSchoolRepository extends SchoolRepository {
  _CountingSchoolRepository() : super(dio: Dio());

  final Map<String, int> fetches = {};

  void _count(String name) => fetches[name] = (fetches[name] ?? 0) + 1;

  @override
  Future<SchoolLinks> fetchLinks() async {
    _count('links');
    return SchoolLinks.fromJson(const {
      'links': [
        {
          'guardianId': 'g-1',
          'school': {'id': 's-1', 'name': 'Test maktab'},
          'students': [
            {'id': 'st-1', 'fullName': 'Karimov Aziz', 'linkedBy': 'ME'},
          ],
        },
      ],
    });
  }

  @override
  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int limit = kAnnouncementsPageSize,
  }) async {
    _count('unread');
    return AnnouncementPage.empty;
  }

  @override
  Future<MonthAttendance> fetchAttendance({
    required String studentId,
    String? month,
  }) async {
    _count('attendance');
    return MonthAttendance.fromJson({
      'student': {'id': studentId},
      'month': month,
    });
  }

  @override
  Future<List<EarlyExitRequest>> fetchEarlyExits() async {
    _count('earlyExits');
    return const [];
  }

  @override
  Future<List<SchoolPaymentReminder>> fetchPayments() async {
    _count('payments');
    return const [];
  }

  @override
  Future<List<PaymentVerification>> fetchVerifications() async {
    _count('verifications');
    return const [];
  }
}

AppNotification _push(NotificationType type) => AppNotification(
  id: 'n-${type.name}',
  type: type,
  childId: 'kid-1',
  childName: 'Aziz',
  title: 'T',
  message: 'M',
  timestamp: DateTime(2026, 10, 20),
  data: const {'studentId': 'st-1'},
);

void main() {
  late _CountingSchoolRepository repo;
  late ProviderContainer container;

  /// Barcha maktab ekranlari ochiq (provayderlar tinglanadi) va yuklangan.
  Future<void> openAllScreens() async {
    final month = (
      studentId: 'st-1',
      month: tashkentTodayStr().substring(0, 7),
    );
    final providers = <ProviderListenable<AsyncValue<Object?>>>[
      schoolLinksProvider,
      schoolUnreadCountProvider,
      monthAttendanceProvider(month),
      schoolEarlyExitsProvider,
      schoolPaymentsProvider,
      schoolVerificationsProvider,
    ];
    for (final provider in providers) {
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
    }
    await container.read(schoolLinksProvider.future);
    await container.read(schoolUnreadCountProvider.future);
    await container.read(monthAttendanceProvider(month).future);
    await container.read(schoolEarlyExitsProvider.future);
    await container.read(schoolPaymentsProvider.future);
    await container.read(schoolVerificationsProvider.future);
    repo.fetches.clear();
  }

  /// Push keldi → qaysi so'rovlar qayta yuborildi.
  Future<Set<String>> refetchedAfter(NotificationType type) async {
    refreshForSchoolPush(_push(type), container.invalidate);
    await container.pump();
    await pumpEventQueue();
    return repo.fetches.keys.toSet();
  }

  setUp(() async {
    repo = _CountingSchoolRepository();
    container = ProviderContainer(
      overrides: [
        schoolRepositoryProvider.overrideWithValue(repo),
        schoolSignedInProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await openAllScreens();
  });

  final expected = <NotificationType, Set<String>>{
    NotificationType.schoolAttendance: {'attendance'},
    NotificationType.schoolEarlyExit: {'earlyExits', 'attendance'},
    NotificationType.schoolAnnouncement: {'unread'},
    NotificationType.schoolPayment: {'payments'},
    NotificationType.schoolVerification: {'payments', 'verifications'},
    // Faqat ro'yxat: o'qilmaganlar soni bog'lanish bor-yo'qligiga
    // qaraydi, u esa o'zgarmadi — qayta so'ralmaydi.
    NotificationType.schoolMode: {'links'},
  };

  for (final MapEntry(key: type, value: fetched) in expected.entries) {
    test('${type.name} → ${fetched.join(', ')}', () async {
      expect(await refetchedAfter(type), fetched);
    });
  }

  test(
    'eslatma va maktabga aloqasiz push`lar hech narsani so`ramaydi',
    () async {
      final quiet = [
        NotificationType.schoolReminder,
        for (final type in NotificationType.values)
          if (!type.isSchool) type,
      ];
      for (final type in quiet) {
        expect(await refetchedAfter(type), isEmpty, reason: type.name);
      }
    },
  );
}

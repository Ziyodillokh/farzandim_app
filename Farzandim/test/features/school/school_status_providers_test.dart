// Dashboard kartasi va maktab sahifasi uchun provayderlar (soxta
// repository bilan): bugungi davomat joriy oy javobidan olinadi, o'qilmagan
// e'lonlar soni faqat bog'lanish bo'lsa so'raladi, `invalidateSchoolData`
// hammasini qayta so'raydi.

import 'package:dio/dio.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_refresh.dart';
import 'package:farzandim/features/school/presentation/school_view_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  SchoolLinks links = SchoolLinks.empty;
  int unread = 0;
  int linkFetches = 0;
  int unreadFetches = 0;
  final List<String> attendanceCalls = [];

  @override
  Future<SchoolLinks> fetchLinks() async {
    linkFetches++;
    return links;
  }

  @override
  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int limit = kAnnouncementsPageSize,
  }) async {
    unreadFetches++;
    return AnnouncementPage(
      items: const [],
      page: page,
      limit: limit,
      total: 0,
      totalPages: 1,
      unread: unread,
    );
  }

  @override
  Future<MonthAttendance> fetchAttendance({
    required String studentId,
    String? month,
  }) async {
    attendanceCalls.add('$studentId:$month');
    final today = tashkentTodayStr();
    return MonthAttendance.fromJson({
      'student': {'id': studentId, 'name': 'Karimov Aziz'},
      'month': month,
      'days': [
        {
          'date': today,
          'schoolDay': true,
          'record': const {'status': 'LATE', 'inAt': '08:42', 'outAt': null},
        },
      ],
      'summary': const {'late': 1, 'total': 1},
      'rate': 100,
    });
  }
}

SchoolLinks _linked() => SchoolLinks.fromJson(const {
  'links': [
    {
      'guardianId': 'g-1',
      'fullName': 'Karimova Malika',
      'relation': 'MOTHER',
      'school': {'id': 's-1', 'name': 'Test maktab'},
      'students': [
        {
          'id': 'st-1',
          'fullName': 'Karimov Aziz',
          'className': '7-A',
          'childId': 'kid-1',
          'linkedBy': 'ME',
        },
      ],
    },
  ],
  'children': [
    {'id': 'kid-1', 'name': 'Aziz'},
  ],
});

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

  setUp(() => repo = _FakeSchoolRepository());

  test('currentSchoolMonth — joriy Toshkent oyi "YYYY-MM"', () {
    final month = currentSchoolMonth();
    expect(month, matches(RegExp(r'^\d{4}-(0[1-9]|1[0-2])$')));
    expect(tashkentTodayStr().startsWith(month), isTrue);
  });

  group('todayAttendanceProvider', () {
    test('joriy oy so`raladi va bugungi kun olinadi', () async {
      final container = makeContainer();
      final sub = container.listen(todayAttendanceProvider('st-1'), (_, _) {});
      addTearDown(sub.close);

      await container.read(
        monthAttendanceProvider((
          studentId: 'st-1',
          month: currentSchoolMonth(),
        )).future,
      );
      final today = container.read(todayAttendanceProvider('st-1'));

      expect(repo.attendanceCalls, ['st-1:${currentSchoolMonth()}']);
      expect(SchoolDayStatus.of(today.valueOrNull), SchoolDayStatus.late);
      expect(today.valueOrNull?.record?.inAt, '08:42');
    });

    test(
      'kirilmagan — so`rovsiz xato (kesh boshqa hisobga o`tmaydi)',
      () async {
        final container = makeContainer(signedIn: false);
        final sub = container.listen(
          todayAttendanceProvider('st-1'),
          (_, _) {},
        );
        addTearDown(sub.close);

        await expectLater(
          container.read(
            monthAttendanceProvider((
              studentId: 'st-1',
              month: currentSchoolMonth(),
            )).future,
          ),
          throwsA(const SchoolFailure(SchoolFailureKind.sessionExpired)),
        );
        expect(repo.attendanceCalls, isEmpty);
      },
    );
  });

  group('schoolUnreadCountProvider', () {
    test('bog`lanish yo`q → 0, e`lonlar so`ralmaydi', () async {
      final container = makeContainer();
      await container.read(schoolLinksProvider.future);
      final sub = container.listen(schoolUnreadCountProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(schoolUnreadCountProvider.future), 0);
      expect(repo.unreadFetches, 0);
    });

    test('bog`lanish bor → server sanagan son', () async {
      repo
        ..links = _linked()
        ..unread = 3;
      final container = makeContainer();
      await container.read(schoolLinksProvider.future);
      final sub = container.listen(schoolUnreadCountProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(schoolUnreadCountProvider.future), 3);
      expect(repo.unreadFetches, 1);
    });
  });

  test(
    'invalidateSchoolData — ro`yxat, davomat va son qayta so`raladi',
    () async {
      repo
        ..links = _linked()
        ..unread = 1;
      final container = makeContainer();
      await container.read(schoolLinksProvider.future);
      final unreadSub = container.listen(schoolUnreadCountProvider, (_, _) {});
      final todaySub = container.listen(
        todayAttendanceProvider('st-1'),
        (_, _) {},
      );
      addTearDown(unreadSub.close);
      addTearDown(todaySub.close);
      final args = (studentId: 'st-1', month: currentSchoolMonth());
      await container.read(schoolUnreadCountProvider.future);
      await container.read(monthAttendanceProvider(args).future);

      repo.unread = 4;
      invalidateSchoolData(container.invalidate);

      await container.read(schoolLinksProvider.future);
      expect(await container.read(schoolUnreadCountProvider.future), 4);
      await container.read(monthAttendanceProvider(args).future);
      expect(repo.linkFetches, 2);
      expect(repo.unreadFetches, 2);
      expect(repo.attendanceCalls, hasLength(2));
    },
  );
}

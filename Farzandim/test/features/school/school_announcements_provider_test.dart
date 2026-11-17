// E'lonlar ekrani provayderi (soxta repository bilan): 20 tadan sahifalar,
// `loadMore` (takrorsiz, xatoda to'xtaydi), optimistik "o'qildi" (xatoda
// qaytariladi), o'qilmaganlar soni va ro'yxatni yo'qotmasdan yangilash.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  final Map<int, AnnouncementPage> pages = {};
  final Set<int> failingPages = {};
  int countUnread = 0;
  Exception? readError;

  /// Berilsa "o'qildi" javobi shu tugaguncha kutadi.
  Completer<void>? readGate;
  final List<String> calls = [];

  @override
  Future<SchoolLinks> fetchLinks() async => SchoolLinks.fromJson(const {
    'links': [
      {
        'guardianId': 'g-1',
        'school': {'id': 's-1', 'name': '12-maktab'},
        'students': [
          {'id': 'st-1', 'fullName': 'Karimov Aziz', 'linkedBy': 'ME'},
        ],
      },
    ],
  });

  @override
  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int limit = kAnnouncementsPageSize,
  }) async {
    if (limit == 1) {
      calls.add('count');
      return AnnouncementPage.empty.copyUnread(countUnread);
    }
    calls.add('page:$page');
    if (failingPages.contains(page)) {
      throw const SchoolFailure(SchoolFailureKind.network);
    }
    return pages[page] ?? AnnouncementPage.empty;
  }

  @override
  Future<DateTime> markAnnouncementRead(String announcementId) async {
    calls.add('read:$announcementId');
    final gate = readGate;
    if (gate != null) await gate.future;
    final error = readError;
    if (error != null) throw error;
    return DateTime.utc(2026, 10, 20, 9);
  }
}

extension on AnnouncementPage {
  AnnouncementPage copyUnread(int unread) => AnnouncementPage(
    items: items,
    page: page,
    limit: limit,
    total: total,
    totalPages: totalPages,
    unread: unread,
  );
}

SchoolAnnouncement _item(String id, {bool read = false}) =>
    SchoolAnnouncement.fromJson({
      'id': id,
      'schoolId': 's-1',
      'schoolName': '12-maktab',
      'title': 'E`lon $id',
      'body': 'Matn',
      'priority': 'NORMAL',
      'sentAt': '2026-10-20T04:00:00.000Z',
      'readAt': read ? '2026-10-20T05:00:00.000Z' : null,
    });

AnnouncementPage _page(
  int page,
  List<SchoolAnnouncement> items, {
  int totalPages = 2,
  int unread = 2,
}) => AnnouncementPage(
  items: items,
  page: page,
  limit: kAnnouncementsPageSize,
  total: items.length * totalPages,
  totalPages: totalPages,
  unread: unread,
);

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

  /// Provayderni tirik ushlab, birinchi sahifa kelishini kutadi.
  Future<SchoolAnnouncementsNotifier> open(ProviderContainer container) async {
    final sub = container.listen(schoolAnnouncementsProvider, (_, _) {});
    addTearDown(sub.close);
    await pumpEventQueue();
    return container.read(schoolAnnouncementsProvider.notifier);
  }

  setUp(() {
    repo = _FakeSchoolRepository();
    repo.pages[1] = _page(1, [
      _item('a-1'),
      _item('a-2'),
      _item('a-3', read: true),
    ]);
    repo.pages[2] = _page(2, [_item('a-3', read: true), _item('a-4')]);
  });

  group('sahifalar', () {
    test('birinchi sahifa: e`lonlar, o`qilmaganlar soni, davomi bor', () async {
      final container = makeContainer();
      await open(container);
      final state = container.read(schoolAnnouncementsProvider);

      expect(state.loading, isFalse);
      expect(state.failure, isNull);
      expect(state.items.map((a) => a.id), ['a-1', 'a-2', 'a-3']);
      expect(state.unread, 2);
      expect(state.hasMore, isTrue);
      expect(repo.calls, ['page:1']);
    });

    test('kirilmagan — so`rovsiz xato holati', () async {
      final container = makeContainer(signedIn: false);
      final notifier = await open(container);
      await notifier.refresh();

      final state = container.read(schoolAnnouncementsProvider);
      expect(state.failure?.kind, SchoolFailureKind.sessionExpired);
      expect(repo.calls, isEmpty);
    });

    test('birinchi sahifa xatosi → qayta urinish tiklaydi', () async {
      repo.failingPages.add(1);
      final container = makeContainer();
      final notifier = await open(container);
      expect(
        container.read(schoolAnnouncementsProvider).failure?.kind,
        SchoolFailureKind.network,
      );

      repo.failingPages.clear();
      await notifier.refresh();
      final state = container.read(schoolAnnouncementsProvider);
      expect(state.failure, isNull);
      expect(state.items, hasLength(3));
    });

    test(
      'loadMore: qo`shadi, takrorni tashlaydi, sonni o`zgartirmaydi',
      () async {
        repo.pages[2] = _page(2, [
          _item('a-3', read: true),
          _item('a-4'),
        ], unread: 9);
        final container = makeContainer();
        final notifier = await open(container);
        await notifier.loadMore();

        final state = container.read(schoolAnnouncementsProvider);
        expect(state.items.map((a) => a.id), ['a-1', 'a-2', 'a-3', 'a-4']);
        expect(state.page, 2);
        expect(state.hasMore, isFalse);
        expect(state.unread, 2);

        await notifier.loadMore();
        expect(repo.calls, ['page:1', 'page:2'], reason: 'oxiriga yetildi');
      },
    );

    test(
      'loadMore xatosi: ro`yxat qoladi, faqat retryMore davom etadi',
      () async {
        repo.failingPages.add(2);
        final container = makeContainer();
        final notifier = await open(container);
        await notifier.loadMore();

        var state = container.read(schoolAnnouncementsProvider);
        expect(state.moreFailure?.kind, SchoolFailureKind.network);
        expect(state.items, hasLength(3));

        await notifier.loadMore();
        expect(repo.calls, ['page:1', 'page:2'], reason: 'avtomatik emas');

        repo.failingPages.clear();
        await notifier.retryMore();
        state = container.read(schoolAnnouncementsProvider);
        expect(state.moreFailure, isNull);
        expect(state.items, hasLength(4));
      },
    );
  });

  group('markRead', () {
    test(
      'optimistik: darhol o`qilgan, server tasdig`ida son yangilanadi',
      () async {
        final container = makeContainer();
        await container.read(schoolLinksProvider.future);
        final countSub = container.listen(schoolUnreadCountProvider, (_, _) {});
        addTearDown(countSub.close);
        await container.read(schoolUnreadCountProvider.future);
        final notifier = await open(container);
        final gate = repo.readGate = Completer<void>();

        final done = notifier.markRead('a-1');
        var state = container.read(schoolAnnouncementsProvider);
        expect(state.items.first.isRead, isTrue);
        expect(state.unread, 1);

        gate.complete();
        expect(await done, isTrue);
        await pumpEventQueue();
        state = container.read(schoolAnnouncementsProvider);
        expect(state.items.first.isRead, isTrue);
        expect(state.unread, 1);
        expect(
          repo.calls.where((c) => c == 'count'),
          hasLength(2),
          reason: 'dashboard belgisi qayta so`raladi',
        );
      },
    );

    test('server rad etsa — belgi va son qaytariladi', () async {
      repo.readError = const SchoolFailure(SchoolFailureKind.network);
      final container = makeContainer();
      final notifier = await open(container);

      expect(await notifier.markRead('a-2'), isFalse);
      final state = container.read(schoolAnnouncementsProvider);
      expect(state.items[1].isRead, isFalse);
      expect(state.unread, 2);
    });

    test('allaqachon o`qilgan — so`rovsiz', () async {
      final container = makeContainer();
      final notifier = await open(container);
      expect(await notifier.markRead('a-3'), isTrue);
      expect(repo.calls, ['page:1']);
    });

    test('ro`yxatda yo`q (push) — faqat serverga yuboriladi', () async {
      final container = makeContainer();
      final notifier = await open(container);
      final before = container.read(schoolAnnouncementsProvider);

      expect(await notifier.markRead('eski'), isTrue);
      expect(repo.calls, ['page:1', 'read:eski']);
      final after = container.read(schoolAnnouncementsProvider);
      expect(after.items, before.items);
      expect(after.unread, 2);
    });

    test(
      'oraliqda yangilangan ro`yxat qaytarilmaydi (server haqiqati)',
      () async {
        final container = makeContainer();
        final notifier = await open(container);
        final gate = repo.readGate = Completer<void>();
        repo.readError = const SchoolFailure(SchoolFailureKind.network);

        final done = notifier.markRead('a-1');
        repo.pages[1] = _page(1, [_item('a-0'), _item('a-1')]);
        await notifier.refresh();
        gate.complete();
        expect(await done, isFalse);

        final state = container.read(schoolAnnouncementsProvider);
        expect(state.items.map((a) => a.id), ['a-0', 'a-1']);
        expect(state.items.every((a) => !a.isRead), isTrue);
        expect(state.unread, 2);
      },
    );
  });

  test(
    'invalidateSchoolData — ochiq ro`yxat yo`qolmasdan yangilanadi',
    () async {
      final container = makeContainer();
      await open(container);
      repo.pages[1] = _page(1, [_item('a-0'), _item('a-1')], unread: 5);

      invalidateSchoolData(container.invalidate);
      await container.pump();
      final reloading = container.read(schoolAnnouncementsProvider);
      expect(
        reloading.items,
        isNotEmpty,
        reason: 'eski ro`yxat ekranda qoladi',
      );
      await pumpEventQueue();

      final state = container.read(schoolAnnouncementsProvider);
      expect(state.items.map((a) => a.id), ['a-0', 'a-1']);
      expect(state.unread, 5);
      expect(repo.calls.where((c) => c == 'page:1'), hasLength(2));
    },
  );
}

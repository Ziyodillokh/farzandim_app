// Maktab bilan bog'lanish ekranlari: xodim sahifasidagi shablon tayyor
// matn bilan yozish varag'ini ochadi va yuborilgach yozishmaga o'tadi;
// yozishma ekranida yozish (xodim kontakt bo'lmasa — o'chiq); e'lonlar
// filtri.

import 'package:dio/dio.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/school_connect_repository.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/screens/school_announcements_screen.dart';
import 'package:farzandim/features/school/presentation/screens/school_contact_screen.dart';
import 'package:farzandim/features/school/presentation/screens/school_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _student = ConnectStudent(
  id: 'st-1',
  name: 'Karimova Aziza',
  className: '6-B',
);

const _homeroom = SchoolContact(
  staffId: 'stf-h',
  fullName: 'Rasulova Malika',
  role: StaffRole.homeroom,
  position: '',
  group: ContactGroup.classTeacher,
);

SchoolThread _thread({bool available = true}) => SchoolThread(
  id: 'th-1',
  resolved: false,
  schoolName: '24-maktab',
  staff: _homeroom,
  student: _student,
  lastFromStaff: true,
  available: available,
  unread: 1,
  messages: [
    ThreadMessage(
      id: 'm-1',
      author: MessageAuthor.parent,
      topic: ContactTopic.absence,
      body: 'Bugun kela olmaydi',
      createdAt: DateTime(2026, 11, 9, 7, 32),
      seen: true,
    ),
    ThreadMessage(
      id: 'm-2',
      author: MessageAuthor.staff,
      body: 'Rahmat, tuzalib keting',
      createdAt: DateTime(2026, 11, 9, 8, 14),
    ),
  ],
);

class _FakeConnectRepository extends SchoolConnectRepository {
  _FakeConnectRepository({this.available = true}) : super(dio: Dio());

  final bool available;
  final started = <(String, ContactTopic, String)>[];
  final sent = <String>[];
  int reads = 0;

  @override
  Future<SchoolContacts> fetchContacts(String studentId) async =>
      const SchoolContacts(student: _student, contacts: [_homeroom]);

  @override
  Future<SchoolThread> fetchThread(String threadId) async =>
      _thread(available: available);

  @override
  Future<SchoolThread> startThread({
    required String staffId,
    required String studentId,
    required ContactTopic topic,
    required String body,
  }) async {
    started.add((staffId, topic, body));
    return _thread();
  }

  @override
  Future<SchoolThread> sendMessage({
    required String threadId,
    required String body,
    ContactTopic? topic,
  }) async {
    sent.add(body);
    return _thread();
  }

  @override
  Future<void> markThreadRead(String threadId) async => reads++;
}

Widget _app(_FakeConnectRepository repo, String initial) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/school/contacts/:staffId',
        builder: (_, state) => SchoolContactScreen(
          staffId: state.pathParameters['staffId']!,
          studentId: 'st-1',
        ),
      ),
      GoRoute(
        path: '/school/threads/:threadId',
        builder: (_, state) =>
            SchoolThreadScreen(threadId: state.pathParameters['threadId']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      schoolConnectRepositoryProvider.overrideWithValue(repo),
      schoolSignedInProvider.overrideWithValue(true),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeSchoolRepository extends SchoolRepository {
  _FakeSchoolRepository() : super(dio: Dio());

  @override
  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int limit = kAnnouncementsPageSize,
  }) async => AnnouncementPage(
    items: [
      SchoolAnnouncement(
        id: 'a-1',
        schoolId: 's-1',
        schoolName: 'Test',
        title: "O'qilmagan e'lon",
        body: 'Matn',
        priority: AnnouncementPriority.normal,
        sentAt: DateTime.now(),
      ),
      SchoolAnnouncement(
        id: 'a-2',
        schoolId: 's-1',
        schoolName: 'Test',
        title: "O'qilgan e'lon",
        body: 'Matn',
        priority: AnnouncementPriority.normal,
        sentAt: DateTime.now(),
        readAt: DateTime.now(),
      ),
    ],
    page: 1,
    limit: limit,
    total: 2,
    totalPages: 1,
    unread: 1,
  );
}

void main() {
  testWidgets('shablon → tayyor matn → yuborish → yozishmaga o`tish', (
    tester,
  ) async {
    final repo = _FakeConnectRepository();
    await tester.pumpWidget(_app(repo, '/school/contacts/stf-h'));
    await tester.pumpAndSettle();

    expect(find.text('Rasulova Malika'), findsOneWidget);
    final template = find.text('school.connect.topic.absence.title');
    await tester.ensureVisible(template);
    await tester.pumpAndSettle();
    await tester.tap(template);
    await tester.pumpAndSettle();

    // Tayyor matn maydonda (tarjimasiz testda — kalit).
    expect(
      find.widgetWithText(TextField, 'school.connect.topic.absence.body'),
      findsOneWidget,
    );
    await tester.tap(find.text('school.connect.send'));
    await tester.pumpAndSettle();

    expect(repo.started.single.$1, 'stf-h');
    expect(repo.started.single.$2, ContactTopic.absence);
    // Yozishma ochildi va xodim javoblari o'qildi deb belgilandi.
    expect(find.text('Rahmat, tuzalib keting'), findsOneWidget);
    expect(repo.reads, 1);
    // "Xabar yuborildi" bildirgisi o'z vaqtida yopilsin.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('yozishmada xabar yuborish', (tester) async {
    final repo = _FakeConnectRepository();
    await tester.pumpWidget(_app(repo, '/school/threads/th-1'));
    await tester.pumpAndSettle();

    expect(find.text('Bugun kela olmaydi'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Ertaga boradi ');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('school.connect.send'));
    await tester.pumpAndSettle();
    expect(repo.sent, ['Ertaga boradi']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('xodim endi kontakt emas — yozish o`chiq', (tester) async {
    final repo = _FakeConnectRepository(available: false);
    await tester.pumpWidget(_app(repo, '/school/threads/th-1'));
    await tester.pumpAndSettle();
    expect(find.text('school.connect.unavailable'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('e`lonlar: "O`qilmagan" filtri faqat o`qilmaganlarni qoldiradi', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(_FakeSchoolRepository()),
          schoolSignedInProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: SchoolAnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("O'qilgan e'lon"), findsOneWidget);

    await tester.tap(find.text('school.announcements.filter.unread'));
    await tester.pumpAndSettle();
    expect(find.text("O'qilmagan e'lon"), findsOneWidget);
    expect(find.text("O'qilgan e'lon"), findsNothing);
  });
}

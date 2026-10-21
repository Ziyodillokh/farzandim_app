// Psixologga murojaat: mavzu + matn bo'lmasa yuborilmaydi, 1000 belgi
// chegarasi, "Shoshilinch", 429 (matn saqlanadi), SOS havolasi, chiqishda
// tasdiq; "Murojaatlarim": holatlar va suhbat vaqti Toshkent vaqtida.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_header.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_request_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_requests_screen.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care/care_request_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_school_repository.dart';
import 'school_fixtures.dart';
import 'school_test_app.dart';

const _openLabel = 'open-page';
const _message = 'Tanaffusda meni masxara qilishyapti';

String _t(String key, [Map<String, String>? args]) => key.tr(namedArgs: args);

FakeSchoolRepository _repo({List<CareRequest> requests = const []}) =>
    FakeSchoolRepository(today: todayWith({}), careRequests: requests);

/// Boshlang'ich sahifadan [path] sahifasini ochadi.
Future<void> _open(
  WidgetTester tester,
  FakeSchoolRepository repo,
  String path, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  await pumpSchoolApp(
    tester,
    repository: repo,
    initialLocation: '/start',
    size: size,
    textScale: textScale,
    routes: [
      GoRoute(
        path: '/start',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => context.push(path),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: SchoolRoutes.newRequest,
        builder: (_, _) => const CareRequestScreen(),
      ),
      GoRoute(
        path: SchoolRoutes.requests,
        builder: (_, _) => const CareRequestsScreen(),
      ),
      markerRoute('/chats'),
      markerRoute(SchoolRoutes.hub),
    ],
  );
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Finder get _sendButton => find.text(_t('school.requests.send'));

void main() {
  setUpAll(setUpSchoolWidgetTests);

  group('yangi murojaat', () {
    testWidgets('mavzu va matnsiz yuborilmaydi; shoshilinch murojaat '
        'yuboriladi va matn o\'chadi', (tester) async {
      final repo = _repo();
      await _open(tester, repo, SchoolRoutes.newRequest);

      expect(tester.takeException(), isNull);
      expect(find.text(_t('school.requests.intro')), findsOneWidget);
      expect(find.text(_t('school.requests.sos')), findsOneWidget);
      expect(find.text(_t('school.requests.required')), findsOneWidget);
      for (final key in [
        'learning',
        'peers',
        'bullying',
        'family',
        'emotions',
        'safety',
        'other',
      ]) {
        expect(find.text(_t('school.requests.topics.$key')), findsOneWidget);
      }

      await _tap(tester, _sendButton);
      expect(repo.calls, isNot(contains('createCareRequest')));

      await _tap(tester, find.text(_t('school.requests.topics.bullying')));
      await _tap(tester, _sendButton);
      expect(repo.calls, isNot(contains('createCareRequest')));

      await tester.enterText(find.byType(TextField), '  $_message  ');
      await tester.pump();
      expect(find.text(_t('school.requests.required')), findsNothing);
      await _tap(tester, find.byType(Switch));
      await _tap(tester, _sendButton);
      await tester.pumpAndSettle();

      expect(find.text(_t('school.requests.sentTitle')), findsOneWidget);
      expect(find.text(_t('school.requests.sentBody')), findsOneWidget);
      expect(repo.sentRequests, [
        (CareTopic.bullying, _message, CareUrgency.urgent),
      ]);

      await tester.tap(find.text(_t('school.requests.done')));
      await tester.pumpAndSettle();
      expect(find.text(_openLabel), findsOneWidget);
    });

    testWidgets('oddiy murojaat — NORMAL', (tester) async {
      final repo = _repo();
      await _open(tester, repo, SchoolRoutes.newRequest);

      await _tap(tester, find.text(_t('school.requests.topics.learning')));
      await tester.enterText(
        find.byType(TextField),
        'Matematikani tushunmayapman',
      );
      await tester.pump();
      await _tap(tester, _sendButton);
      await tester.pumpAndSettle();

      expect(repo.sentRequests.single.$3, CareUrgency.normal);
      expect(repo.sentRequests.single.$1, CareTopic.learning);
    });

    testWidgets('429 — kunlik chegara xabari, matn saqlanadi', (tester) async {
      final repo = _repo();
      await _open(tester, repo, SchoolRoutes.newRequest);
      await _tap(tester, find.text(_t('school.requests.topics.peers')));
      await tester.enterText(find.byType(TextField), _message);
      await tester.pump();

      repo.failNext = const SchoolException(SchoolErrorCode.tooManyRequests);
      await _tap(tester, _sendButton);
      await tester.pumpAndSettle();

      expect(find.text(_t('school.requests.limitReached')), findsOneWidget);
      expect(find.text(_t('school.requests.sentTitle')), findsNothing);
      expect(find.text(_message), findsOneWidget);
    });

    testWidgets('tarmoq xatosi — xabar, qayta yuborish mumkin', (tester) async {
      final repo = _repo();
      await _open(tester, repo, SchoolRoutes.newRequest);
      await _tap(tester, find.text(_t('school.requests.topics.family')));
      await tester.enterText(find.byType(TextField), _message);
      await tester.pump();

      repo.failNext = const SchoolException(SchoolErrorCode.network);
      await _tap(tester, _sendButton);
      await tester.pumpAndSettle();
      expect(find.text(_t('school.errors.network')), findsOneWidget);

      await _tap(tester, _sendButton);
      await tester.pumpAndSettle();
      expect(find.text(_t('school.requests.sentTitle')), findsOneWidget);
    });

    testWidgets('matn 1000 belgidan oshmaydi, hisoblagich ko\'rinadi', (
      tester,
    ) async {
      await _open(tester, _repo(), SchoolRoutes.newRequest);

      expect(find.text('0/$kCareMessageMaxLength'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'a' * 1100);
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, kCareMessageMaxLength);
      expect(find.text('1000/$kCareMessageMaxLength'), findsOneWidget);
    });

    testWidgets('SOS tugmasi Chatlar (SOS xabar) sahifasini ochadi', (
      tester,
    ) async {
      await _open(tester, _repo(), SchoolRoutes.newRequest);

      await _tap(tester, find.text(_t('chats.sosButton')));
      await tester.pumpAndSettle();

      expect(find.text('page:/chats'), findsOneWidget);
    });

    testWidgets('yozilgan matn bilan chiqishda tasdiq so\'raladi', (
      tester,
    ) async {
      final repo = _repo();
      await _open(tester, repo, SchoolRoutes.newRequest);
      await tester.enterText(find.byType(TextField), _message);
      await tester.pump();

      await tester.tap(find.byType(HeaderIconButton).first);
      await tester.pumpAndSettle();
      expect(find.text(_t('school.leave.requestTitle')), findsOneWidget);
      await tester.tap(find.text(_t('school.leave.stay')));
      await tester.pumpAndSettle();
      expect(find.text(_message), findsOneWidget);

      await tester.tap(find.byType(HeaderIconButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_t('school.leave.leave')));
      await tester.pumpAndSettle();
      expect(find.text(_openLabel), findsOneWidget);
      expect(repo.calls, isNot(contains('createCareRequest')));
    });

    testWidgets('320pt ekran va katta shriftda toshib ketmaydi', (
      tester,
    ) async {
      await _open(
        tester,
        _repo(),
        SchoolRoutes.newRequest,
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text(_t('school.requests.topics.emotions')));
      expect(tester.takeException(), isNull);
    });
  });

  group('Murojaatlarim', () {
    final scheduled = CareRequest.tryFromJson({
      ...careRequestJson,
      'urgency': 'URGENT',
    })!;
    final sent = CareRequest.tryFromJson({
      'id': 'req-2',
      'topic': 'LEARNING',
      'urgency': 'NORMAL',
      'status': 'NEW',
      'createdAt': '2026-10-20T04:05:00.000Z',
      'meetingAt': null,
    })!;

    testWidgets('holatlar va suhbat vaqti Toshkent vaqtida', (tester) async {
      await _open(
        tester,
        _repo(requests: [sent, scheduled]),
        SchoolRoutes.requests,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CareRequestTile), findsNWidgets(2));
      expect(find.text(_t('school.requests.privacy')), findsOneWidget);
      expect(find.text(_t('school.requests.topics.peers')), findsOneWidget);
      expect(find.text(_t('school.requests.topics.learning')), findsOneWidget);
      expect(find.text(_t('school.requests.status.scheduled')), findsOneWidget);
      expect(find.text(_t('school.requests.status.sent')), findsOneWidget);
      expect(find.text(_t('school.requests.urgentTitle')), findsOneWidget);
      // 09:00Z → 14:00 Toshkent; 06:30Z → 11:30; 04:05Z → 09:05.
      expect(
        find.text(_t('school.requests.meeting', {'date': '21-oktabr, 14:00'})),
        findsOneWidget,
      );
      expect(
        find.text(_t('school.requests.sentAt', {'date': '19-oktabr, 11:30'})),
        findsOneWidget,
      );
      expect(
        find.text(_t('school.requests.sentAt', {'date': '20-oktabr, 09:05'})),
        findsOneWidget,
      );
    });

    testWidgets('bo\'sh ro\'yxat va "Yangi murojaat"', (tester) async {
      await _open(tester, _repo(), SchoolRoutes.requests);

      expect(find.text(_t('school.requests.emptyTitle')), findsOneWidget);
      await tester.tap(find.text(_t('school.requests.newRequest')));
      await tester.pumpAndSettle();

      expect(find.text(_t('school.requests.newTitle')), findsOneWidget);
    });

    testWidgets('yuklash xatosi — "Qayta urinish" bilan tiklanadi', (
      tester,
    ) async {
      final repo = _repo(requests: [scheduled])
        ..failOnce['loadCareRequests'] = const SchoolException(
          SchoolErrorCode.network,
        );
      await _open(tester, repo, SchoolRoutes.requests);

      expect(find.text(_t('school.errors.network')), findsOneWidget);
      await tester.tap(find.text(_t('common.retry')));
      await tester.pumpAndSettle();

      expect(find.byType(CareRequestTile), findsOneWidget);
    });
  });
}

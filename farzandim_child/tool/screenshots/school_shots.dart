// Skrinshot harness'i uchun maktab sahifalari va holatlari:
//   SHOT_SCHOOL=none (standart — bog'lanmagan, bosh sahifa avvalgidek) |
//     notmarked | late | present | out | dayoff | again | expired | invalid |
//     outside | offline
//   SHOT_PAGE=school (Maktabim: davomat, topshiriqlar, testlar, so'rovnoma,
//     psixolog) |
//     check_in (QR natijasi / xatosi) | psych (test kirishi) |
//     psych_stimulus | psych_question | psych_multi | psych_done |
//     survey | survey_done | request_new | requests
//   (test / so'rovnoma / murojaat sahifalari — bog'langan holatda, masalan
//   SHOT_SCHOOL=late)

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/domain/psych_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_request_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_requests_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/care_survey_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/psych_test_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_check_in_screen.dart';
import 'package:farzandim_child/features/school/presentation/screens/school_hub_screen.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care/survey_question_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../test/features/school/fake_school_repository.dart';
import '../../test/features/school/school_fixtures.dart';
import '../../test/features/school/school_test_app.dart';

const shotSchool = String.fromEnvironment('SHOT_SCHOOL', defaultValue: 'none');

const _token = 'eyJzIjoic2Nob29sLTEiLCJ0IjoxfQ.c2lnbmF0dXJl';

final _scanner = FakeScanner();

String? schoolLocation(String page) => switch (page) {
  'school' => '/school',
  'check_in' => '/check-in',
  'psych' ||
  'psych_stimulus' ||
  'psych_question' ||
  'psych_multi' ||
  'psych_done' => '/psych',
  'survey' || 'survey_done' => '/survey',
  'request_new' => '/request',
  'requests' => '/requests',
  _ => null,
};

Map<String, Object?> _record(String status, {String? inAt, String? outAt}) => {
  'status': status,
  'inAt': inAt,
  'outAt': outAt,
  'source': 'QR',
};

SchoolToday? _today() => switch (shotSchool) {
  'none' => null,
  'notmarked' => todayWith({'record': null}),
  'present' ||
  'again' => todayWith({'record': _record('PRESENT', inAt: '07:56')}),
  'out' => todayWith({
    'record': _record('PRESENT', inAt: '07:56', outAt: '13:31'),
  }),
  'dayoff' => todayWith({'record': null, 'schoolDay': false}),
  _ => todayWith({}),
};

SchoolErrorCode? get _failure => switch (shotSchool) {
  'expired' => SchoolErrorCode.kioskExpired,
  'invalid' => SchoolErrorCode.kioskInvalid,
  'outside' => SchoolErrorCode.outsideHours,
  'offline' => SchoolErrorCode.network,
  _ => null,
};

final _survey = CareSurveyStatus.tryFromJson({
  'enrolled': true,
  'answered': false,
  'survey': {
    'id': 'survey-1',
    'title': 'Haftalik so‘rovnoma',
    'questions': [
      {
        'id': 'q1',
        'text': 'Bu hafta maktabda o‘zingni qanchalik xotirjam his qilding?',
      },
      {'id': 'q2', 'text': 'Darslar senga qanchalik tushunarli bo‘ldi?'},
      {
        'id': 'q3',
        'text':
            'Maktabda seni ranjitgan yoki masxara qilgan holatlar bo‘ldimi?',
      },
      {'id': 'q4', 'text': 'Maktabda o‘zingni xavfsiz his qilasanmi?'},
    ],
  },
})!;

final _psychAssignments = [
  PsychAssignmentSummary.tryFromJson(psychSummaryJson)!,
  PsychAssignmentSummary.tryFromJson({
    ...psychSummaryJson,
    'assignmentId': 'assign-2',
    'kind': 'EMOTIONAL',
    'title': 'Kayfiyatim qanday?',
    'itemCount': 12,
    'timeLimitMin': null,
    'closesAt': '2026-10-28T13:00:00.000Z',
  })!,
];

List<CareRequest> _requests() {
  final now = DateTime.now().toUtc();
  return [
    CareRequest(
      id: 'req-2',
      topic: CareTopic.learning,
      urgency: CareUrgency.normal,
      status: CareRequestStatus.sent,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    CareRequest.tryFromJson({
      ...careRequestJson,
      'urgency': 'URGENT',
      'meetingAt': now
          .add(const Duration(days: 1))
          .copyWith(hour: 9, minute: 0)
          .toIso8601String(),
    })!,
    CareRequest.tryFromJson({
      ...careRequestJson,
      'id': 'req-0',
      'topic': 'FAMILY',
      'status': 'RESOLVED',
      'createdAt': '2026-10-02T07:15:00.000Z',
      'meetingAt': '2026-10-03T08:30:00.000Z',
    })!,
  ];
}

/// Toshkent kunidan [offset] kun keyingi sana (`YYYY-MM-DD`).
String _day(int offset) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5));
  final day = DateTime(now.year, now.month, now.day + offset);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

List<SchoolAssignment> _assignments() => [
  for (final json in [
    {...schoolAssignmentJson, 'done': false, 'dueDate': _day(1)},
    {
      ...schoolAssignmentJson,
      'id': 'sa-2',
      'kind': 'AUDIOBOOK',
      'materialId': 'audiobook:book-1',
      'title': 'O‘tkan kunlar — Abdulla Qodiriy',
      'subject': null,
      'done': null,
      'note': '1–3-boblarni tinglang',
      'dueDate': _day(3),
    },
    {
      ...schoolAssignmentJson,
      'id': 'sa-3',
      'subject': 'ENGLISH',
      'note': '',
      'dueDate': _day(-1),
    },
  ])
    ?SchoolAssignment.tryFromJson(json),
];

FakeSchoolRepository _repository() => FakeSchoolRepository(
  today: _today(),
  checkInAction: switch (shotSchool) {
    'out' => CheckInAction.departed,
    'again' => CheckInAction.none,
    _ => CheckInAction.arrived,
  },
  psychAssignments: _psychAssignments,
  psychTests: [PsychTest.tryFromJson(psychTestJson)!],
  careSurvey: _survey,
  careRequests: _requests(),
  assignments: _assignments(),
);

final _repo = _repository();

List<Override> schoolOverrides() => [
  schoolRepositoryProvider.overrideWithValue(_repo),
  schoolAccountProvider.overrideWithValue('child-1'),
];

/// Bugungi holat avval yuklangan (ilovadagidek — bosh sahifa / Maktabim).
Widget _afterToday(Widget child) => Consumer(
  builder: (context, ref, child) {
    ref.watch(schoolTodayProvider);
    return child!;
  },
  child: child,
);

List<RouteBase> schoolShotRoutes() => [
  GoRoute(path: '/school', builder: (_, _) => const SchoolHubScreen()),
  GoRoute(
    path: '/check-in',
    builder: (_, _) =>
        _afterToday(SchoolCheckInScreen(scannerBuilder: _scanner.build)),
  ),
  GoRoute(
    path: '/psych',
    builder: (_, _) => const PsychTestScreen(assignmentId: 'assign-1'),
  ),
  GoRoute(
    path: '/survey',
    builder: (_, _) => _afterToday(const CareSurveyScreen()),
  ),
  GoRoute(path: '/request', builder: (_, _) => const CareRequestScreen()),
  GoRoute(
    path: '/requests',
    builder: (_, _) => _afterToday(const CareRequestsScreen()),
  ),
];

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// So'rovnomaning [question]-savoliga (0 dan) [value] baho.
Future<void> _rate(WidgetTester tester, int question, int value) async {
  final option = find.descendant(
    of: find.byType(SurveyQuestionCard).at(question),
    matching: find.text('school.survey.scale.$value'.tr()),
  );
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Sahifa holatini tayyorlash: QR "ko'rsatiladi", test boshlanadi va
/// javoblar belgilanadi, so'rovnoma / murojaat to'ldiriladi.
Future<void> performSchoolActions(WidgetTester tester, String page) async {
  switch (page) {
    case 'check_in':
      final failure = _failure;
      _repo.failNext = failure == null ? null : SchoolException(failure);
      _scanner.scan(kioskLink(_token));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    case 'psych_stimulus':
      await _tapText(tester, 'school.psych.start'.tr());
    case 'psych_question' || 'psych_multi' || 'psych_done':
      await _tapText(tester, 'school.psych.start'.tr());
      await _tapText(tester, 'school.psych.toQuestion'.tr());
      await _tapText(tester, '9');
      if (page == 'psych_question') return;
      await _tapText(tester, 'school.psych.next'.tr());
      await _tapText(tester, 'school.psych.likert.4'.tr());
      await _tapText(tester, 'school.psych.next'.tr());
      await _tapText(tester, 'Olma');
      await _tapText(tester, 'Nok');
      if (page == 'psych_multi') return;
      await _tapText(tester, 'school.psych.finish'.tr());
      await tester.pump(const Duration(milliseconds: 800));
    case 'survey' || 'survey_done':
      await _rate(tester, 0, 4);
      await _rate(tester, 1, 2);
      if (page == 'survey') return;
      await _rate(tester, 2, 1);
      await _rate(tester, 3, 5);
      await _tapText(tester, 'school.survey.submit'.tr());
      await tester.pump(const Duration(milliseconds: 800));
    case 'request_new':
      await _tapText(tester, 'school.requests.topics.bullying'.tr());
      await tester.enterText(
        find.byType(TextField),
        'Tanaffusda ikki sinfdoshim meni masxara qilishyapti.',
      );
      await tester.pump(const Duration(milliseconds: 200));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 200));
  }
}

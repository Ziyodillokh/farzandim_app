// Parvoz Parents dizayn QA — sahifani PNG'ga chizadi (soxta ma'lumot bilan).
// CI'da ishlamaydi (`tool/` ichida):
//
//   flutter test tool/screenshots/parent_shots.dart \
//     --dart-define=SHOT_OUT=/tmp/p.png \
//     --dart-define=SHOT_PAGE=school   # start | school | school_empty
//                                      # | school_due (to'lov kuni o'tgan)
//                                      # | link (kod kiritish) | school_match
//                                      # | match_sheet (farzandga bog'lash)
//                                      # | profile | control_empty | control
//                                      # | control_switch (farzandlar varag'i)
//                                      # | announcements | payments
//                                      # | early_exits | attendance
//     --dart-define=SHOT_LOCALE=uz --dart-define=SHOT_SCROLL=0
//     --dart-define=SHOT_WIDTH=360 --dart-define=SHOT_TEXT_SCALE=1.3
//     --dart-define=SHOT_HEIGHT=2400 --dart-define=SHOT_CHECK_TEXT=true
//     overview_year — o'quv yili davri (uzun belgi), «Aliyev Ali · 1-A»
//     SHOT_CHECK_TEXT — sahifadagi so'z o'rtasidan uzilgan matnlarni
//     «MID-WORD» qatori bilan chiqaradi (uzun SHOT_HEIGHT bilan butun
//     ro'yxat quriladi).

// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_router.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/data/models/auth_models.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/models/gender.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/growth/presentation/providers/growth_providers.dart';
import 'package:farzandim/features/iq/data/iq_repository.dart';
import 'package:farzandim/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/models/student_overview.dart';
import 'package:farzandim/features/school/data/school_connect_repository.dart';
import 'package:farzandim/features/school/data/school_repository.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_connect_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_payment_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/settings/data/models/user_session.dart';
import 'package:farzandim/features/settings/presentation/providers/sessions_provider.dart';
import 'package:farzandim/features/voice_message/presentation/providers/voice_message_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/helpers/readable_text.dart';
import 'parent_fake_school.dart';

const _out = String.fromEnvironment('SHOT_OUT', defaultValue: 'build/p.png');
const _page = String.fromEnvironment('SHOT_PAGE', defaultValue: 'school');
const _locale = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'uz');
const _scroll = int.fromEnvironment('SHOT_SCROLL');
final _width = double.parse(
  const String.fromEnvironment('SHOT_WIDTH', defaultValue: '390'),
);
final _height = double.parse(
  const String.fromEnvironment('SHOT_HEIGHT', defaultValue: '844'),
);
const _checkText = bool.fromEnvironment('SHOT_CHECK_TEXT');
const _dpr = 2.0;
final _textScale = double.parse(
  const String.fromEnvironment('SHOT_TEXT_SCALE', defaultValue: '1'),
);

String _location() => switch (_page) {
  'start' => AppRoutes.start,
  'school' ||
  'school_empty' ||
  'school_due' ||
  'school_match' ||
  'match_sheet' => AppRoutes.school,
  'link' => AppRoutes.schoolLink,
  'profile' => AppRoutes.profile,
  'announcements' => AppRoutes.schoolAnnouncements,
  'payments' ||
  'payments_verify' ||
  'payments_verify_cash' => AppRoutes.schoolPayments,
  'early_exits' => AppRoutes.schoolEarlyExits,
  'attendance' || 'attendance_day' => AppRoutes.schoolAttendancePath('st-1'),
  'contacts' => AppRoutes.schoolContactsPath(student: 'st-1'),
  'contact' ||
  'compose' => AppRoutes.schoolContactPath('stf-h', student: 'st-1'),
  'contact_psych' => AppRoutes.schoolContactPath('stf-p', student: 'st-1'),
  'thread' => AppRoutes.schoolThreadPath('th-1'),
  'overview' || 'overview_year' => AppRoutes.schoolStudentPath('st-1'),
  'announcement' => AppRoutes.schoolAnnouncementPath('a-1'),
  _ => AppRoutes.dashboard,
};

final _children = [
  Child(
    id: 'kid-1',
    name: 'Aziza',
    age: 12,
    gender: Gender.female,
    region: 'Toshkent',
    familyCode: '12345',
    createdAt: DateTime(2026, 9, 2),
    isConnected: true,
    deviceModel: 'Galaxy A15',
  ),
  Child(
    id: 'kid-2',
    name: 'Jasur',
    age: 8,
    gender: Gender.male,
    region: 'Toshkent',
    familyCode: '54321',
    createdAt: DateTime(2026, 9, 2),
  ),
];

const _school = SchoolInfo(
  id: 'sc-1',
  name: '24-sonli umumta’lim maktabi',
  shortName: '24-maktab',
  city: 'Toshkent',
);

/// Jasur hali farzandga bog'lanmagan (ota-ona endigina kod bilan ulandi).
bool get _unmatched => _page == 'school_match' || _page == 'match_sheet';

SchoolLinks _links() => _page == 'school_empty'
    ? SchoolLinks.empty
    : SchoolLinks(
        links: [
          SchoolLink(
            guardianId: 'g-1',
            fullName: 'Nilufar Karimova',
            relation: GuardianRelation.mother,
            school: _school,
            students: [
              const LinkedStudent(
                id: 'st-1',
                fullName: 'Karimova Aziza',
                className: '6-B',
                linkedBy: LinkedBy.me,
                childId: 'kid-1',
              ),
              LinkedStudent(
                id: 'st-2',
                fullName: 'Karimov Jasur',
                className: '2-A',
                linkedBy: _unmatched ? LinkedBy.none : LinkedBy.me,
                childId: _unmatched ? null : 'kid-2',
              ),
            ],
          ),
        ],
        children: const [],
      );

class _FakeAuth extends StateNotifier<BackendAuthState>
    implements BackendAuthNotifier {
  _FakeAuth()
    : super(
        const AuthAuthenticated(
          AuthUser(
            id: 'u-1',
            role: 'PARENT',
            displayName: 'Nilufar Karimova',
            phone: '+998 90 123 45 67',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('parent screenshot', (tester) async {
    debugDisableShadows = false;
    tester.view
      ..physicalSize = Size(_width * _dpr, _height * _dpr)
      ..devicePixelRatio = _dpr;
    tester.platformDispatcher.textScaleFactorTestValue = _textScale;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      await EasyLocalization.ensureInitialized();
      for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600]) {
        GoogleFonts.poppins(fontWeight: w);
        GoogleFonts.unbounded(fontWeight: w);
      }
      GoogleFonts.poppins(fontWeight: FontWeight.w700);
      await GoogleFonts.pendingFonts();
      await _loadIconFonts();
    });

    final children = switch (_page) {
      'control_empty' || 'start' => <Child>[],
      'control' => _children.take(1).toList(),
      'control_switch' => _children,
      _ => _children,
    };
    final boundary = GlobalKey();
    final router = GoRouter(
      initialLocation: _location(),
      routes: buildAppRoutes(),
    );
    final app = EasyLocalization(
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('uz'),
      startLocale: const Locale(_locale),
      child: ProviderScope(
        overrides: [
          backendAuthProvider.overrideWith((ref) => _FakeAuth()),
          childrenProvider.overrideWith((ref) => Stream.value(children)),
          schoolLinksProvider.overrideWith((ref) async => _links()),
          schoolRepositoryProvider.overrideWithValue(FakeSchoolRepository()),
          schoolConnectRepositoryProvider.overrideWithValue(
            FakeSchoolConnectRepository(),
          ),
          growthSummaryProvider.overrideWith((ref, args) async => demoGrowth),
          iqSummaryProvider.overrideWith((ref, id) async => demoIq),
          kelajakSummaryProvider.overrideWith((ref, id) async => demoKelajak),
          schoolUnreadCountProvider.overrideWith((ref) async => 2),
          if (_page == 'overview_year')
            studentOverviewProvider.overrideWith(
              (ref, id) async => StudentOverview(
                student: const ConnectStudent(
                  id: 'st-1',
                  name: 'Aliyev Ali',
                  className: '1-A',
                  schoolName: 'Parvoz QA maktabi',
                ),
                period: const OverviewPeriod(
                  isQuarter: false,
                  from: '2026-09-01',
                  to: '2026-11-11',
                ),
                attendance: demoOverview.attendance,
                tasks: demoOverview.tasks,
              ),
            ),
          if (_page == 'school_due')
            schoolPaymentsProvider.overrideWith(
              (ref) async => const [
                SchoolPaymentReminder(
                  id: 'p-due',
                  schoolId: 'sc-1',
                  schoolName: '24-maktab',
                  nextDate: '2026-11-01',
                  prepaidMonths: 0,
                  paused: false,
                  children: [],
                  openVerification: false,
                ),
              ],
            ),
          todayAttendanceProvider.overrideWith(
            (ref, id) => AsyncData(
              id == 'st-1'
                  ? const AttendanceDay(
                      date: '2026-11-09',
                      schoolDay: true,
                      record: AttendanceRecord(
                        status: AttendanceStatus.present,
                        inAt: '08:12',
                      ),
                    )
                  : const AttendanceDay(
                      date: '2026-11-09',
                      schoolDay: true,
                      record: AttendanceRecord(
                        status: AttendanceStatus.late,
                        inAt: '08:41',
                      ),
                    ),
            ),
          ),
          latestChatItemProvider.overrideWith(
            (ref, id) => const AsyncData(null),
          ),
          unreadChatCountProvider.overrideWith(
            (ref, id) => AsyncData(id == 'kid-1' ? 2 : 0),
          ),
          sessionsProvider.overrideWith(_FakeSessions.new),
        ],
        child: Builder(
          builder: (context) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: router,
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: app));
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
    if (_page == 'payments_verify' || _page == 'payments_verify_cash') {
      await tester.tap(find.text("To'laganman, tekshiring").first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(
        find.text(_page == 'payments_verify' ? 'Click' : 'Naqd').first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (_page == 'attendance_day') {
      await tester.tap(find.text('5').first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    if (_page == 'compose') {
      await tester.tap(find.text('Darsga kelmaydi').first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    if (_page == 'link') {
      await tester.enterText(find.byType(TextField).first, 'K7MQ4XPA');
      await tester.pump(const Duration(milliseconds: 300));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (_page == 'match_sheet') {
      final match = find.text("Farzandga bog'lash").first;
      await tester.ensureVisible(match);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(match);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Jasur').last);
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (_page == 'control_switch') {
      await tester.tap(find.text('Aziza').first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    if (_scroll > 0) {
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, -_scroll.toDouble()),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.runAsync(() async {
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
    }
    if (_checkText) _reportMidWordBreaks(tester);
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: _dpr);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(_out)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    debugDisableShadows = true;
  });
}

/// So'z o'rtasidan uzilgan matnlar (SHOT_CHECK_TEXT).
void _reportMidWordBreaks(WidgetTester tester) {
  var found = 0;
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    final breaks = midWordBreaks(paragraph);
    if (breaks.isEmpty) continue;
    found++;
    final text = paragraph.text.toPlainText().replaceAll('\n', ' ');
    stdout.writeln(
      'MID-WORD [$_page ${_width.toInt()}px ${_textScale}x] '
      '«$text» ${paragraph.size.width.toStringAsFixed(0)}px $breaks',
    );
  }
  stdout.writeln(
    'MID-WORD-TOTAL [$_page ${_width.toInt()}px ${_textScale}x] $found',
  );
}

class _FakeSessions extends SessionsNotifier {
  @override
  Future<List<UserSession>> build() async => const [];
}

/// Ikon shriftlari (flutter_test ularni yuklamaydi — kvadrat chiqadi):
/// Solar (paket) va Material.
Future<void> _loadIconFonts() async {
  final home = Platform.environment['HOME'] ?? '';
  const solar = 'hosted/pub.dev/solar_icons-0.1.0/fonts';
  for (final family in ['SolarIconsBold', 'SolarIconsOutline']) {
    final file = File('$home/.pub-cache/$solar/$family.ttf');
    if (!file.existsSync()) continue;
    final loader = FontLoader('packages/solar_icons/$family')
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
  const material =
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf';
  final file = File(material);
  if (file.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
}

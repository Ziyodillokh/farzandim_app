// Growth v5 dizayn QA — ekranni kanvas o'lchamida (390×844) PNG'ga chizadi.
// CI'da ishlamaydi (`tool/` ichida). Kanvasdagi artboard bilan solishtirish uchun:
//
//   FLUTTER_ROOT=/opt/homebrew/share/flutter flutter test tool/screenshots/v5_shots.dart \
//     --dart-define=SHOT_OUT=/tmp/kit.png \
//     --dart-define=SHOT_PAGE=kit          # kit | today | learn | school | school_none | school_review | perm_setup | me | k_login ...
//                                          # all — hammasi bitta jarayonda (SHOT_OUT — papka)
//     --dart-define=SHOT_SCROLL=0          # ixtiyoriy: pastga siljitish (px)
//     --dart-define=SHOT_LOCALE=uz --dart-define=SHOT_TEXT_SCALE=1.0
//     --dart-define=SHOT_WIDTH=390 --dart-define=SHOT_HEIGHT=844 --dart-define=SHOT_SCALE=2

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/learning/domain/learning_models.dart';
import 'package:farzandim_child/core/routing/kelajak_routes.dart';
import 'package:farzandim_child/features/kelajak/presentation/kelajak_navigation.dart';
import 'package:farzandim_child/features/kelajak/presentation/providers/kelajak_providers.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/permission_setup_screen.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_local_data.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/login_screen.dart';
import 'package:farzandim_child/growth/men/lock/app_lock.dart';
import 'package:farzandim_child/growth/men/lock/lock_gate.dart';
import 'package:farzandim_child/growth/kirish/recovery_screens.dart';
import 'package:farzandim_child/growth/kirish/school_code_screens.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/features/learning/fake_learning_repository.dart';
import '../../test/features/learning/learning_fixtures.dart';
import '../../test/features/school/fake_school_repository.dart';
import '../../test/growth/fake_kirish.dart';
import '../../test/features/kelajak/kelajak_test_app.dart' show kelajakRepo;
import '../../test/growth/fake_library.dart';
import '../../test/growth/fake_men.dart';
import '../../test/growth/fake_school_v5.dart';
import '../../test/growth/fake_topics_repository.dart';
import '../../test/growth/fake_voice.dart';
import '../../test/growth/g5_overrides.dart';
import '../../test/growth/g5_test_app.dart' show preloadG5Fonts;

const _out = String.fromEnvironment('SHOT_OUT', defaultValue: 'build/v5.png');
const _envPage = String.fromEnvironment('SHOT_PAGE', defaultValue: 'kit');

/// Joriy ekran (`SHOT_PAGE=all` da har test o'zinikini qo'yadi).
var _page = _envPage;
const _scroll = int.fromEnvironment('SHOT_SCROLL');
const _locale = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'uz');
const _width = int.fromEnvironment('SHOT_WIDTH', defaultValue: 390);
const _height = int.fromEnvironment('SHOT_HEIGHT', defaultValue: 844);
const _scale = String.fromEnvironment('SHOT_SCALE', defaultValue: '2');
const _textScale = String.fromEnvironment('SHOT_TEXT_SCALE', defaultValue: '1');

String _location(String page) => switch (page) {
  'perm_setup' => '/permission-setup',
  'today' || 'today_setup' => GrowthV5Routes.today,
  'practice' ||
  'practice_selected' ||
  'practice_wrong' ||
  'practice_result' => GrowthV5Routes.practice(Subject.math),
  'learn' => GrowthV5Routes.learn,
  'library' => GrowthV5Routes.library,
  'audiobook' => GrowthV5Routes.audiobook('b1'),
  'article' => GrowthV5Routes.article('a1'),
  'kids_today' => GrowthV5Routes.today,
  'kids_wrong' || 'kids_result' => GrowthV5Routes.practice(Subject.math),
  'map' => GrowthV5Routes.subjectMap(Subject.math),
  'topic' => GrowthV5Routes.topic(Subject.math, 't4'),
  'school' || 'school_none' || 'school_review' => GrowthV5Routes.school,
  'tasks' => GrowthV5Routes.schoolTasks,
  'task' => GrowthV5Routes.schoolTask('t1'),
  'task_written' => GrowthV5Routes.schoolTask('w1'),
  'attendance' => GrowthV5Routes.attendance,
  'history' => GrowthV5Routes.attendanceHistory,
  'notices' => GrowthV5Routes.notices,
  'timetable' => GrowthV5Routes.timetable,
  'submit' => GrowthV5Routes.homeworkSubmit('w1'),
  'voice' => GrowthV5Routes.voice,
  'voice_intro' => GrowthV5Routes.voiceSurvey,
  'voice_q' => GrowthV5Routes.voiceSurveyRun,
  'voice_help' => GrowthV5Routes.voiceHelp,
  'voice_compose' => GrowthV5Routes.voiceCompose,
  'voice_list' => GrowthV5Routes.voiceRequests,
  'voice_status' => GrowthV5Routes.voiceRequest('r2'),
  'voice_pending' => GrowthV5Routes.voiceRequest('local-1'),
  'voice_chat' => GrowthV5Routes.voiceRequest('r1'),
  'voice_personal' => GrowthV5Routes.voicePersonal('p1'),
  'me' => GrowthV5Routes.me,
  'me_growth' => GrowthV5Routes.meGrowth,
  'me_don' => GrowthV5Routes.meDon,
  'me_level' => GrowthV5Routes.meLevel,
  'me_settings' => GrowthV5Routes.meSettings,
  'me_perms' => GrowthV5Routes.mePermissions,
  'me_notify' => GrowthV5Routes.meNotifications,
  'me_help' => GrowthV5Routes.meHelp,
  'me_privacy' => GrowthV5Routes.mePrivacy,
  'k_welcome' => GrowthV5Routes.kirish,
  'k_login' ||
  'k_login_error' ||
  'k_login_locked' ||
  'k_setup' => GrowthV5Routes.kirishLogin,
  'k_recovery' => GrowthV5Routes.kirishRecovery,
  'k_recovery_status' ||
  'k_recovery_done' => GrowthV5Routes.kirishRecoveryStatus,
  'k_profile' => GrowthV5Routes.kirishProfile,
  'k_code' || 'k_code_error' => GrowthV5Routes.kirishCode,
  'k_locked' => GrowthV5Routes.kirishLocked,
  'k_review' || 'k_confirmed' => GrowthV5Routes.kirishStatus,
  'k_correction' => GrowthV5Routes.kirishCorrection,
  'k_accounts' => GrowthV5Routes.kirishAccounts,
  'k_closed' => GrowthV5Routes.kirishClosed,
  'q_interests' => GrowthV5Routes.kelajakInterests,
  'q_careers' => GrowthV5Routes.kelajakCareers,
  'q_goal' => GrowthV5Routes.kelajakGoal,
  'q_safety' => GrowthV5Routes.kelajakSafety,
  'q_lesson' => GrowthV5Routes.kelajakLesson('codes'),
  'f_family' => GrowthV5Routes.family,
  'f_sos' => GrowthV5Routes.familySos,
  'subjects' => GrowthV5Routes.allSubjects,
  'k_tests' || 'k_tests_mixed' || 'k_tests_age' => KelajakRoutes.hub,
  'lock' => GrowthV5Routes.today,
  'me_lock' || 'me_lock_on' || 'me_lock_entry' => GrowthV5Routes.meLock,
  'me_password' => GrowthV5Routes.mePassword,
  'f_extra' => GrowthV5Routes.familyExtraTime,
  _ => GrowthV5Routes.kit,
};

const _allPages = [
  'k_tests',
  'k_tests_mixed',
  'k_tests_age',
  'lock',
  'me_lock',
  'me_lock_on',
  'me_lock_entry',
  'subjects',
  'me_password',
  'a1',
  'article',
  'attendance',
  'audiobook',
  'b1',
  'codes',
  'f_extra',
  'f_family',
  'f_sos',
  'history',
  'k_accounts',
  'k_closed',
  'k_code',
  'k_code_error',
  'k_confirmed',
  'k_correction',
  'k_locked',
  'k_login',
  'k_login_error',
  'k_login_locked',
  'k_profile',
  'k_recovery',
  'k_recovery_done',
  'k_recovery_status',
  'k_review',
  'k_setup',
  'k_welcome',
  'kids_result',
  'kids_today',
  'kids_wrong',
  'learn',
  'library',
  'map',
  'me',
  'me_don',
  'me_growth',
  'me_help',
  'me_level',
  'me_notify',
  'me_perms',
  'me_privacy',
  'me_settings',
  'notices',
  'p1',
  'practice',
  'practice_result',
  'practice_selected',
  'practice_wrong',
  'q_careers',
  'q_goal',
  'q_interests',
  'q_lesson',
  'q_safety',
  'r1',
  'r2',
  'school',
  'submit',
  't1',
  't4',
  'task',
  'task_written',
  'tasks',
  'timetable',
  'today',
  'today_setup',
  'topic',
  'voice',
  'voice_chat',
  'voice_compose',
  'voice_help',
  'voice_intro',
  'voice_list',
  'voice_pending',
  'voice_personal',
  'voice_q',
  'voice_status',
  'w1',
];

void main() {
  const pages = _envPage == 'all' ? _allPages : [_envPage];
  for (final page in pages) {
    _shot(page);
  }
}

void _shot(String page) {
  final out = _envPage == 'all' ? '$_out/${page}_$_locale.png' : _out;
  testWidgets('v5 screenshot $page', (tester) async {
    _page = page;
    // flutter_test soyalarni xiralashtirmasdan chizadi (golden barqarorligi uchun);
    // qurilmadagidek ko'rinishi uchun bu yerda yoqamiz va oxirida qaytaramiz.
    debugDisableShadows = false;
    final dpr = double.parse(_scale);
    tester.view
      ..physicalSize = Size(_width * dpr, _height * dpr)
      ..devicePixelRatio = dpr;
    tester.platformDispatcher.textScaleFactorTestValue = double.parse(
      _textScale,
    );
    addTearDown(tester.view.reset);
    if (page == 'perm_setup') {
      // Ruxsatlar ekrani: to'rttasi yoqilgan, «ilovalar ustida ko'rsatish» yo'q.
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('farzandim/usage_stats'),
        (call) async => switch (call.method) {
          'hasPermission' => true,
          'hasOverlayPermission' => false,
          _ => null,
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('farzandim_child/device_admin'),
        (call) async => true,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => call.method == 'checkPermissionStatus' ? 1 : null,
      );
    }
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      // Cheklov akkauntga bog'langan: g5Overrides'dagi bola — child-1.
      if (_page == 'k_locked')
        accountKey(kSchoolCodeLockKey, 'child-1'): DateTime.now()
            .add(const Duration(minutes: 12))
            .toIso8601String(),
    });
    // ignore: invalid_use_of_visible_for_testing_member
    FlutterSecureStorage.setMockInitialValues({});
    final registry = AccountRegistry(MemoryAccountStore());
    final kirishRepo = _kirishRepo();
    final lock = AppLock(MemoryLockStore());
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      await preloadG5Fonts();
      if (_page == 'perm_setup') await _loadMaterialIcons();
      await EasyLocalization.ensureInitialized();
      await _seedAccounts(registry);
      if (_page == 'me_lock_on' || _page == 'lock') {
        await lock.setPin('2580');
        await lock.setBiometrics(true);
      }
      if (_page == 'lock') await lock.load();
    });

    final boundary = GlobalKey();
    final router = GoRouter(
      initialLocation: _location(_page),
      routes: [
        ...buildGrowthV5Routes(),
        ...kelajakRoutes,
        GoRoute(
          path: '/permission-setup',
          builder: (_, _) => const PermissionSetupScreen(),
        ),
      ],
    );
    final app = EasyLocalization(
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('uz'),
      startLocale: Locale(_locale),
      child: ProviderScope(
        overrides: () {
          final learning = _learning();
          return [
            ...libraryOverrides(
              player: FakeLibPlayer(),
              articles: FakeLibArticles(),
            ),
            schoolV5RepositoryProvider.overrideWithValue(
              FakeSchoolV5Repository(
                notices: kSchoolNotices(),
                month: kSchoolMonth(),
                day: kSchoolDay(),
              ),
            ),
            ...menOverrides(kFakeMen()),
            ...kirishOverrides(
              repo: kirishRepo,
              registry: registry,
              // Qulf ekranida barmoq izi oynasi «bekor qilinadi».
              deviceKey: FakeDeviceKey(allow: _page != 'lock'),
            ),
            recoveryTicketStoreProvider.overrideWithValue(
              MemoryAccountStore()
                ..values['g5_recovery_ticket_v1'] = jsonEncode(
                  RecoveryTicket(
                    requestId: 'rq-1',
                    pollToken: 'poll-1',
                    channel: RecoveryChannel.parent,
                    createdAt: kG5Now.subtract(const Duration(minutes: 20)),
                  ).toJson(),
                ),
            ),
            ...voiceOverrides(
              FakeVoiceRepository(
                survey: kVoiceSurvey(),
                contact: kVoiceContact,
                requests: kVoiceRequests,
                details: kVoiceDetails,
              ),
              store: MemoryOutboxStore()
                ..values['g5_voice_outbox_v1_child-1'] =
                    '[{"id":"local-1","message":"Yordam kerak","urgent":true,"createdAt":"2026-11-05T09:20:00.000"}]',
            ),
            ...g5Overrides(
              learning: learning,
              unread: 2,
              school: FakeSchoolRepository(
                today: kSchoolToday,
                assignments: kSchoolTasks,
                psychAssignments: const [kPersonalSummary],
                psychTests: const [kPersonalTest],
                clock: () => kG5Now,
              ),
              // Maktabga ulanmagan bola (M01: kod kiritish / tasdiq kutilmoqda).
              schoolAccount: _page == 'school_none' || _page == 'school_review'
                  ? null
                  : 'child-1',
              topics: FakeTopicsRepository(
                topics: _sampleTopics,
                currentTopicId: 't4',
                learning: learning,
              ),
            ),
            kelajakRepositoryProvider.overrideWithValue(
              kelajakRepo(
                overview: switch (_page) {
                  'k_tests_mixed' => 'overview_ok_today_mixed',
                  'k_tests_age' => 'overview_age_required',
                  _ => 'overview_ok_fresh',
                },
              ),
            ),
            kelajakAccountProvider.overrideWithValue('child-1'),
            // g5Overrides'dagi bo'sh qulfdan keyin — shu ustun.
            appLockProvider.overrideWithValue(lock),
          ];
        }(),
        child: Builder(
          builder: (context) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: router,
            builder: (context, child) => AppLockGate(
              lock: lock,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: app));
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await tester.pump();
      }
      await GoogleFonts.pendingFonts();
    });
    await tester.pump(const Duration(milliseconds: 400));
    if (_page == 'k_setup') {
      unawaited(
        router.push(
          GrowthV5Routes.kirishSetup,
          extra: const SetupArgs(
            setupToken: 'setup-1',
            login: 'jasur.k07',
            childName: 'Jasur Karimov',
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    await _act(tester);
    if (_scroll > 0) {
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, -_scroll.toDouble()),
      );
      await tester.pump(const Duration(milliseconds: 800));
    }

    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: dpr);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out)
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    // Test tugashidan oldin qaytariladi (aks holda flutter_test xato beradi).
    debugDisableShadows = true;
    expect(File(out).existsSync(), isTrue);
  });
}

/// Namunaviy o'quvchi: 6-sinf, uch fan; Ingliz tili bugun bajarilgan.
FakeLearningRepository _learning() => FakeLearningRepository(
  profile: _page == 'today_setup'
      ? null
      : _page.startsWith('kids')
      ? const LearningProfile(
          grade: 2,
          subjects: [Subject.native, Subject.math],
        )
      : const LearningProfile(
          grade: 6,
          subjects: [Subject.math, Subject.english, Subject.native],
        ),
  clock: () => kG5Now,
  results: [
    result(Subject.english, 9, kG5Now.subtract(const Duration(hours: 1))),
    result(Subject.math, 6, kG5Now.subtract(const Duration(days: 4))),
  ],
);

/// Holatga yetkazish: variant tanlash, tekshirish, mashqni tugatish.
Future<void> _act(WidgetTester tester) async {
  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> type(Finder f, String text) async {
    await tester.enterText(f, text);
    await tester.pump(const Duration(milliseconds: 100));
  }

  const letters = ['A', 'B', 'C', 'D'];
  if (_page == 'me_lock_entry') {
    await tap(find.text('PIN-kod qoʻyish'));
    await tester.tap(find.bySemanticsLabel('2').last);
    await tester.pump(const Duration(milliseconds: 300));
    return;
  }
  switch (_page) {
    case 'k_login_error' || 'k_login_locked':
      await type(find.byType(TextField).first, 'aziza.k24');
      await type(find.byType(TextField).last, 'xato1234');
      await tap(find.text('Kirish'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
    case 'k_setup':
      await type(find.byType(TextField).first, 'yangiParol7');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
    case 'k_code_error':
      await type(find.byType(TextField).first, '047215');
      await tester.pump(const Duration(milliseconds: 300));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
    case 'practice_selected':
      await tap(find.text('B'));
    case 'practice_wrong':
      await tap(find.text('B'));
      await tap(find.text('Tekshirish'));
    case 'kids_wrong':
      await tap(find.bySemanticsLabel(RegExp('^B variant')));
      await tap(find.text('Tekshirish'));
    case 'kids_result':
      for (var i = 0; i < 10; i++) {
        final pick = i == 3 || i == 7 ? (i + 1) % 4 : i % 4;
        await tap(find.bySemanticsLabel(RegExp('^${letters[pick]} variant')));
        await tap(find.text('Tekshirish'));
        await tap(find.text(i == 9 ? 'Natijani koʻrish' : 'Keyingi savol'));
      }
    case 'practice_result':
      for (var i = 0; i < 10; i++) {
        final pick = i == 3 || i == 7 ? (i + 1) % 4 : i % 4;
        await tap(find.text(letters[pick]));
        await tap(find.text('Tekshirish'));
        await tap(find.text(i == 9 ? 'Natijani koʻrish' : 'Keyingi savol'));
      }
  }
}

/// Kirish ekranlari uchun soxta server holati.
FakeKirishRepository _kirishRepo() => FakeKirishRepository(
  loginError: switch (_page) {
    'k_login_error' => const KirishException(KirishError.invalidCredentials),
    'k_login_locked' => const KirishException(
      KirishError.locked,
      retryAfter: Duration(minutes: 14),
    ),
    _ => null,
  },
  linkError: _page == 'k_code_error'
      ? const KirishException(KirishError.codeInvalid)
      : null,
  status: switch (_page) {
    'k_review' || 'school_review' => const LinkStatus(
      student: StudentLinkState.underReview,
      parent: ParentLinkState.pending,
    ),
    'k_confirmed' => const LinkStatus(
      student: StudentLinkState.confirmed,
      parent: ParentLinkState.confirmed,
      schoolName: '45-maktab',
      className: '6-B',
    ),
    _ => LinkStatus.none,
  },
  recovery: _page == 'k_recovery_done'
      ? RecoveryStatus(
          state: RecoveryState.restored,
          createdAt: kG5Now.subtract(const Duration(minutes: 20)),
          restoredAt: kG5Now.subtract(const Duration(minutes: 5)),
          signedOutAt: kG5Now.subtract(const Duration(minutes: 5)),
        )
      : RecoveryStatus(
          state: RecoveryState.received,
          createdAt: kG5Now.subtract(const Duration(minutes: 20)),
        ),
);

/// A10/A12 uchun qurilmadagi akkauntlar.
Future<void> _seedAccounts(AccountRegistry registry) async {
  switch (_page) {
    case 'k_accounts':
      await registry.upsert(
        const DeviceAccount(
          childId: 'child-1',
          name: 'Aziza Karimova',
          owner: true,
          className: '6-B',
        ),
      );
      await registry.upsert(
        const DeviceAccount(
          childId: 'child-9',
          name: 'Jasur Karimov',
          owner: false,
          login: 'jasur.k07',
          className: '4-A',
          deviceKey: true,
          sessionId: 'sid-9',
        ),
      );
    case 'k_closed':
      await registry.ownerClosed(notice: SessionClosedReason.recovered);
  }
}

final _sampleTopics = [
  topic(
    't1',
    'Natural sonlar',
    position: 1,
    mastery: TopicMastery.mastered,
    completedAttempts: 3,
  ),
  topic(
    't2',
    'Kasrlar',
    position: 2,
    mastery: TopicMastery.mastered,
    completedAttempts: 24,
    lastAssessedAt: DateTime(2026, 10, 28),
  ),
  topic('t3', 'Oʻnli kasrlar', position: 3, mastery: TopicMastery.practice),
  topic(
    't4',
    'Foizlar',
    position: 4,
    mastery: TopicMastery.practice,
    completedAttempts: 6,
    goal: 'Sonning foizini topishni oʻrganasan',
    lastResult: TopicResult(
      correct: 6,
      total: 10,
      completedAt: DateTime(2026, 11, 1),
    ),
  ),
  topic('t5', 'Nisbat va proporsiya', position: 5),
];

/// Eski (Material) ekranlar ikonlari — flutter_test shriftni o'zi yuklamaydi.
Future<void> _loadMaterialIcons() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  await loader.load();
}

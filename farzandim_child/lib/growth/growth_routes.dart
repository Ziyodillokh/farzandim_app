// Growth v5 marshrutlari.
//
// Qoida (konsepsiya v2): pastki menyu faqat to'rtta ildiz ekranda (B01, U01,
// M01, I01) turadi. Qolgan barcha ekranlar root navigator'ga to'liq ekran
// sifatida ochiladi — ularda menyu yo'q.

import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/growth/bugun/notifications_screen.dart';
import 'package:farzandim_child/growth/bugun/today_screen.dart';
import 'package:farzandim_child/growth/dev/kit_gallery_screen.dart';
import 'package:farzandim_child/growth/maktab/attendance_history_screen.dart';
import 'package:farzandim_child/growth/maktab/attendance_screen.dart';
import 'package:farzandim_child/growth/maktab/homework_submit_screen.dart';
import 'package:farzandim_child/growth/maktab/notices_screen.dart';
import 'package:farzandim_child/growth/maktab/school_screen.dart';
import 'package:farzandim_child/growth/maktab/task_detail_screen.dart';
import 'package:farzandim_child/growth/maktab/tasks_screen.dart';
import 'package:farzandim_child/growth/maktab/timetable_screen.dart';
import 'package:farzandim_child/growth/kelajak/careers_screen.dart';
import 'package:farzandim_child/growth/kelajak/interests_screen.dart';
import 'package:farzandim_child/growth/kelajak/kelajak_data.dart';
import 'package:farzandim_child/growth/kelajak/safety_screens.dart';
import 'package:farzandim_child/growth/kelajak/weekly_goal_screen.dart';
import 'package:farzandim_child/growth/oila/extra_time_screen.dart';
import 'package:farzandim_child/growth/oila/family_screen.dart';
import 'package:farzandim_child/growth/oila/sos_screen.dart';
import 'package:farzandim_child/growth/oflayn/offline_screens.dart';
import 'package:farzandim_child/growth/olimpiada/olympiad_data.dart';
import 'package:farzandim_child/growth/olimpiada/olympiad_screens.dart';
import 'package:farzandim_child/growth/tafakkur/thinking_result_screen.dart';
import 'package:farzandim_child/growth/kirish/account_screens.dart';
import 'package:farzandim_child/growth/kirish/data/kirish_models.dart';
import 'package:farzandim_child/growth/kirish/link_screens.dart';
import 'package:farzandim_child/growth/kirish/login_screen.dart';
import 'package:farzandim_child/growth/kirish/profile_screen.dart';
import 'package:farzandim_child/growth/kirish/recovery_screens.dart';
import 'package:farzandim_child/growth/kirish/school_code_screens.dart';
import 'package:farzandim_child/growth/kirish/setup_screen.dart';
import 'package:farzandim_child/growth/kirish/welcome_screen.dart';
import 'package:farzandim_child/growth/men/don_history_screen.dart';
import 'package:farzandim_child/growth/men/growth_screen.dart';
import 'package:farzandim_child/growth/men/help_screen.dart';
import 'package:farzandim_child/growth/men/level_screen.dart';
import 'package:farzandim_child/growth/men/me_screen.dart';
import 'package:farzandim_child/growth/men/notifications_screen.dart';
import 'package:farzandim_child/growth/men/permissions_screen.dart';
import 'package:farzandim_child/growth/men/lock/lock_settings_screen.dart';
import 'package:farzandim_child/growth/men/password_screen.dart';
import 'package:farzandim_child/growth/oqish/learn/all_subjects_screen.dart';
import 'package:farzandim_child/growth/men/privacy_screen.dart';
import 'package:farzandim_child/growth/men/settings_screen.dart';
import 'package:farzandim_child/growth/ovoz/compose_screen.dart';
import 'package:farzandim_child/growth/ovoz/help_screen.dart';
import 'package:farzandim_child/growth/ovoz/personal_survey_screen.dart';
import 'package:farzandim_child/growth/ovoz/request_screen.dart';
import 'package:farzandim_child/growth/ovoz/requests_screen.dart';
import 'package:farzandim_child/growth/ovoz/survey_intro_screen.dart';
import 'package:farzandim_child/growth/ovoz/survey_screen.dart';
import 'package:farzandim_child/growth/ovoz/voice_screen.dart';
import 'package:farzandim_child/growth/oqish/attempts/attempts_screen.dart';
import 'package:farzandim_child/growth/oqish/attempts/result_detail_screen.dart';
import 'package:farzandim_child/growth/oqish/learn/learn_screen.dart';
import 'package:farzandim_child/growth/oqish/library/article_screen.dart';
import 'package:farzandim_child/growth/oqish/library/audiobook_screen.dart';
import 'package:farzandim_child/growth/oqish/library/library_screen.dart';
import 'package:farzandim_child/growth/oqish/library/video_lesson_screen.dart';
import 'package:farzandim_child/growth/oqish/practice/practice_screen.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_map_screen.dart';
import 'package:farzandim_child/growth/oqish/topics/topic_screen.dart';
import 'package:farzandim_child/growth/shell/growth_shell.dart';
import 'package:farzandim_child/growth/shell/uninstall_guard_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:go_router/go_router.dart';

abstract final class GrowthV5Routes {
  /// B01 · Bugun
  static const today = '/bugun';

  /// U01 · O'qish markazi
  static const learn = '/oqish';

  /// M01 · Maktab
  static const school = '/maktab';

  /// I01 · Men
  static const me = '/men';

  /// U04–U08 · Fan bo'yicha mashq (`/mashq/math`, mavzu bilan `?mavzu=<id>`).
  static String practice(Subject subject, {String? topicId}) => topicId == null
      ? '/mashq/${subject.name}'
      : '/mashq/${subject.name}?mavzu=${Uri.encodeQueryComponent(topicId)}';
  static const practicePattern = '/mashq/:subject';

  /// B02 · Bildirishnomalar.
  static const notifications = '/bugun/xabarlar';

  /// U11 · Kutubxona va U12–U14 materiallar.
  static const library = '/oqish/kutubxona';
  static String audiobook(String id) =>
      '/oqish/kutubxona/audio/${Uri.encodeComponent(id)}';
  static String video(String id) =>
      '/oqish/kutubxona/video/${Uri.encodeComponent(id)}';
  static String article(String id) =>
      '/oqish/kutubxona/maqola/${Uri.encodeComponent(id)}';

  /// M02–M08 · Maktab bo'limi.
  static const schoolTasks = '/maktab/vazifalar';
  static String schoolTask(String id) =>
      '/maktab/vazifa/${Uri.encodeComponent(id)}';
  static String homeworkSubmit(String id) =>
      '/maktab/vazifa/${Uri.encodeComponent(id)}/javob';
  static const attendance = '/maktab/davomat';
  static const attendanceHistory = '/maktab/davomat/tarix';
  static const notices = '/maktab/elonlar';
  static const timetable = '/maktab/jadval';

  /// A · Kirish va ulanish.
  static const kirish = '/kirish';
  static const kirishLogin = '/kirish/login';
  static const kirishSetup = '/kirish/sozlash';
  static const kirishRecovery = '/kirish/tiklash';
  static const kirishRecoveryStatus = '/kirish/tiklash/holat';
  static const kirishAccounts = '/kirish/akkauntlar';
  static const kirishClosed = '/kirish/chiqildi';
  static const kirishProfile = '/kirish/sinf';
  static const kirishCode = '/kirish/maktab-kodi';
  static const kirishLocked = '/kirish/cheklandi';
  static const kirishStatus = '/kirish/ulanish';
  static const kirishCorrection = '/kirish/tuzatish';

  /// Tokensiz ochiladigan kirish ekranlari (router himoyasidan tashqari).
  static const kirishPublic = {
    kirish,
    kirishLogin,
    kirishSetup,
    kirishRecovery,
    kirishRecoveryStatus,
    kirishAccounts,
    kirishClosed,
  };

  /// I · Men.
  static const meGrowth = '/men/osish';
  static const meDon = '/men/don';
  static const meLevel = '/men/daraja';
  static const mePermissions = '/men/ruxsatlar';
  static const meSettings = '/men/sozlamalar';
  static const meNotifications = '/men/sozlamalar/bildirishnomalar';
  static const meHelp = '/men/sozlamalar/yordam';
  static const mePrivacy = '/men/sozlamalar/maxfiylik';
  static const mePassword = '/men/sozlamalar/parol';
  static const meLock = '/men/qulf';

  /// U17–U19 · Olimpiada, U16 · Tafakkur.
  static const olympiads = '/oqish/olimpiada';
  static String olympiadRun(String id) =>
      '/oqish/olimpiada/${Uri.encodeComponent(id)}';
  static const olympiadDone = '/oqish/olimpiada-topshirildi';
  static const thinking = '/oqish/tafakkur';

  /// U10 · Oflayn to'plam.
  static const offline = '/oqish/oflayn';
  static String offlinePractice(String subject) =>
      '/oqish/oflayn/${Uri.encodeComponent(subject)}';

  /// K · Qiziqishlar va kelajak.
  static const kelajakInterests = '/qiziqish';
  static const kelajakCareers = '/qiziqish/kasblar';
  static const kelajakGoal = '/qiziqish/maqsad';
  static const kelajakSafety = '/qiziqish/xavfsizlik';
  static String kelajakLesson(String lesson) =>
      '/qiziqish/xavfsizlik/${Uri.encodeComponent(lesson)}';

  /// F · Oila.
  static const family = '/oila';
  static const familySos = '/oila/sos';
  static const familyExtraTime = '/oila/vaqt';

  /// H · Bola ovozi.
  static const voice = '/maktab/ovoz';
  static const voiceSurvey = '/maktab/ovoz/sorov';
  static const voiceSurveyRun = '/maktab/ovoz/sorov/savollar';
  static const voiceHelp = '/maktab/ovoz/yordam';
  static const voiceCompose = '/maktab/ovoz/yordam/yangi';
  static const voiceRequests = '/maktab/ovoz/murojaatlar';
  static String voiceRequest(String id) =>
      '/maktab/ovoz/murojaat/${Uri.encodeComponent(id)}';
  static String voicePersonal(String id) =>
      '/maktab/ovoz/shaxsiy/${Uri.encodeComponent(id)}';

  /// U09 · Urinishlar tarixi.
  static const attempts = '/oqish/urinishlar';

  /// U08 (tarixdan) · Saqlangan natija.
  static String result(String id) => '/oqish/natija/${Uri.encodeComponent(id)}';
  static const resultPattern = '/oqish/natija/:resultId';

  /// U01b · Barcha fanlar.
  static const allSubjects = '/oqish/fanlar';

  /// U02 · Fanning bilim xaritasi.
  static String subjectMap(Subject subject) => '/oqish/fan/${subject.name}';
  static const subjectMapPattern = '/oqish/fan/:subject';

  /// U03 · Mavzu (`/oqish/mavzu/<id>?fan=math`).
  static String topic(Subject subject, String topicId) =>
      '/oqish/mavzu/${Uri.encodeComponent(topicId)}?fan=${subject.name}';
  static const topicPattern = '/oqish/mavzu/:topicId';

  /// Komponentlar galereyasi (faqat debug).
  static const kit = '/v5/kit';

  static const tabRoots = [today, learn, school, me];
}

List<RouteBase> buildGrowthV5Routes() => [
  StatefulShellRoute.indexedStack(
    // Qobiq ochilganda va ilovaga qaytilganda «O'chirishni taqiqlash»
    // siyosati ham qo'llanadi (fn-uninstall-guard-regression).
    builder: (context, state, shell) =>
        UninstallGuardSync(child: GrowthShell(navigationShell: shell)),
    branches: [
      for (final (index, path) in GrowthV5Routes.tabRoots.indexed)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: path,
              pageBuilder: (context, state) => tabPage(state, switch (index) {
                0 => const TodayScreen(),
                1 => const LearnScreen(),
                2 => const SchoolScreen(),
                _ => const MeScreen(),
              }),
            ),
          ],
        ),
    ],
  ),
  GoRoute(
    path: GrowthV5Routes.practicePattern,
    // Noma'lum fan (eski havola) — Bugun ekraniga.
    redirect: (context, state) =>
        Subject.fromName(state.pathParameters['subject']) == null
        ? GrowthV5Routes.today
        : null,
    pageBuilder: (context, state) => sessionPage(
      state,
      PracticeScreen(
        subject: Subject.fromName(state.pathParameters['subject'])!,
        topicId: state.uri.queryParameters['mavzu'],
      ),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.notifications,
    pageBuilder: (context, state) =>
        slidePage(state, const NotificationsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.schoolTasks,
    pageBuilder: (context, state) =>
        slidePage(state, const SchoolTasksScreen()),
  ),
  GoRoute(
    path: '/maktab/vazifa/:id',
    pageBuilder: (context, state) =>
        slidePage(state, SchoolTaskScreen(taskId: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/maktab/vazifa/:id/javob',
    pageBuilder: (context, state) => slidePage(
      state,
      HomeworkSubmitScreen(taskId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.attendance,
    pageBuilder: (context, state) => slidePage(state, const AttendanceScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.attendanceHistory,
    pageBuilder: (context, state) =>
        slidePage(state, const AttendanceHistoryScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.notices,
    pageBuilder: (context, state) => slidePage(state, const NoticesScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.timetable,
    pageBuilder: (context, state) => slidePage(state, const TimetableScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.meGrowth,
    pageBuilder: (context, state) => slidePage(state, const MeGrowthScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.meDon,
    pageBuilder: (context, state) =>
        slidePage(state, const MeDonHistoryScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.meLevel,
    pageBuilder: (context, state) => slidePage(state, const MeLevelScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.mePermissions,
    pageBuilder: (context, state) =>
        slidePage(state, const MePermissionsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.meSettings,
    pageBuilder: (context, state) => slidePage(state, const MeSettingsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.meNotifications,
    pageBuilder: (context, state) =>
        slidePage(state, const MeNotificationsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.meHelp,
    pageBuilder: (context, state) => slidePage(state, const MeHelpScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.mePrivacy,
    pageBuilder: (context, state) => slidePage(state, const MePrivacyScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.olympiads,
    pageBuilder: (context, state) =>
        slidePage(state, const OlympiadListScreen()),
  ),
  GoRoute(
    path: '${GrowthV5Routes.olympiads}/:id',
    redirect: (context, state) =>
        state.extra is Olympiad ? null : GrowthV5Routes.olympiads,
    pageBuilder: (context, state) =>
        slidePage(state, OlympiadRunScreen(olympiad: state.extra! as Olympiad)),
  ),
  GoRoute(
    path: GrowthV5Routes.olympiadDone,
    redirect: (context, state) => state.extra is (Olympiad, OlympiadReceipt)
        ? null
        : GrowthV5Routes.olympiads,
    pageBuilder: (context, state) {
      final (olympiad, receipt) = state.extra! as (Olympiad, OlympiadReceipt);
      return slidePage(
        state,
        OlympiadDoneScreen(olympiad: olympiad, receipt: receipt),
      );
    },
  ),
  GoRoute(
    path: GrowthV5Routes.offline,
    pageBuilder: (context, state) =>
        slidePage(state, const OfflinePackScreen()),
  ),
  GoRoute(
    path: '${GrowthV5Routes.offline}/:subject',
    pageBuilder: (context, state) => slidePage(
      state,
      OfflinePracticeScreen(subject: state.pathParameters['subject']!),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.allSubjects,
    pageBuilder: (context, state) =>
        slidePage(state, const AllSubjectsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.meLock,
    pageBuilder: (context, state) => slidePage(state, const MeLockScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.mePassword,
    pageBuilder: (context, state) => slidePage(state, const MePasswordScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.thinking,
    pageBuilder: (context, state) =>
        slidePage(state, const ThinkingResultScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kelajakInterests,
    pageBuilder: (context, state) =>
        slidePage(state, const KelajakInterestsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kelajakCareers,
    pageBuilder: (context, state) =>
        slidePage(state, const KelajakCareersScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kelajakGoal,
    pageBuilder: (context, state) => slidePage(
      state,
      KelajakWeeklyGoalScreen(
        suggested: state.extra is Subject ? state.extra! as Subject : null,
      ),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.kelajakSafety,
    pageBuilder: (context, state) =>
        slidePage(state, const KelajakSafetyListScreen()),
  ),
  GoRoute(
    path: '${GrowthV5Routes.kelajakSafety}/:lesson',
    redirect: (context, state) =>
        SafetyLesson.values.any((l) => l.name == state.pathParameters['lesson'])
        ? null
        : GrowthV5Routes.kelajakSafety,
    pageBuilder: (context, state) => slidePage(
      state,
      KelajakSafetyLessonScreen(
        lesson: SafetyLesson.values.byName(state.pathParameters['lesson']!),
      ),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.family,
    pageBuilder: (context, state) => slidePage(state, const FamilyScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.familySos,
    pageBuilder: (context, state) => slidePage(state, const SosScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.familyExtraTime,
    pageBuilder: (context, state) => slidePage(state, const ExtraTimeScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirish,
    pageBuilder: (context, state) =>
        tabPage(state, const KirishWelcomeScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishLogin,
    pageBuilder: (context, state) => slidePage(
      state,
      KirishLoginScreen(initialLogin: state.uri.queryParameters['login']),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishSetup,
    redirect: (context, state) =>
        state.extra is SetupArgs ? null : GrowthV5Routes.kirishLogin,
    pageBuilder: (context, state) =>
        slidePage(state, KirishSetupScreen(args: state.extra! as SetupArgs)),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishRecovery,
    pageBuilder: (context, state) =>
        slidePage(state, const KirishRecoveryScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishRecoveryStatus,
    // A03 chiptani `extra` bilan uzatadi (qurilmaga saqlanmagan bo'lsa ham).
    pageBuilder: (context, state) => slidePage(
      state,
      KirishRecoveryStatusScreen(
        ticket: switch (state.extra) {
          final RecoveryTicket ticket => ticket,
          _ => null,
        },
      ),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishAccounts,
    pageBuilder: (context, state) =>
        slidePage(state, const KirishAccountsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishClosed,
    pageBuilder: (context, state) => tabPage(state, const KirishClosedScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishProfile,
    pageBuilder: (context, state) =>
        slidePage(state, const KirishProfileScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishCode,
    pageBuilder: (context, state) =>
        slidePage(state, const KirishSchoolCodeScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishLocked,
    pageBuilder: (context, state) =>
        slidePage(state, const KirishLockedScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishStatus,
    pageBuilder: (context, state) =>
        slidePage(state, const KirishLinkStatusScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.kirishCorrection,
    pageBuilder: (context, state) =>
        slidePage(state, const KirishCorrectionScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.voice,
    pageBuilder: (context, state) => slidePage(state, const VoiceScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.voiceSurvey,
    pageBuilder: (context, state) =>
        slidePage(state, const VoiceSurveyIntroScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.voiceSurveyRun,
    pageBuilder: (context, state) =>
        sessionPage(state, const VoiceSurveyScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.voiceHelp,
    pageBuilder: (context, state) => slidePage(state, const VoiceHelpScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.voiceCompose,
    pageBuilder: (context, state) =>
        sessionPage(state, const VoiceComposeScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.voiceRequests,
    pageBuilder: (context, state) =>
        slidePage(state, const VoiceRequestsScreen()),
  ),
  GoRoute(
    path: '/maktab/ovoz/murojaat/:id',
    pageBuilder: (context, state) => slidePage(
      state,
      VoiceRequestScreen(requestId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/maktab/ovoz/shaxsiy/:id',
    pageBuilder: (context, state) => sessionPage(
      state,
      VoicePersonalScreen(assignmentId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.library,
    // Audio / video yashirin — kutubxona (va uning audio/video sahifalari)
    // ochilmaydi, eski havolalar O'qish markaziga tushadi.
    redirect: (_, state) =>
        isHiddenMediaRoute(state.uri.path) ? GrowthV5Routes.learn : null,
    pageBuilder: (context, state) => slidePage(state, const LibraryScreen()),
  ),
  GoRoute(
    path: '/oqish/kutubxona/audio/:id',
    redirect: (_, state) =>
        isHiddenMediaRoute(state.uri.path) ? GrowthV5Routes.learn : null,
    pageBuilder: (context, state) =>
        slidePage(state, AudiobookScreen(bookId: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/oqish/kutubxona/video/:id',
    redirect: (_, state) =>
        isHiddenMediaRoute(state.uri.path) ? GrowthV5Routes.learn : null,
    pageBuilder: (context, state) => slidePage(
      state,
      VideoLessonScreen(videoId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/oqish/kutubxona/maqola/:id',
    pageBuilder: (context, state) =>
        slidePage(state, ArticleScreen(articleId: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: GrowthV5Routes.attempts,
    pageBuilder: (context, state) => slidePage(state, const AttemptsScreen()),
  ),
  GoRoute(
    path: GrowthV5Routes.resultPattern,
    pageBuilder: (context, state) => slidePage(
      state,
      ResultDetailScreen(resultId: state.pathParameters['resultId']!),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.subjectMapPattern,
    redirect: (context, state) =>
        Subject.fromName(state.pathParameters['subject']) == null
        ? GrowthV5Routes.learn
        : null,
    pageBuilder: (context, state) => slidePage(
      state,
      TopicMapScreen(
        subject: Subject.fromName(state.pathParameters['subject'])!,
      ),
    ),
  ),
  GoRoute(
    path: GrowthV5Routes.topicPattern,
    redirect: (context, state) =>
        Subject.fromName(state.uri.queryParameters['fan']) == null
        ? GrowthV5Routes.learn
        : null,
    pageBuilder: (context, state) => slidePage(
      state,
      TopicScreen(
        subject: Subject.fromName(state.uri.queryParameters['fan'])!,
        topicId: state.pathParameters['topicId']!,
      ),
    ),
  ),
  if (kDebugMode)
    GoRoute(
      path: GrowthV5Routes.kit,
      pageBuilder: (context, state) =>
          slidePage(state, const KitGalleryScreen()),
    ),
];

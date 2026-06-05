// ─────────────────────────────────────────────────────────────────────
// FARZANDIM — ROUTER (go_router config)
// ─────────────────────────────────────────────────────────────────────
//
// Bu fayl butun ilovaning routing tizimini boshqaradi:
//   - Qaysi URL qaysi ekranga olib keladi
//   - Ekrandan ekranga qanday o'tiladi
//   - Auth state'ga qarab redirect (Bosqich 1.5'da qo'shamiz)
//
// Foydalanish (boshqa joydan):
//
//   context.go(AppRoutes.dashboard);     // ekranni almashtirish
//   context.push(AppRoutes.addChild);    // yangi ekranni stack'ga qo'shish
//   context.pop();                        // orqaga qaytish

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/app_limits_screen.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/app_restrictions_screen.dart';
import 'package:farzandim/features/auth/presentation/providers/backend_auth_provider.dart';
import 'package:farzandim/features/auth/presentation/screens/add_account_screen.dart';
import 'package:farzandim/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:farzandim/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:farzandim/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:farzandim/features/auth/presentation/screens/telegram_login_screen.dart';
import 'package:farzandim/features/auth/presentation/screens/welcome_screen.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/screens/add_child_screen.dart';
import 'package:farzandim/features/child_management/presentation/screens/children_management_screen.dart';
import 'package:farzandim/features/child_management/presentation/screens/dashboard_screen.dart';
import 'package:farzandim/features/child_management/presentation/screens/family_code_screen.dart';
import 'package:farzandim/features/geo_zones/presentation/screens/add_edit_geo_zone_screen.dart';
import 'package:farzandim/features/geo_zones/presentation/screens/geo_zones_list_screen.dart';
import 'package:farzandim/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:farzandim/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:farzandim/features/location/presentation/screens/location_history_screen.dart';
import 'package:farzandim/features/location/presentation/screens/location_map_screen.dart';
import 'package:farzandim/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:farzandim/features/profile/presentation/screens/profile_screen.dart';
import 'package:farzandim/features/quick_actions/presentation/screens/app_permissions_screen.dart';
import 'package:farzandim/features/quick_actions/presentation/screens/device_settings_screen.dart';
import 'package:farzandim/features/quick_actions/presentation/screens/permission_apps_screen.dart';
import 'package:farzandim/features/quick_actions/presentation/screens/voice_messages_screen.dart';
import 'package:farzandim/features/feedback/presentation/screens/feedback_inbox_screen.dart';
import 'package:farzandim/features/gamification/presentation/screens/leaderboard_screen.dart';
import 'package:farzandim/features/photo_request/presentation/screens/photo_requests_list_screen.dart';
import 'package:farzandim/features/schedules/presentation/screens/schedules_list_screen.dart';
import 'package:farzandim/features/sos/presentation/screens/sos_alerts_list_screen.dart';
import 'package:farzandim/features/settings/presentation/screens/about_screen.dart';
import 'package:farzandim/features/settings/presentation/screens/active_sessions_screen.dart';
import 'package:farzandim/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:farzandim/features/support/presentation/screens/support_chat_screen.dart';
import 'package:farzandim/features/settings/presentation/screens/settings_screen.dart';
import 'package:farzandim/features/pair_requests/presentation/screens/pair_requests_screen.dart';
import 'package:farzandim/features/voice_message/presentation/screens/voice_chat_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Slide right-to-left page transition — Dashboard'dan boshqa ekranga
/// ochilganda zamonaviy "drill-down" his. 250ms, easeOutCubic.
CustomTransitionPage<T> _slidePage<T>(Widget child) {
  return CustomTransitionPage<T>(
    key: ValueKey(child.runtimeType),
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Auth-protected routelar — login qilinmagan bo'lsa shu URL'lardan
/// boshqasiga kirib bo'lmaydi.
const _authRoutes = <String>[
  AppRoutes.welcome,
  AppRoutes.telegramLogin, // Telegram Login — yagona auth ekran
  AppRoutes.signIn,
  AppRoutes.signUp,
  AppRoutes.forgotPassword,
  // DIQQAT: addAccount auth route EMAS — u mas'ul (kirgan) qurilmada
  // "Faol seanslar → Boshqa hisob qo'shish" orqali QR yaratish uchun
  // ochiladi. _authRoutes'da bo'lsa, kirgan user dashboard'ga otib ketardi.
];

/// Firebase + Backend auth providerlarga listen qilib `notifyListeners`
/// chaqiradigan ChangeNotifier — `GoRouter.refreshListenable` uchun.
///
/// Har qaysi auth state o'zgarganda router redirect'ni qayta hisoblaydi
/// (login → dashboard, logout → welcome). Sprint 4.4'da Backend auth ham
/// kuzatiladi — migration paytida ikkalasi parallel ishlaydi.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(backendAuthProvider, (_, __) => notifyListeners());
  }
}

/// Firebase ishga tushirilgan bo'lsa Analytics observer qaytaradi, aks
/// holda bo'sh ro'yxat — web preview Firebase'siz ishlashi uchun.
///
/// DEV stub firebase_options bilan ishlatilganda `Firebase.apps` to'la
/// bo'lishi mumkin, lekin Analytics'ning haqiqiy API kaliti yo'q —
/// har navigatsiyada 400 Bad Request. Project ID dev-stub bo'lsa
/// observer'ni o'chirib qo'yamiz.
List<NavigatorObserver> _analyticsObservers() {
  try {
    // Web preview'da Analytics ishlatilmaydi — `FirebaseAnalytics.instance`
    // JS SDK'da dynamic-config fetch'ni triggerlaydi va web API kalit bilan
    // har navigatsiyada [400] "API key not valid" xatosi chiqadi.
    if (kIsWeb) return <NavigatorObserver>[];
    if (Firebase.apps.isEmpty) return <NavigatorObserver>[];
    final projectId = Firebase.apps.first.options.projectId;
    if (projectId.contains('dev-stub')) {
      return <NavigatorObserver>[];
    }
    return [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ];
  } catch (_) {
    // Firebase plugin mavjud emas / ishga tushmagan — observer'siz.
    return <NavigatorObserver>[];
  }
}

/// Ilovaning yagona `GoRouter` obyekti — `routerProvider` orqali olinadi.
///
/// `MaterialApp.router(routerConfig: ref.watch(routerProvider))`.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.welcome,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    // Sprint 1.5: auto screen_view event'lar Analytics'ga.
    // Firebase ishga tushirilmagan bo'lsa (web preview) — observer'siz.
    observers: _analyticsObservers(),

    // ─── Auth-protected redirect ───
    //
    // Sprint 4.4.22 cleanup: Firebase auth olib tashlandi, faqat Backend.
    redirect: (context, state) {
      final backendAuth = ref.read(backendAuthProvider);

      // Birinchi marta yuklanyapti — hech qanday redirect qilmaymiz.
      if (backendAuth is AuthUnknown) return null;

      final isLoggedIn = backendAuth is AuthAuthenticated;
      final isAuthRoute = _authRoutes.contains(state.matchedLocation);

      // Login qilinmagan + protected route → Welcome.
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.welcome;

      // Login qilingan + auth route → Dashboard.
      // Eslatma: /login-telegram'da turganida — agar login muvaffaqiyatli
      // bo'lib state Authenticated'ga o'tdi, refresh chaqirilib bu yerga
      // keladi va Dashboard'ga avtomatik o'tadi.
      if (isLoggedIn && isAuthRoute) return AppRoutes.dashboard;

      return null;
    },

    routes: buildAppRoutes(),
  );
});

/// Ilovaning barcha route'lari. `routerProvider` (real ilova) va preview
/// harness (main_preview.dart) ikkisi ham shu ro'yxatni ishlatadi — shu
/// sabab preview'da ham barcha ekranlar ochiladi (page-not-found bo'lmaydi).
List<RouteBase> buildAppRoutes() {
  return <RouteBase>[
    // Welcome ekran — auth qilmagan foydalanuvchilar uchun bosh sahifa.
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),

    // Telegram Login WebView (Sprint 4.4 — Backend auth migration).
    GoRoute(
      path: AppRoutes.telegramLogin,
      pageBuilder: (context, state) => _slidePage(const TelegramLoginScreen()),
    ),

    // Akkauntga kirish — email/telefon + parol.
    GoRoute(
      path: AppRoutes.signIn,
      pageBuilder: (context, state) => _slidePage(const SignInScreen()),
    ),

    // Ro'yxatdan o'tish — telefon/email tab + parol.
    GoRoute(
      path: AppRoutes.signUp,
      pageBuilder: (context, state) => _slidePage(const SignUpScreen()),
    ),

    // Parolni tiklash (UI stub).
    GoRoute(
      path: AppRoutes.forgotPassword,
      pageBuilder: (context, state) =>
          _slidePage(const ForgotPasswordScreen()),
    ),

    // Akkauntga qo'shilish — QR orqali boshqa qurilmaga ulanish.
    GoRoute(
      path: AppRoutes.addAccount,
      pageBuilder: (context, state) => _slidePage(const AddAccountScreen()),
    ),

    // Dashboard — auth qilgan foydalanuvchining asosiy ekrani.
    // Bosqich 2.1: faqat empty state. Bosqich 3'da to'liq dashboard.
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const DashboardScreen(),
    ),

    // Yangi bola qo'shish formasi.
    GoRoute(
      path: AppRoutes.addChild,
      pageBuilder: (context, state) => _slidePage(const AddChildScreen()),
    ),

    // Bolani tahrirlash — Bosqich 7.2.
    GoRoute(
      path: AppRoutes.editChildPattern,
      pageBuilder: (context, state) => _slidePage(
        AddChildScreen(childId: state.pathParameters['id']),
      ),
    ),

    // Oila kodi ekrani — bola qo'shilgandan keyin shu yerga keladi.
    // `state.extra` orqali yangi yaratilgan Child obyekti yuboriladi
    // (childrenProvider yangilanish race condition'ini bartaraf etish).
    GoRoute(
      path: AppRoutes.familyCodePattern,
      pageBuilder: (context, state) => _slidePage(
        FamilyCodeScreen(
          childId: state.pathParameters['childId']!,
          initialChild: state.extra is Child ? state.extra! as Child : null,
        ),
      ),
    ),

    // Bildirishnomalar — Bosqich 6.A.
    GoRoute(
      path: AppRoutes.notifications,
      pageBuilder: (context, state) => _slidePage(const NotificationsScreen()),
    ),

    // Sozlamalar — Bosqich 7.1.
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (context, state) => _slidePage(const SettingsScreen()),
    ),
    GoRoute(
      path: AppRoutes.settingsAbout,
      pageBuilder: (context, state) => _slidePage(const AboutScreen()),
    ),
    GoRoute(
      path: AppRoutes.settingsSessions,
      pageBuilder: (context, state) =>
          _slidePage(const ActiveSessionsScreen()),
    ),
    GoRoute(
      path: AppRoutes.support,
      pageBuilder: (context, state) =>
          _slidePage(const SupportChatScreen()),
    ),
    // Profil va Bolalar boshqaruvi — Bosqich 7.3 va 7.2.
    GoRoute(
      path: AppRoutes.settingsProfile,
      pageBuilder: (context, state) => _slidePage(const ProfileScreen()),
    ),
    GoRoute(
      path: AppRoutes.settingsChildren,
      pageBuilder: (context, state) =>
          _slidePage(const ChildrenManagementScreen()),
    ),
    GoRoute(
      path: AppRoutes.settingsDeleteAccount,
      pageBuilder: (context, state) => _slidePage(const DeleteAccountScreen()),
    ),
    GoRoute(
      path: AppRoutes.legalPrivacyPolicy,
      pageBuilder: (context, state) => _slidePage(const PrivacyPolicyScreen()),
    ),
    GoRoute(
      path: AppRoutes.legalTermsOfService,
      pageBuilder: (context, state) =>
          _slidePage(const TermsOfServiceScreen()),
    ),

    // Bola joylashuvi xaritada — Bosqich 4.1.
    GoRoute(
      path: AppRoutes.locationPattern,
      pageBuilder: (context, state) => _slidePage(
        LocationMapScreen(childId: state.pathParameters['childId']),
      ),
    ),

    // Bola harakat tarixi — Sprint 4 (Polyline xaritada).
    GoRoute(
      path: AppRoutes.locationHistoryPattern,
      pageBuilder: (context, state) => _slidePage(
        LocationHistoryScreen(childId: state.pathParameters['childId']!),
      ),
    ),

    // Geo-zonalar — Bosqich 4.2 + Firestore migration (per-child).
    GoRoute(
      path: AppRoutes.geoZonesPattern,
      pageBuilder: (context, state) => _slidePage(
        GeoZonesListScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.geoZonesAddPattern,
      pageBuilder: (context, state) => _slidePage(
        AddEditGeoZoneScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.geoZonesEditPattern,
      pageBuilder: (context, state) => _slidePage(
        AddEditGeoZoneScreen(
          childId: state.pathParameters['childId']!,
          zoneId: state.pathParameters['id'],
        ),
      ),
    ),

    // Quick Actions — Bosqich 5.
    GoRoute(
      path: AppRoutes.qaDevicePattern,
      pageBuilder: (context, state) => _slidePage(
        DeviceSettingsScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.appPermissionsPattern,
      pageBuilder: (context, state) => _slidePage(
        AppPermissionsScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.permissionAppsPattern,
      pageBuilder: (context, state) => _slidePage(
        PermissionAppsScreen(
          childId: state.pathParameters['childId']!,
          permission: state.pathParameters['permission']!,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.qaVoicePattern,
      pageBuilder: (context, state) => _slidePage(
        VoiceChatScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.voiceMessages,
      pageBuilder: (context, state) => _slidePage(const VoiceMessagesScreen()),
    ),
    GoRoute(
      path: AppRoutes.appRestrictionsPattern,
      pageBuilder: (context, state) => _slidePage(
        AppRestrictionsScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.appLimitsPattern,
      pageBuilder: (context, state) => _slidePage(
        AppLimitsScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.schedulesPattern,
      pageBuilder: (context, state) => _slidePage(
        SchedulesListScreen(childId: state.pathParameters['childId']!),
      ),
    ),
    GoRoute(
      // "Batafsil" → endi Reyting (leaderboard). Avval ChildAchievementsScreen
      // edi; route path o'zgarmadi (dashboard navigatsiyasi shu).
      path: AppRoutes.childAchievementsPattern,
      pageBuilder: (context, state) => _slidePage(
        LeaderboardScreen(
          childId: state.pathParameters['childId']!,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.sosAlerts,
      pageBuilder: (context, state) =>
          _slidePage(const SosAlertsListScreen()),
    ),
    GoRoute(
      path: AppRoutes.photoRequestsPattern,
      pageBuilder: (context, state) => _slidePage(
        PhotoRequestsListScreen(
          childId: state.pathParameters['childId']!,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.feedbackInboxPattern,
      pageBuilder: (context, state) => _slidePage(
        FeedbackInboxScreen(
          childId: state.pathParameters['childId']!,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.pairRequestsPattern,
      pageBuilder: (context, state) => _slidePage(
        PairRequestsScreen(
          childId: state.pathParameters['childId']!,
        ),
      ),
    ),
  ];
}

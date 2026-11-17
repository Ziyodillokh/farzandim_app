// ─────────────────────────────────────────────────────────────────────
// AppRouter — go_router konfiguratsiyasi
// ─────────────────────────────────────────────────────────────────────
//
// Initial route: /splash. SplashScreen rozilik, kirish (Growth v5) va
// ruxsatlarni tekshirib to'g'ri ekranga yo'naltiradi.
//
// Asosiy ekranlar — `buildGrowthV5Routes()` (Bugun / O'qish / Maktab / Men,
// kirish oqimi). Bu yerda faqat v5 hali ishlatadigan eski ekranlar
// (juftlash, ruxsatlar, ovozli chat, video pleyer, ...) va eski manzillardan
// v5 ekvivalentiga yo'naltirishlar (`_legacyRedirects`) qoladi.
//
// Pairing state o'zgarganda router redirect qayta ishga tushadi
// (`refreshListenable` orqali).

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/core/routing/growth_routes.dart';
import 'package:farzandim_child/core/routing/iq_routes.dart';
import 'package:farzandim_child/core/routing/kelajak_routes.dart';
import 'package:farzandim_child/core/routing/route_pages.dart';
import 'package:farzandim_child/core/routing/school_routes.dart';
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/features/consent/presentation/providers/consent_provider.dart';
import 'package:farzandim_child/features/consent/presentation/screens/consent_screen.dart';
import 'package:farzandim_child/features/account/presentation/screens/account_edit_screen.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/ios_permission_setup_screen.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/permission_setup_screen.dart';
import 'package:farzandim_child/features/screen_time/presentation/screens/screen_time_screen.dart';
import 'package:farzandim_child/features/splash/presentation/screens/splash_screen.dart';
import 'package:farzandim_child/features/don_history/presentation/screens/don_history_screen.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/screens/pair_waiting_screen.dart';
import 'package:farzandim_child/features/pairing/presentation/screens/pairing_screen.dart';
import 'package:farzandim_child/features/pairing/presentation/screens/qr_scanner_screen.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/screens/classic_video_player_screen.dart';
import 'package:farzandim_child/features/videos/presentation/screens/reels_player_screen.dart';
import 'package:farzandim_child/features/videos/presentation/screens/youtube_player_screen.dart';
import 'package:farzandim_child/features/videos/data/repositories/video_engagement_repository.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/voice_message/presentation/screens/voice_chat_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:farzandim_child/growth/common/media_visibility.dart';
import 'package:go_router/go_router.dart';

/// Eski (v4) manzillar → Growth v5 ekvivalenti. Serverdagi bildirishnoma
/// havolalari (`relatedRoute`, `deepLink`) va eski push'lar shu manzillarni
/// yuborishi mumkin — "sahifa topilmadi" o'rniga mos bo'limga tushadi.
const _legacyRedirects = <String, String>{
  '/dashboard': GrowthV5Routes.today,
  '/welcome': '/splash',
  '/onboarding': '/splash',
  '/statistics': GrowthV5Routes.meGrowth,
  '/streak-detail': GrowthV5Routes.meGrowth,
  '/steps-detail': GrowthV5Routes.meGrowth,
  '/daily-share': GrowthV5Routes.meGrowth,
  '/analytics': GrowthV5Routes.meGrowth,
  '/progress': GrowthV5Routes.meGrowth,
  '/profile': GrowthV5Routes.me,
  '/ranking': GrowthV5Routes.meLevel,
  '/settings': GrowthV5Routes.meSettings,
  '/notifications': GrowthV5Routes.notifications,
  // Audio / video yashirin: kutubxona o'rniga O'qish markazi.
  '/content': kShowAudioVideo ? GrowthV5Routes.library : GrowthV5Routes.learn,
  '/videos': kShowAudioVideo ? GrowthV5Routes.library : GrowthV5Routes.learn,
  '/audiobooks': kShowAudioVideo
      ? GrowthV5Routes.library
      : GrowthV5Routes.learn,
  '/books': kShowAudioVideo ? GrowthV5Routes.library : GrowthV5Routes.learn,
  '/articles': GrowthV5Routes.library,
  '/contests': GrowthV5Routes.olympiads,
  '/chats': GrowthV5Routes.family,
  '/schedules': GrowthV5Routes.today,
};

/// `/video-player` uchun wrapper — ochilgan videoni "Ko'rish tarixi"ga yozadi,
/// so'ng havola turiga qarab kerakli player'ni ochadi (YouTube / reels /
/// klassik landscape). Tarix markazlashtirilgan: feed, dashboard yoki content
/// hub — qayerdan ochilmasin bir joyda yoziladi.
class _VideoPlayerRoute extends ConsumerStatefulWidget {
  const _VideoPlayerRoute({required this.video});

  final VideoModel video;

  @override
  ConsumerState<_VideoPlayerRoute> createState() => _VideoPlayerRouteState();
}

class _VideoPlayerRouteState extends ConsumerState<_VideoPlayerRoute> {
  @override
  void initState() {
    super.initState();
    // Ko'rish tarixiga yozamiz (backend, fire-and-forget). build paytida
    // provider'ni o'zgartirmaslik uchun microtask'da.
    Future.microtask(
      () => ref
          .read(videoEngagementRepositoryProvider)
          .recordHistory(widget.video.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    if (video.isYouTube) {
      return YoutubePlayerScreen(video: video);
    }
    return video.isReels
        ? ReelsPlayerScreen(initialVideo: video)
        : ClassicVideoPlayerScreen(video: video);
  }
}

/// Til o'zgarishini `GoRouter.refreshListenable`'ga uzatuvchi provider.
///
/// `context.setLocale()` faqat easy_localization holatini yangilaydi; go_router
/// sahifalarni cache qiladi (Navigator GlobalKey), shuning uchun til almashganda
/// cache'langan ekran (masalan Profil badge'lari) eski tilda qolib "bir marta
/// refresh" talab qilardi. `main.dart` joriy locale'ni shu yerga yozadi →
/// refresh notifier oshadi → router sahifani yangi tilda qayta quradi.
final localeRefreshProvider = StateProvider<String>((ref) => 'uz');

final routerProvider = Provider<GoRouter>((ref) {
  // Pairing state o'zgarganida router'ni QAYTA yaratmaymiz —
  // aks holda har bir state o'zgarishi initialLocation'ga
  // ('/welcome') uloqtiradi va PairingScreen unmount bo'ladi.
  // O'rniga refreshListenable orqali redirect logikasini
  // qayta ishga tushiramiz.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen<AppPairingState>(pairingStateProvider, (_, __) => refresh.value++);
  // Ota-ona roziligi (Play talabi) o'zgarganda redirect qayta hisoblanadi —
  // rozilik berilgach router /consent'dan keyingi ekranga o'zi o'tkazadi.
  ref.listen<ConsentState>(consentStateProvider, (_, __) => refresh.value++);
  // Til almashganda cache'langan ekranlar (Profil badge'lari va h.k.) QAYTA
  // quriladi — aks holda eski tilda qolib, refresh/navigatsiya talab qilardi.
  ref.listen(localeRefreshProvider, (_, __) => refresh.value++);
  // v5: akkauntlar ro'yxati (A12 belgisi, akkaunt almashishi) o'zgarganda.
  final registry = ref.read(accountRegistryProvider);
  void onAccounts() => refresh.value++;
  registry.addListener(onAccounts);
  ref.onDispose(() => registry.removeListener(onAccounts));

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    // Noma'lum manzil (deep-link, App Link, notification, eski route) — go_router
    // default "Page Not Found" dead-end ko'rsatardi. O'rniga Splash'ni ko'rsatamiz:
    // u pairing/permission holatiga qarab to'g'ri ekranga o'zi yo'naltiradi.
    errorBuilder: (_, __) => const SplashScreen(),
    redirect: (context, state) {
      // '/' yoki bo'sh manzil — bu router'da '/' route YO'Q (initial: /splash).
      // Deep-link / OS launcher / FCM `deepLink:'/'` / eski "Page Not Found"
      // "Home" tugmasi shu yerga olib kelib "no routes for location: /"
      // dead-end'ini chiqarardi. Markaziy splash'ga yo'naltiramiz — u pairing
      // holatiga qarab to'g'ri ekranni tanlaydi (re-pair QR оqimida ham).
      final raw = state.uri.path;
      if (raw.isEmpty || raw == '/') return '/splash';

      final pairing = ref.read(pairingStateProvider);
      final isPaired = pairing.isPaired;
      final loc = state.matchedLocation;

      // Splash, til va pairing — har doim ruxsat (onboarding oqimi).
      // /welcome — til tanlash (yangi foydalanuvchi); Splash til tanlanmagan
      // va hali pair bo'lmagan holatda shu yerga yo'naltiradi.
      // /onboarding — qiziqishlar ekrani; endi faqat KOD kiritilgandan
      // (pair) keyin Splash yo'naltiradi, bir martalik.
      // /qr-scan — pairing oqimining bir qismi: bola hali pair bo'lmagan
      // holatda "QR kod orqali ulash" tugmasi shu ekranga olib boradi.
      // Agar publicPaths'da bo'lmasa, router uni darhol /pairing ga
      // qaytaradi va tugma "ishlamayotgandek" ko'rinadi (bug edi).
      final publicPaths = {
        '/splash',
        '/consent',
        '/pairing',
        '/pair-waiting',
        '/qr-scan',
        ...GrowthV5Routes.kirishPublic,
      };

      // ── Ota-ona roziligi (Google Play MAJBURIY) ────────────────────────
      // Bola ma'lumoti (joylashuv, ilova ishlatilishi) yig'ilishidan OLDIN
      // oshkor rozilik olinadi. `unknown` — SharedPreferences hali o'qilmagan
      // (boot): bu paytda YO'NALTIRMAYMIZ, aks holda splash bilan raqobat
      // qilib "sakrash" bo'ladi. Til tanlash (/welcome) rozilikdan oldin
      // ochiq — foydalanuvchi matnni o'z tilida o'qiy olishi uchun.
      final consent = ref.read(consentStateProvider);
      final preConsentPaths = {
        '/splash',
        '/consent',
        // A01 — til tanlash rozilikdan oldin (matnni o'z tilida o'qish).
        GrowthV5Routes.kirish,
      };
      if (consent == ConsentState.notGiven && !preConsentPaths.contains(loc)) {
        return '/consent';
      }
      // Rozilik bor, lekin foydalanuvchi /consent'da qolib ketgan → splash
      // to'g'ri ekranni tanlaydi.
      if (consent == ConsentState.given && loc == '/consent') {
        return '/splash';
      }

      // Kirilmagan va himoyalangan ekran → kirish (A01; sessiya yopilgan
      // bo'lsa A12).
      if (!isPaired && !publicPaths.contains(loc)) {
        final closed =
            pairing.isSessionEnded ||
            ref.read(accountRegistryProvider).closedNotice != null;
        return closed ? GrowthV5Routes.kirishClosed : GrowthV5Routes.kirish;
      }

      // Pairing endigina tugadi (kullanici hali /pairing'da).
      // Splash permission'larni tekshirib to'g'ri ekranga yo'naltiradi.
      if (isPaired && loc == '/pairing') {
        return '/splash';
      }

      // Ekran vaqti (Family Controls) — faqat iOS.
      if (!PlatformCapabilities.isIOS && loc == '/screen-time') {
        return GrowthV5Routes.today;
      }

      return null;
    },
    routes: [
      ...buildGrowthV5Routes(),
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      // Ota-ona roziligi (Google Play talabi) — ma'lumot yig'ishdan oldin.
      GoRoute(path: '/consent', builder: (_, __) => const ConsentScreen()),
      GoRoute(path: '/pairing', builder: (_, __) => const PairingScreen()),
      GoRoute(
        path: '/pair-waiting',
        builder: (_, __) => const PairWaitingScreen(),
      ),
      // QR kod orqali qayta ulanish — pairing_screen'dan ochiladi.
      GoRoute(path: '/qr-scan', builder: (_, __) => const QrScannerScreen()),
      for (final MapEntry(key: from, value: to) in _legacyRedirects.entries)
        GoRoute(path: from, redirect: (_, __) => to),
      // Yosh/sinfni tuzatish (Kelajak va IQ ekranlaridan).
      GoRoute(
        path: '/account-edit',
        pageBuilder: (context, state) =>
            slidePage(state, const AccountEditScreen()),
      ),
      GoRoute(
        path: '/video-player',
        redirect: (_, state) =>
            isHiddenMediaRoute(state.uri.path) ? GrowthV5Routes.learn : null,
        builder: (context, state) =>
            _VideoPlayerRoute(video: state.extra! as VideoModel),
      ),
      ...growthRoutes,
      ...schoolRoutes,
      ...kelajakRoutes,
      ...iqRoutes,
      GoRoute(
        path: '/don-history',
        pageBuilder: (context, state) =>
            slidePage(state, const DonHistoryScreen()),
      ),
      GoRoute(
        path: '/voice-chat',
        pageBuilder: (context, state) =>
            slidePage(state, const VoiceChatScreen()),
      ),
      GoRoute(
        path: '/screen-time',
        pageBuilder: (context, state) =>
            slidePage(state, const ScreenTimeScreen()),
      ),
      GoRoute(
        path: '/permission-setup',
        builder: (_, __) => PlatformCapabilities.isIOS
            ? const IosPermissionSetupScreen()
            : const PermissionSetupScreen(),
      ),
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────
// AppRouter — go_router konfiguratsiyasi
// ─────────────────────────────────────────────────────────────────────
//
// Initial route: /splash. SplashScreen consent+til+pairing+permissions
// tekshirib to'g'ri ekranga yo'naltiradi.
//
// Asosiy ekranlar:
//   /splash           — startup tekshiruvi
//   /welcome          — til tanlash (yangi foydalanuvchi birinchi ekrani)
//   /pairing          — 5 raqamli kod kiritish
//   /permissions      — runtime perms (location/notification/camera)
//   /permission-setup — sistema-darajadagi 4 ta perm
//   /dashboard        — paired + barcha permissions yoqilgach
//
// Redirect mantiqi:
//   - Pair bo'lmagan + himoyalangan ekran → /pairing
//   - Pair bo'lgan + /welcome|/pairing'da → /splash (re-route)
//
// Pairing state o'zgarganda router redirect qayta ishga tushadi
// (`refreshListenable` orqali).

import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/features/account/presentation/screens/account_edit_screen.dart';
import 'package:farzandim_child/features/consent/presentation/providers/consent_provider.dart';
import 'package:farzandim_child/features/consent/presentation/screens/consent_screen.dart';
import 'package:farzandim_child/features/settings/presentation/screens/settings_screen.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/permission_setup_screen.dart';
import 'package:farzandim_child/features/splash/presentation/screens/splash_screen.dart';
import 'package:farzandim_child/features/statistics/presentation/screens/statistics_screen.dart';
import 'package:farzandim_child/features/audiobooks/data/models/audiobook_model.dart';
import 'package:farzandim_child/features/audiobooks/presentation/screens/audiobook_detail_screen.dart';
import 'package:farzandim_child/features/audiobooks/presentation/screens/audio_player_screen.dart';
import 'package:farzandim_child/features/articles/data/models/article_model.dart';
import 'package:farzandim_child/features/articles/presentation/screens/article_view_screen.dart';
import 'package:farzandim_child/features/articles/presentation/screens/articles_feed_screen.dart';
import 'package:farzandim_child/features/contests/data/repositories/certificate_repository.dart';
import 'package:farzandim_child/features/contests/presentation/screens/certificate_screen.dart';
import 'package:farzandim_child/features/books/data/models/book_model.dart';
import 'package:farzandim_child/features/books/presentation/screens/books_feed_screen.dart';
import 'package:farzandim_child/features/books/presentation/screens/pdf_viewer_screen.dart';
import 'package:farzandim_child/features/gamification/presentation/screens/profile_screen.dart';
import 'package:farzandim_child/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:farzandim_child/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:farzandim_child/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:farzandim_child/features/audiobooks/presentation/screens/audiobooks_feed_screen.dart';
import 'package:farzandim_child/features/content/presentation/screens/content_hub_screen.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:farzandim_child/features/contests/presentation/screens/contest_quiz_screen.dart';
import 'package:farzandim_child/features/contests/presentation/screens/contest_start_screen.dart';
import 'package:farzandim_child/features/contests/presentation/screens/contests_screen.dart';
import 'package:farzandim_child/features/contests/presentation/screens/liked_tests_screen.dart';
import 'package:farzandim_child/features/ranking/presentation/screens/ranking_screen.dart';
import 'package:farzandim_child/features/schedules/presentation/screens/schedules_screen.dart';
import 'package:farzandim_child/features/dashboard/presentation/screens/child_dashboard_screen.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/screens/pair_waiting_screen.dart';
import 'package:farzandim_child/features/pairing/presentation/screens/pairing_screen.dart';
import 'package:farzandim_child/features/pairing/presentation/screens/qr_scanner_screen.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/permissions_screen.dart';
import 'package:farzandim_child/features/videos/data/models/video_model.dart';
import 'package:farzandim_child/features/videos/presentation/screens/classic_video_player_screen.dart';
import 'package:farzandim_child/features/videos/presentation/screens/reels_player_screen.dart';
import 'package:farzandim_child/features/videos/presentation/screens/youtube_player_screen.dart';
import 'package:farzandim_child/features/videos/presentation/screens/videos_feed_screen.dart';
import 'package:farzandim_child/features/videos/presentation/screens/video_engagement_screens.dart';
import 'package:farzandim_child/features/videos/data/repositories/video_engagement_repository.dart';
import 'package:farzandim_child/features/video_message/presentation/screens/video_preview_screen.dart';
import 'package:farzandim_child/features/video_message/presentation/screens/video_recording_screen.dart';
import 'package:farzandim_child/features/pairing/data/models/pairing_state.dart';
import 'package:farzandim_child/features/voice_message/presentation/screens/voice_chat_screen.dart';
import 'package:farzandim_child/features/onboarding/presentation/screens/language_select_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Slide right-to-left page transition — Dashboard'dan boshqa ekranga
/// ochilganda zamonaviy "drill-down" his. 250ms, easeOutCubic.
CustomTransitionPage<T> _slidePage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    // go_router'ning noyob pageKey'i — bir xil ekran stack'da takror
    // bo'lsa ham kalitlar to'qnashmaydi (duplicate page key crash fix).
    key: state.pageKey,
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

final routerProvider = Provider<GoRouter>((ref) {
  // Pairing state o'zgarganida router'ni QAYTA yaratmaymiz —
  // aks holda har bir state o'zgarishi initialLocation'ga
  // ('/welcome') uloqtiradi va PairingScreen unmount bo'ladi.
  // O'rniga refreshListenable orqali redirect logikasini
  // qayta ishga tushiramiz.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen<AppPairingState>(pairingStateProvider, (_, __) => refresh.value++);
  // Parent Consent state (Store compliance) — rozilik berilgach
  // router avtomatik /consent dan /splash ga o'tkazadi.
  ref.listen<ConsentState>(consentStateProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final pairing = ref.read(pairingStateProvider);
      final consent = ref.read(consentStateProvider);
      final isPaired = pairing.isPaired;
      final loc = state.matchedLocation;

      // ── Parent Consent guard (App Store / Play Store compliance) ──
      // Rozilik holati hali SharedPreferences'dan o'qilmagan bo'lsa
      // (`unknown`) — splash'da kutamiz, redirect qilmaymiz.
      // Rozilik berilmagan bo'lsa — barcha boshqa marshrutlarni
      // /consent ga yo'naltiramiz (/splash dan tashqari, u tekshiruvni
      // bajaradi va o'zi /consent ga yo'naltiradi).
      if (consent == ConsentState.notGiven &&
          loc != '/consent' &&
          loc != '/splash') {
        return '/consent';
      }
      // Rozilik berilgach foydalanuvchi hali /consent da bo'lsa —
      // /splash ga qaytarib pairing/permission tekshiruvini ishga tushir.
      if (consent == ConsentState.given && loc == '/consent') {
        return '/splash';
      }

      // Splash, til va pairing — har doim ruxsat (onboarding oqimi).
      // /welcome — til tanlash (yangi foydalanuvchi); Splash til tanlanmagan
      // va hali pair bo'lmagan holatda shu yerga yo'naltiradi.
      // /onboarding — qiziqishlar ekrani; endi faqat KOD kiritilgandan
      // (pair) keyin Splash yo'naltiradi, bir martalik.
      // /qr-scan — pairing oqimining bir qismi: bola hali pair bo'lmagan
      // holatda "QR kod orqali ulash" tugmasi shu ekranga olib boradi.
      // Agar publicPaths'da bo'lmasa, router uni darhol /pairing ga
      // qaytaradi va tugma "ishlamayotgandek" ko'rinadi (bug edi).
      const publicPaths = {
        '/splash',
        '/pairing',
        '/pair-waiting',
        '/qr-scan',
        '/consent',
        '/onboarding',
        '/welcome',
      };

      // Pairing yo'q va himoyalangan ekran → /pairing
      if (!isPaired && !publicPaths.contains(loc)) {
        return '/pairing';
      }

      // Pairing endigina tugadi (kullanici hali /pairing'da).
      // Splash permission'larni tekshirib to'g'ri ekranga yo'naltiradi.
      if (isPaired && loc == '/pairing') {
        return '/splash';
      }

      // Pair bo'lgan foydalanuvchi til sahifasiga (deep-link) tushsa — splash'ga.
      if (isPaired && loc == '/welcome') {
        return '/splash';
      }

      // Content library (audiokitoblar/videolar/konkurslar/reyting/analytics)
      // hozircha mock data — `kEnableContentLibrary` `false` paytda
      // /dashboard'ga qaytariladi (deep-link himoyasi).
      if (!kEnableContentLibrary) {
        const contentPaths = {
          '/analytics',
          '/videos',
          '/video-player',
          '/watch-history',
          '/liked-videos',
          '/audiobooks',
          '/audiobook-detail',
          '/audio-player',
          '/contests',
          '/contest-start',
          '/contest-quiz',
          '/liked-tests',
          '/ranking',
        };
        if (contentPaths.contains(loc)) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      // Parent Consent — birinchi ochilishda ko'rsatiladi (Store compliance).
      // SharedPreferences `parent_consent_v1 = true` saqlangach ko'rsatilmaydi.
      GoRoute(path: '/consent', builder: (_, __) => const ConsentScreen()),
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const LanguageSelectScreen(),
      ),
      // 3 ta slaydli onboarding — birinchi ochilishda Splash yo'naltiradi.
      // SharedPreferences `onboarding_seen_v1` tugagach qayta ko'rsatilmaydi.
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/pairing', builder: (_, __) => const PairingScreen()),
      GoRoute(
        path: '/pair-waiting',
        builder: (_, __) => const PairWaitingScreen(),
      ),
      // QR kod orqali qayta ulanish — pairing_screen'dan ochiladi.
      GoRoute(path: '/qr-scan', builder: (_, __) => const QrScannerScreen()),
      GoRoute(
        path: '/permissions',
        builder: (_, __) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const ChildDashboardScreen(),
      ),
      GoRoute(
        path: '/account-edit',
        pageBuilder: (context, state) =>
            _slidePage(state, const AccountEditScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _slidePage(state, const SettingsScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _slidePage(state, const ProfileScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _slidePage(state, const NotificationsScreen()),
      ),
      // Sprint 4.4.40: "Hammasini ko'rish" tugmasi tap → bola statistika
      // ekrani (Date navigator + ScreenTimeChart + barcha ilovalar).
      GoRoute(
        path: '/analytics',
        pageBuilder: (context, state) =>
            _slidePage(state, const AnalyticsScreen()),
      ),
      // Dashboard'dagi stat chiplar (streak/qadam/DON) → Statistika sahifasi.
      GoRoute(
        path: '/statistics',
        pageBuilder: (context, state) =>
            _slidePage(state, const StatisticsScreen()),
      ),
      GoRoute(
        path: '/videos',
        pageBuilder: (context, state) =>
            _slidePage(state, const VideosFeedScreen()),
      ),
      GoRoute(
        path: '/video-player',
        builder: (context, state) =>
            _VideoPlayerRoute(video: state.extra! as VideoModel),
      ),
      GoRoute(
        path: '/watch-history',
        pageBuilder: (context, state) =>
            _slidePage(state, const WatchHistoryScreen()),
      ),
      GoRoute(
        path: '/liked-videos',
        pageBuilder: (context, state) =>
            _slidePage(state, const LikedVideosScreen()),
      ),
      GoRoute(
        path: '/audiobooks',
        pageBuilder: (context, state) =>
            _slidePage(state, const AudiobooksFeedScreen()),
      ),
      // Content hub — audiokitoblar + kitoblar + konkurslar bitta ekranda.
      // Bottom nav endi shu yagona tabga olib boradi (avval 2 ta alohida edi).
      GoRoute(
        path: '/content',
        pageBuilder: (context, state) =>
            _slidePage(state, const ContentHubScreen()),
      ),
      GoRoute(
        path: '/audiobook-detail',
        pageBuilder: (context, state) => _slidePage(
          state,
          AudiobookDetailScreen(book: state.extra! as AudiobookModel),
        ),
      ),
      GoRoute(
        path: '/audio-player',
        pageBuilder: (context, state) =>
            _slidePage(state, const AudioPlayerScreen()),
      ),
      // Sprint 5.x — Books feature
      GoRoute(
        path: '/books',
        pageBuilder: (context, state) =>
            _slidePage(state, const BooksFeedScreen()),
      ),
      GoRoute(
        path: '/books/pdf',
        builder: (context, state) {
          final book = state.extra as BookModel;
          return PdfViewerScreen(book: book);
        },
      ),
      // #48 — Maqolalar (foydali bilimlar)
      GoRoute(
        path: '/articles',
        pageBuilder: (context, state) =>
            _slidePage(state, const ArticlesFeedScreen()),
      ),
      GoRoute(
        path: '/articles/view',
        builder: (context, state) {
          final article = state.extra as ArticleModel;
          return ArticleViewScreen(article: article);
        },
      ),
      GoRoute(
        path: '/contests',
        pageBuilder: (context, state) =>
            _slidePage(state, const ContestsScreen()),
      ),
      GoRoute(
        path: '/liked-tests',
        pageBuilder: (context, state) =>
            _slidePage(state, const LikedTestsScreen()),
      ),
      // #56 — Sertifikat (g'olib uchun)
      GoRoute(
        path: '/certificate',
        builder: (context, state) {
          final data = state.extra as CertificateData;
          return CertificateScreen(data: data);
        },
      ),
      GoRoute(
        path: '/contest-start',
        builder: (context, state) {
          final contest = state.extra as ContestModel;
          return ContestStartScreen(contest: contest);
        },
      ),
      GoRoute(
        path: '/contest-quiz',
        builder: (context, state) {
          final contest = state.extra as ContestModel;
          return ContestQuizScreen(contest: contest);
        },
      ),
      GoRoute(
        path: '/ranking',
        pageBuilder: (context, state) =>
            _slidePage(state, const RankingScreen()),
      ),
      GoRoute(
        path: '/video-recording',
        builder: (context, state) {
          // Banner query param orqali yuboradi; test tugmasi extra orqali.
          final requestId =
              state.uri.queryParameters['requestId'] ??
              (state.extra as String?);
          return VideoRecordingScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/video-preview',
        builder: (context, state) {
          final args = state.extra as VideoPreviewArgs;
          return VideoPreviewScreen(args: args);
        },
      ),
      GoRoute(
        path: '/voice-chat',
        pageBuilder: (context, state) =>
            _slidePage(state, const VoiceChatScreen()),
      ),
      GoRoute(
        path: '/schedules',
        pageBuilder: (context, state) =>
            _slidePage(state, const SchedulesScreen()),
      ),
      GoRoute(
        path: '/permission-setup',
        builder: (_, __) => const PermissionSetupScreen(),
      ),
    ],
  );
});

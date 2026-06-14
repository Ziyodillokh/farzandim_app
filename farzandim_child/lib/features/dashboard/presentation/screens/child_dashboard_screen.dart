// ─────────────────────────────────────────────────────────────────────
// ChildDashboardScreen — bola Dashboard'i (Bosqich 8.B)
// ─────────────────────────────────────────────────────────────────────
//
// PDF dizayni asosida qurilgan to'liq Dashboard. Real ma'lumotlar:
//   - Welcome banner (childName SharedPreferences/state'dan)
//   - Family card (parent displayName/email)
//   - Status grid (region, batareya, Wi-Fi — DeviceInfoService → Firestore)
//
// Mock ishlatilmaydi — Child Agent talab qiladigan diagnostika va
// ilovalar bo'limlari "Tez orada" placeholder'lar bilan ko'rsatiladi.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/feature_flags.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:farzandim_child/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim_child/features/analytics/presentation/widgets/app_restrictions_list.dart';
import 'package:farzandim_child/features/audiobooks/presentation/providers/audiobooks_providers.dart';
import 'package:farzandim_child/features/videos/presentation/providers/videos_providers.dart';
import 'package:farzandim_child/features/videos/presentation/widgets/video_section.dart';
import 'package:farzandim_child/features/analytics/presentation/widgets/app_usage_list.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/widgets/safe_internet_setup_card.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_stat_panel.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/family_card.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/motivational_banner.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/schedule_mini_card.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/section_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/sos_button.dart';
import 'package:farzandim_child/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:farzandim_child/shared/widgets/skeleton_card.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() =>
      _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_guardPermissions);
    Future.microtask(_updateStreak);

    // Sprint 4.4.38: analytics provider'lar har 30 sek invalidate
    // qilinadi — real-time hissi (Backend usage 2 daq interval bilan
    // kelganidan keyin darhol UI'da ko'rinadi).
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshAnalytics(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App foreground'ga qaytganda darhol refresh — eng so'nggi sync
    // natijasini ko'rsatish.
    if (state == AppLifecycleState.resumed) {
      _refreshAnalytics();
    }
  }

  void _refreshAnalytics() {
    if (!mounted) return;
    // installedAppsMap bu yerda invalidate qilinmaydi — ikonkalar
    // o'zgarmaydi, har 30s'da base64-ikonli og'ir ro'yxat tortilardi
    ref
      ..invalidate(dailyUsageProvider)
      ..invalidate(weeklyUsageProvider)
      ..invalidate(childAppLimitsProvider);
    final pairing = ref.read(pairingStateProvider);
    final childId = pairing.childId;
    if (childId != null) {
      ref
        ..invalidate(childAvatarUrlProvider(childId))
        ..invalidate(childDataStreamProvider((
          parentUid: pairing.parentUid!,
          childId: childId,
        )));
    }
  }

  /// Kun boshida Dashboard ochilganda streak'ni yangilash.
  /// Konsept v2 4.2: haftalik streak (>=7) bonus XP olib keladi —
  /// lekin bonus alohida joyga ulansa bo'ladi (hozircha faqat
  /// streak counter yangilanadi).
  Future<void> _updateStreak() async {
    final pairing = ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid == null || childId == null) return;

    try {
      await ref.read(xpServiceProvider).updateStreakOnDailyOpen(
            parentUid: parentUid,
            childId: childId,
          );
    } catch (e) {
      // Stream-driven UI o'zi qayta yangilanadi — fail mute.
    }
  }

  /// Foydalanuvchi qaysidir yo'l bilan permission'siz Dashboard'ga
  /// tushib qolsa (sistema sozlamalardan o'chirilgan, eski deep-link),
  /// /permission-setup ga qaytaramiz. Splash bilan bir xil 4 ta perm.
  ///
  /// Web'da `locationAlways`, `ignoreBatteryOptimizations`, usage stats
  /// va overlay permission'lar mavjud emas — `permission_handler_html`
  /// "not implemented" xato qaytaradi. Web faqat sinash/preview rejimi,
  /// shuning uchun tekshiruvni o'tkazib yuboramiz.
  Future<void> _guardPermissions() async {
    if (kIsWeb) return;

    final usageService = UsageStatsService();
    final locStatus = await Permission.locationAlways.status;
    final batteryStatus =
        await Permission.ignoreBatteryOptimizations.status;
    final usageGranted = await usageService.hasPermission();
    final overlayGranted = await usageService.hasOverlayPermission();

    final allGranted = locStatus.isGranted &&
        batteryStatus.isGranted &&
        usageGranted &&
        overlayGranted;

    if (!allGranted && mounted) {
      context.go('/permission-setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingStateProvider);

    if (!pairing.isPaired ||
        pairing.parentUid == null ||
        pairing.childId == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final childData = ref.watch(childDataStreamProvider((
      parentUid: pairing.parentUid!,
      childId: pairing.childId!,
    )));

    final parentInfo = ref.watch(parentInfoProvider(pairing.parentUid!));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: childData.when(
            data: (data) => _buildDashboard(
              context,
              ref,
              pairing.childId!,
              data,
              parentInfo,
            ),
            // Skeleton: dashboard kartochkalar shakli
            loading: () => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  // Top header skeleton
                  Row(
                    children: [
                      SkeletonAvatar(size: 40),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 16)),
                      SizedBox(width: 12),
                      SkeletonBox(width: 40, height: 40),
                    ],
                  ),
                  SizedBox(height: 24),
                  SkeletonCard(height: 120),
                  SizedBox(height: 12),
                  SkeletonCard(height: 88),
                  SizedBox(height: 12),
                  SkeletonCard(height: 88),
                  SizedBox(height: 12),
                  SkeletonCard(height: 100),
                ],
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'common.errorPrefix'.tr(namedArgs: {'error': '$e'}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const ChildBottomNavigation(),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    String childId,
    Map<String, dynamic>? childData,
    AsyncValue<Map<String, dynamic>?> parentInfo,
  ) {
    // Bell'ga unread badge — notifications provider'dan o'qiymiz.
    // valueOrNull — Firestore permission-denied bo'lsa ham crash qilmaslik.
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        _refreshAnalytics();
        // Provider invalidate'lardan keyin yangi data kelishi uchun
        // qisqa kutish — UI refresh indicator spin'i ko'rinadi.
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardTopHeader(
            unreadCount: unreadCount,
            onNotificationsTap: () => context.push('/notifications'),
            onSettingsTap: () => context.push('/settings'),
            // Dashboard'da SOS pill kerak emas — pastda alohida katta
            // SosButton bor (3-sek hold-to-send). Yuqorida dublikat
            // bo'lmasligi uchun yashiramiz.
            showSos: false,
          ),
          // Logo tagidagi 3 kartali xulosa — XP / Level / Viloyat reytingi.
          const SizedBox(height: 8),
          const DashboardStatPanel(),
          // Sprint 4.4.28: yangi versiya mavjud bo'lsa banner (dismissable).
          UpdateBanner(),
          const SizedBox(height: 16),
          // Xavfsiz internet yoqilgan, lekin xavfsiz DNS sozlanmagan bo'lsa
          // tavsiya kartasi (faqat Android; aks holda o'zi yashirinadi).
          const SafeInternetSetupCard(),
          // === 📺 Videolar playlist (yuqorida) ===
          // Foydalanuvchi talabiga ko'ra videolar "Mening oilam"dan oldin,
          // tezroq ko'rinadigan joyga ko'chirildi.
          if (kEnableContentLibrary) ...[
            const _DashboardVideosSection(),
            const SizedBox(height: 16),
          ],
          // === Jadval mini-card (real Firestore data) ===
          ScheduleMiniCard(
            onTap: () => context.push('/schedules'),
          ),
          const SizedBox(height: 16),
          // === Oilam ===
          FamilyCard(parentInfo: parentInfo),
          const SizedBox(height: 16),
          const MotivationalBanner(),
          const SizedBox(height: 24),
          // === 🎵 Audiokitoblar mini-player (Ilovadan foydalanish'dan oldin) ===
          // Spotify-style compact player: cover + title + author + play.
          if (kEnableContentLibrary) ...[
            const _DashboardAudiobookMiniPlayer(),
            const SizedBox(height: 20),
          ],
          // === 📊 Ilovadan foydalanish (eng pastda — foydalanuvchi talabi) ===
          if (kEnableContentLibrary) ...[
            SectionHeader(
              title: 'dashboard.appUsageTitle'.tr(),
              icon: Icons.apps_rounded,
              iconColor: const Color(0xFF7C5CFF),
            ),
            const SizedBox(height: 8),
            const AppUsageList(limit: 5),
            const SizedBox(height: 8),
            _AppUsageSeeAllButton(
              onTap: () => context.push('/analytics'),
            ),
            const SizedBox(height: 24),
            // Sprint 4.4.33: Parent qo'ygan cheklovlar (block + limit).
            const AppRestrictionsList(),
            const SizedBox(height: 24),
          ],
          // === SOS (eng pastda, har doim mavjud) ===
          const SosButton(),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}

// ─── Videolar playlist (audiokitoblar o'rniga yuqoriga ko'chirildi) ────
class _DashboardVideosSection extends ConsumerWidget {
  const _DashboardVideosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(topVideosProvider);
    // Yoshga mos video yo'q bo'lsa seksiyani umuman ko'rsatmaymiz —
    // soxta mock o'rniga (mock yosh filtridan o'tmaydi).
    if (videos.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.push('/content'),
      behavior: HitTestBehavior.opaque,
      child: VideoSection(
        title: 'Videolar',
        videos: videos,
        leadingIcon: Icons.smart_display_rounded,
        leadingIconColor: const Color(0xFFE53935), // YouTube red
        onViewAll: () => context.push('/content'),
      ),
    );
  }
}

// ─── Audiokitoblar mini-player (Ilovadan foydalanish'dan oldin) ────────
// Spotify-style compact card: cover + title + author + play tugma.
// Tap'da Audiokitoblar tabi (Content hub) ochiladi. 1-2 ta kitobni
// gorizontal stack ko'rinishida ko'rsatadi (eng yangi yoki tanlangan).
class _DashboardAudiobookMiniPlayer extends ConsumerWidget {
  const _DashboardAudiobookMiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(forYouAudiobooksProvider);
    // Yoshga mos audiokitob yo'q bo'lsa seksiyani ko'rsatmaymiz.
    if (books.isEmpty) return const SizedBox.shrink();
    final featured = books.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.headphones_rounded,
                      size: 16,
                      color: Color(0xFF169E45),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Audiokitoblar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.adaptive.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/content'),
                child: const Text(
                  'Barchasi',
                  style: TextStyle(color: AppColors.primary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.push('/content'),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1DB954), Color(0xFF169E45)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x441DB954),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cover (album art).
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: Colors.white24,
                    child: featured.coverUrl.isNotEmpty
                        ? Image.network(
                            featured.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.headphones,
                              color: Colors.white,
                              size: 32,
                            ),
                          )
                        : const Icon(
                            Icons.headphones,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + author.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        featured.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        featured.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Compact progress placeholder (full = unlistened).
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          height: 3,
                          color: Colors.white24,
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: 0.0,
                              child: SizedBox(height: 3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Play button.
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF169E45),
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashboard "Ilovadan foydalanish" bo'limi pastida — `/analytics`
/// ekraniga olib boradi (hammasi + haftalik chart).
class _AppUsageSeeAllButton extends ConsumerWidget {
  const _AppUsageSeeAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(dailyUsageProvider);
    final total = usageAsync.valueOrNull?.apps.length ?? 0;
    if (total <= 5) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Hammasini ko\'rish ($total)',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  AppIcons.forward,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

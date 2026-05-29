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
import 'package:farzandim_child/features/analytics/presentation/widgets/app_usage_list.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/child_bottom_navigation.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/dashboard_top_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/family_card.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/motivational_banner.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/schedule_mini_card.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/section_header.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/sos_button.dart';
import 'package:farzandim_child/features/voice_message/presentation/widgets/voice_messages_quick_card.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:farzandim_child/shared/widgets/skeleton_card.dart';
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
    ref
      ..invalidate(dailyUsageProvider)
      ..invalidate(weeklyUsageProvider)
      ..invalidate(childAppLimitsProvider)
      ..invalidate(installedAppsMapProvider);
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
  Future<void> _guardPermissions() async {
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
    // Sprint 4.4.29: bola rasmi (Parent App'dan yuklangan) header avatar'da.
    final avatarUrlAsync = ref.watch(childAvatarUrlProvider(childId));
    final avatarUrl = avatarUrlAsync.valueOrNull;

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
            photoUrl: avatarUrl,
            onAvatarTap: () => context.push('/account-edit'),
            onSettingsTap: () => context.push('/settings'),
          ),
          // Sprint 4.4.28: yangi versiya mavjud bo'lsa banner (dismissable).
          UpdateBanner(),
          const SizedBox(height: 16),
          // Sprint 4.4.30: TodaySummaryChips, PhotoRequestBanner,
          // VideoRequestBanner, LastVideoStatusIndicator olib tashlandi —
          // UX soddalashtirish (foydalanuvchi talabi).
          VoiceMessagesQuickCard(childId: childId),
          const SizedBox(height: 16),
          // === 📊 Ilovadan foydalanish (content library) ===
          // ScreenTimeChart Parent App dashboard'iga ko'chirildi —
          // bola tomonida unga kerak emas (parent monitoring vositasi).
          if (kEnableContentLibrary) ...[
            SectionHeader(
              title: 'dashboard.appUsageTitle'.tr(),
              icon: Icons.apps,
            ),
            const SizedBox(height: 8),
            // Sprint 4.4.40: Dashboard'da TOP 5 ilova (foydalanish vaqti
            // DESC). Hammasi /analytics ekranida ko'rinadi.
            const AppUsageList(limit: 5),
            const SizedBox(height: 8),
            _AppUsageSeeAllButton(
              onTap: () => context.push('/analytics'),
            ),
            const SizedBox(height: 24),
            // Sprint 4.4.33: Parent qo'ygan cheklovlar (block + limit).
            const AppRestrictionsList(),
            const SizedBox(height: 16),
          ],
          // === Jadval mini-card (real Firestore data) ===
          ScheduleMiniCard(
            onTap: () => context.push('/schedules'),
          ),
          const SizedBox(height: 16),
          // Sprint 4.4.35: Feedback emoji card butunlay olib tashlandi.
          // === Oilam ===
          // Sprint 4.4.30: StatusCardsGrid (2×2) olib tashlandi —
          // UX soddalashtirish.
          FamilyCard(parentInfo: parentInfo),
          const SizedBox(height: 16),
          const MotivationalBanner(),
          const SizedBox(height: 24),
          // === SOS (eng pastda, har doim mavjud) ===
          const SosButton(),
          const SizedBox(height: 24),
        ],
      ),
      ),
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

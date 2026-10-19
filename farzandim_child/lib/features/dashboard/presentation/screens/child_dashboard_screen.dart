// ─────────────────────────────────────────────────────────────────────
// ChildDashboardScreen — "Asosiy" (Growth yangi konsepsiyasi, maket 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Tartib (yuqoridan pastga):
//   • Header: "Asosiy" + chat + bildirishnoma
//   • 3 stat karta: ketma-ket kunlar · yechilgan savollar · DON balans
//   • "Bugungi testlar" — kunlik reja (fanlar × savollar) + "Boshlash"
//   • "So‘nggi natijalar" — o'rtacha natija, kuchli fan, tavsiya
//   • "Kutubxona" — video darslar va audiokitoblar lentasi
//
// Bo'limlar `widgets/home/` ichida (`HomeFeed`). Bu ekran — fon
// vazifalari (ruxsatlar, GPS, streak, qadamlar, avto-yangilash) va
// aylantirish/yangilash qobig'i.

import 'dart:async';

import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/app_restrictions/data/repositories/backend_device_policy_repository.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/uninstall_protection_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/unlock_request_provider.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/app_update/presentation/widgets/update_banner.dart';
import 'package:farzandim_child/features/contests/presentation/providers/contests_providers.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_feed.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:farzandim_child/features/location/presentation/widgets/location_enable_modal.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/features/screen_time/data/screen_time_channel.dart';
import 'package:farzandim_child/features/screen_time/presentation/providers/screen_time_providers.dart';
import 'package:farzandim_child/features/screen_time/presentation/widgets/ios_setup_banner.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bola bosh ekrani — "Asosiy".
class ChildDashboardScreen extends ConsumerStatefulWidget {
  /// `ChildDashboardScreen` konstruktor.
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() =>
      _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  /// Device Admin dialogi shu sessiyada ko'rsatildimi — resume'da qayta-qayta
  /// chiqib bezovta qilmasligi uchun (bola dialogni rad etsa ham).
  bool _promptedThisSession = false;

  /// GPS "yoqing" modali shu sessiyada ko'rsatildimi (spam bo'lmasin —
  /// xizmat yoqilgach `false`ga qaytadi, keyingi o'chishda yana so'raladi).
  bool _locationModalShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_guardPermissions);
    Future.microtask(_guardLocationService);
    Future.microtask(_updateStreak);
    // Qadamni ochilishda darhol yangilaymiz (telefon soniga yaqin bo'lsin).
    Future.microtask(() {
      final stepSvc = ref.read(stepCounterServiceProvider);
      if (stepSvc != null) unawaited(stepSvc.syncNow());
    });
    // "O'chirishni taqiqlash" — app ochilganda siyosatni qo'llaymiz (kerak
    // bo'lsa Device Admin dialogini ko'rsatamiz — foreground shart).
    Future.microtask(() => _syncUninstallProtection(allowPrompt: true));
    Future.microtask(_checkPendingTimeRequest);
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refresh(),
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
    if (state == AppLifecycleState.resumed) {
      _refresh();
      // Bola Sozlamadan GPS'ni yoqib qaytgan bo'lishi mumkin — qayta tekshiramiz
      // (yoqilgan bo'lsa modal qayta chiqmaydi, o'chiq bo'lsa bir marta so'raymiz).
      unawaited(_guardLocationService());
      // "O'chirishni taqiqlash" dialogi — RESUME'da ham ruxsat.
      // ⚠️ Avval dialog FAQAT initState'da (cold start) chiqardi: ota-ona
      // toggle'ni yoqqan paytda bola ilovasi ochiq bo'lsa, himoya AMALDA
      // hech qachon yoqilmasdi (toggle esa ota-onada yashil ko'rinardi).
      // `_promptedThisSession` loop'ning oldini oladi — sessiyada bir marta.
      unawaited(_syncUninstallProtection(allowPrompt: !_promptedThisSession));
      unawaited(_checkPendingTimeRequest());
    }
  }

  /// iOS: bloklash ekranida "Qo'shimcha vaqt so'rash" bosilgan bo'lsa (eslatma
  /// orqali shu yerga keladi) — so'rov oynasini ochadi. Bu yerda (splash
  /// emas) — navigatsiya dialogni yopib yubormasligi uchun.
  Future<void> _checkPendingTimeRequest() async {
    if (!PlatformCapabilities.isIOS) return;
    try {
      final hasRequest = await ref
          .read(screenTimeChannelProvider)
          .consumePendingUnlockRequest();
      if (!hasRequest || !mounted) return;
      await ref.read(unlockRequestFlowProvider)();
    } on ScreenTimeException catch (e) {
      debugPrint('Dashboard: vaqt so\'rovi tekshiruvi xato: $e');
    }
  }

  void _refresh() {
    if (!mounted) return;
    // Qadamni telefon soniga yaqinlashtirish — Health Connect'dan HAQIQIY
    // jamini darhol tortamiz (davriy 5 daqiqani kutmasdan). onStepsUpdated
    // UI keshini yangilaydi, quyidagi invalidate esa yangi qiymatni ko'rsatadi.
    final stepSvc = ref.read(stepCounterServiceProvider);
    if (stepSvc != null) unawaited(stepSvc.syncNow());
    ref
      ..invalidate(todayStepsProvider)
      ..invalidate(backendContestsProvider);
    unawaited(refreshLearning(ref));
    // Deaktivatsiya (ota-ona o'chirsa) darhol; faollashtirish dialogi YO'Q
    // (loop bo'lmasin — dialog faqat app ochilganda, initState'da).
    unawaited(_syncUninstallProtection(allowPrompt: false));
  }

  /// "O'chirishni taqiqlash" siyosatini backend'dan o'qib qo'llaydi. Bola
  /// admin'ni o'chirgan bo'lsa (native bayroq) — ota-onaga xabar yuboradi.
  Future<void> _syncUninstallProtection({required bool allowPrompt}) async {
    if (!PlatformCapabilities.hasAndroidControls) return;
    final childId = ref.read(pairingStateProvider).childId;
    if (childId == null) return;
    final repo = ref.read(backendDevicePolicyRepositoryProvider);
    final policy = await repo.getDevicePolicy(childId);
    if (allowPrompt && (policy.blockUninstall ?? false)) {
      _promptedThisSession = true;
    }
    await uninstallProtectionService.apply(
      policy.blockUninstall,
      allowPrompt: allowPrompt,
    );
    // Bola himoyani o'chirgan bo'lsa → ota-onaga "himoya o'chirildi" push.
    final deactivated = await uninstallProtectionService
        .consumeDeactivatedFlag();
    if (deactivated) {
      unawaited(repo.reportUninstallGuardDisabled(childId));
    }
  }

  Future<void> _updateStreak() async {
    final pairing = ref.read(pairingStateProvider);
    final parentUid = pairing.parentUid;
    final childId = pairing.childId;
    if (parentUid == null || childId == null) return;
    try {
      await ref
          .read(xpServiceProvider)
          .updateStreakOnDailyOpen(parentUid: parentUid, childId: childId);
    } catch (_) {}
  }

  /// Android nazorat ruxsatlari (usage/overlay/batareya) yo'qolsa — qayta
  /// ruxsatlar ekraniga. iOS'da bunday ruxsatlar yo'q va Apple 5.1.1
  /// foydalanuvchini majburlashni taqiqlaydi.
  Future<void> _guardPermissions() async {
    if (!PlatformCapabilities.hasAndroidControls) return;
    final usageService = UsageStatsService();
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    final usageGranted = await usageService.hasPermission();
    final overlayGranted = await usageService.hasOverlayPermission();
    final allGranted =
        batteryStatus.isGranted && usageGranted && overlayGranted;
    if (!allGranted && mounted) context.go('/permission-setup');
  }

  /// GPS xizmati (qurilma-darajada) O'CHIQ bo'lsa — bolaga "Joylashuvni yoqing"
  /// modalini DARHOL ko'rsatadi (ota-ona push'ini kutmasdan). Joylashuv RUXSATI
  /// yo'q bo'lsa tegmaymiz — u onboarding/permission oqimining ishi.
  Future<void> _guardLocationService() async {
    if (kIsWeb) return;
    final perm = await Geolocator.checkPermission();
    final granted =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    if (!granted) return;
    if (await Geolocator.isLocationServiceEnabled()) {
      // Yoqilgan — keyingi o'chishda yana so'ray olishimiz uchun flagni
      // tozalaymiz.
      _locationModalShown = false;
      return;
    }
    // OTA-ONAGA XABAR: bola joylashuvni o'chirdi. Ota-ona push oladi va
    // u yerdan "Joylashuvni yoqishni so'rash"ni bosa oladi.
    unawaited(_reportLocationDisabled());
    if (_locationModalShown || !mounted) return;
    _locationModalShown = true;
    await LocationEnableModal.show(context);
  }

  /// "Joylashuv o'chirildi" xabarini ota-onaga yuboradi — 6 SOATDA BIR MARTA.
  ///
  /// Throttle shart: aks holda bola GPS'ni o'chirib qo'ysa, har ilova
  /// ochilishida/qaytishida ota-onaga push ketardi (spam).
  Future<void> _reportLocationDisabled() async {
    final childId = ref.read(pairingStateProvider).childId;
    if (childId == null || childId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'location.disabledReportedAt';
      final last = prefs.getInt(key) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < const Duration(hours: 6).inMilliseconds) return;
      await prefs.setInt(key, now);
      await ref
          .read(backendDevicePolicyRepositoryProvider)
          .reportLocationDisabled(childId);
    } catch (e) {
      debugPrint('reportLocationDisabled xato: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingStateProvider);
    if (!pairing.isPaired) {
      return const Scaffold(
        backgroundColor: HomeColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: HomeColors.primary),
        ),
      );
    }
    return HomeScaffold(
      onRefresh: () async => _refresh(),
      banners: const [UpdateBanner(), IosSetupBanner()],
    );
  }
}

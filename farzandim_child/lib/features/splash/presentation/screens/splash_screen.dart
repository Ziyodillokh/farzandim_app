// ─────────────────────────────────────────────────────────────────────
// SplashScreen — har startup'da pairing + permissions tekshiradi
// ─────────────────────────────────────────────────────────────────────
//
// Router uchun initial route. 800ms shield+logo ko'rsatadi va
// keyin quyidagicha yo'naltiradi:
//   - Pairing yo'q                                  → /pairing (kod kiritish)
//   - Pairing bor + onboarding ko'rilmagan          → /onboarding (qiziqishlar)
//   - Pairing bor + 4 sistema ruxsati yo'q          → /permission-setup
//   - Pairing bor + barcha 4 ruxsat yoqilgan        → /dashboard
//
// MUHIM: onboarding (qiziqishlar) endi faqat KOD kiritilgandan keyin
// ochiladi — pair bo'lmagan bola to'g'ridan-to'g'ri /pairing ga boradi.
//
// 5 ta sistema ruxsati: locationAlways, ignoreBatteryOptimizations,
// PACKAGE_USAGE_STATS, SYSTEM_ALERT_WINDOW, POST_NOTIFICATIONS.
// Notification 2026-08-10 dan MAJBURIY gate'ga kirdi: Google Play
// "Stalkerware/Monitoring" siyosati monitoring ilovadan HAR DOIM ko'rinib
// turadigan doimiy bildirishnomani talab qiladi — Android 13+ da
// POST_NOTIFICATIONS rad etilsa foreground-servis bildirishnomasi
// status-barda KO'RINMAYDI va talab amalda buziladi. Camera — runtime
// perm — bu yerda tekshirilmaydi (kerak bo'lganda ad-hoc so'raladi).
//
// iOS: Android nazorat ruxsatlari yo'q va Apple 5.1.1 majburlashni
// taqiqlaydi — ruxsatlar ekrani faqat BIR MARTA (tanishtiruv) ko'rsatiladi,
// keyin har doim /dashboard.

import 'package:farzandim_child/features/permissions/data/oem_background_service.dart';
import 'package:farzandim_child/core/auth/session_events.dart';
import 'package:farzandim_child/core/auth/token_storage.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/onboarding/presentation/screens/language_select_screen.dart'
    show kLanguagePickedKey;
import 'package:farzandim_child/features/onboarding/data/onboarding_prefs.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/ios_permission_setup_screen.dart'
    show kPermissionIntroSeenKey;
import 'package:farzandim_child/growth/growth_routes.dart';
import 'package:farzandim_child/growth/kirish/data/account_registry.dart';
import 'package:farzandim_child/growth/kirish/data/account_scope.dart';
import 'package:farzandim_child/growth/kirish/kirish_flow.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_route);
  }

  // PERF: avval 800ms sun'iy delay + 1s consent poll bor edi (native splash
  // ustiga ortiqcha). Endi routing qarori to'g'ridan storage'dan (consent +
  // SharedPreferences pairing/onboarding) o'qiladi — provider-timing kutmasdan,
  // ~50-150ms. 250ms — silliq brend o'tishi (native splashdan keyin).
  Future<void> _route() async {
    final routeFuture = _decideRoute();
    // Route qarori bilan PARALLEL minimal brend-flash (jarangsiz o'tish).
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final route = await routeFuture;
    if (!mounted) return;
    context.go(route);
  }

  /// Qaysi ekranga o'tishni storage'dan to'g'ridan hal qiladi (tez, ishonchli).
  Future<String> _decideRoute() async {
    final prefs = await SharedPreferences.getInstance();

    // 2. Pairing holati — `paired` SharedPreferences'dagi parentUid/childId
    //    bilan aniqlanadi (Firebase emas — tez).
    //    Refresh token yo'q bo'lsa (server sessiyani bekor qilgan) — ulanmagan
    //    deb hisoblaymiz; PairingNotifier eski ma'lumotni o'zi tozalaydi.
    final parentUid = prefs.getString('parentUid');
    final childId = prefs.getString('childId');
    // v5: mehmon akkaunt, A12, akkaunt tanlash va kirish ekranlari.
    final v5 = await _decideV5(prefs, parentUid, childId);
    if (v5 != null) return v5;

    // Qurilma egasi kirgan (v5 qarori `null`): ruxsatlar sozlamasi va bosh
    // sahifa.
    // Web preview — permission/UsageStats yo'q.
    if (kIsWeb) return '/dashboard';

    if (PlatformCapabilities.isIOS) {
      final introSeen = prefs.getBool(kPermissionIntroSeenKey) ?? false;
      return introSeen ? '/dashboard' : '/permission-setup';
    }

    // 5 ta sistema ruxsati — PARALLEL (avval ketma-ket await edi, ~0.3-0.6s
    //    startup'ni sekinlashtirardi). Notification — Play Monitoring-siyosati
    //    "doimiy ko'rinadigan bildirishnoma" talabi uchun majburiy (Android 12-
    //    da POST_NOTIFICATIONS avtomatik granted, gate'ga ta'sir qilmaydi).
    final usageService = UsageStatsService();
    final checks = await Future.wait<bool>([
      Permission.locationAlways.status.then((s) => s.isGranted),
      Permission.ignoreBatteryOptimizations.status.then((s) => s.isGranted),
      usageService.hasPermission(),
      usageService.hasOverlayPermission(),
      Permission.notification.status.then((s) => s.isGranted),
    ]);
    final allGranted = checks.every((granted) => granted);
    if (!allGranted) return '/permission-setup';
    // Xiaomi/Tecno/Oppo va h.k.: «Avtomatik ishga tushish» yoqilmasa tizim
    // ilovani o'ldirib, qayta yoqmaydi. Eski o'rnatishlar ruxsat ekranini
    // boshqa ko'rmaydi — shu qator uchun bir marta ochamiz.
    final nudge = shouldNudgeAutostart(
      hasAutostartScreen: await const OemBackgroundService().hasAutostartScreen(),
      confirmed: prefs.getBool(kOemAutostartConfirmedKey) ?? false,
      alreadyNudged: prefs.getBool(kOemAutostartNudgedKey) ?? false,
    );
    if (nudge) {
      await prefs.setBool(kOemAutostartNudgedKey, true);
      return '/permission-setup';
    }
    return '/dashboard';
  }

  /// Growth v5 kirish qarorlari. `null` — odatiy (qurilma egasi) oqim davom
  /// etadi: ruxsatlar sozlamasi va bosh sahifa.
  Future<String?> _decideV5(
    SharedPreferences prefs,
    String? parentUid,
    String? childId,
  ) async {
    final registry = ref.read(accountRegistryProvider);
    // «Bu qurilmada chiqildi» (A12): faol akkaunt yopilgan — sababi bilan.
    if (registry.closedNotice != null) return GrowthV5Routes.kirishClosed;
    final guest = registry.activeGuest;
    if (guest != null) {
      // Mehmon akkaunt (UI shu bolaning konteynerida): nazorat ekranlari yo'q.
      if (await ref.read(tokenStorageProvider).isSessionDefinitelyMissing()) {
        await registry.signOutGuest(
          guest.childId,
          notice: SessionClosedReason.other,
        );
        return GrowthV5Routes.kirishClosed;
      }
      return await isProfileDone(guest.childId)
          ? '/dashboard'
          : GrowthV5Routes.kirishProfile;
    }
    final ownerPaired =
        parentUid != null &&
        childId != null &&
        !await ref.read(tokenStorageProvider).isSessionDefinitelyMissing();
    if (!ownerPaired) {
      if (registry.owner != null) {
        // Egasining sessiyasi ilova yopiq paytida tugagan (fon isolate'i
        // bekor qilinganini ko'rgan yoki juftlash uzilgan) — sababi bilan A12.
        final reason = prefs.getString(SessionEvents.ownerReasonKey);
        await prefs.remove(SessionEvents.ownerReasonKey);
        await registry.ownerClosed(notice: closedReasonFromWire(reason));
        return GrowthV5Routes.kirishClosed;
      }
      if (registry.accounts.isNotEmpty) return GrowthV5Routes.kirishAccounts;
      final picked = prefs.getBool(kLanguagePickedKey) ?? false;
      return picked ? GrowthV5Routes.kirishLogin : GrowthV5Routes.kirish;
    }
    // Qurilma egasi A10 ro'yxatida ko'rinsin.
    final owner = registry.owner;
    if (owner == null || owner.childId != childId) {
      await registry.upsert(
        DeviceAccount(
          childId: childId,
          name: prefs.getString('childName') ?? '',
          owner: true,
        ),
        activate: true,
      );
    }
    final onboardingSeen = prefs.getBool(kOnboardingSeenKey) ?? false;
    if (!onboardingSeen && !await isProfileDone(childId)) {
      return GrowthV5Routes.kirishProfile;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/growth_logo.png',
              width: 112,
              height: 112,
            ),
            const SizedBox(height: 24),
            const Text(
              'Parvoz',
              style: TextStyle(
                color: AppColors.parvozText,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.parvozGreen),
          ],
        ),
      ),
    );
  }
}

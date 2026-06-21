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
// 4 ta sistema ruxsati: locationAlways, ignoreBatteryOptimizations,
// PACKAGE_USAGE_STATS, SYSTEM_ALERT_WINDOW. Notification/camera —
// runtime perms — bu yerda tekshirilmaydi (kerak bo'lganda ad-hoc
// so'raladi). 800ms — SharedPreferences'dan pairing state'ni
// `PairingNotifier._loadFromStorage` tiklab ulgurishi uchun.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/consent/data/services/consent_storage.dart';
import 'package:farzandim_child/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingSeenKey;
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
    // 1. Parent Consent (Store compliance) — storage'dan to'g'ridan.
    final consentGiven = await ConsentStorage.isParentConsentGiven();
    if (!consentGiven) return '/consent';

    final prefs = await SharedPreferences.getInstance();

    // 2. Pairing — `paired` holati SharedPreferences'dagi parentUid/childId
    //    bilan aniqlanadi (Firebase emas — tez).
    final parentUid = prefs.getString('parentUid');
    final childId = prefs.getString('childId');
    if (parentUid == null || childId == null) return '/pairing';

    // 3. Onboarding (qiziqishlar) — faqat pair'dan keyin, bir marta.
    final onboardingSeen = prefs.getBool(kOnboardingSeenKey) ?? false;
    if (!onboardingSeen) return '/onboarding';

    // 4. Web preview — permission/UsageStats yo'q.
    if (kIsWeb) return '/dashboard';

    // 5. 4 ta sistema ruxsati.
    final usageService = UsageStatsService();
    final locStatus = await Permission.locationAlways.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    final usageGranted = await usageService.hasPermission();
    final overlayGranted = await usageService.hasOverlayPermission();
    final allGranted = locStatus.isGranted &&
        batteryStatus.isGranted &&
        usageGranted &&
        overlayGranted;
    return allGranted ? '/dashboard' : '/permission-setup';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/icons/child_logo_icon.png',
                width: 112,
                height: 112,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Parvoz',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

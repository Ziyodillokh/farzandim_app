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

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/onboarding/presentation/screens/language_select_screen.dart'
    show kLanguagePickedKey;
import 'package:farzandim_child/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingSeenKey;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final parentUid = prefs.getString('parentUid');
    final childId = prefs.getString('childId');
    final isPaired = parentUid != null && childId != null;

    // 3. Til — faqat YANGI foydalanuvchi (hali pair emas va til tanlanmagan).
    //    Mavjud (pair bo'lgan) foydalanuvchi til sahifasini qayta ko'rmaydi.
    final languagePicked = prefs.getBool(kLanguagePickedKey) ?? false;
    if (!isPaired && !languagePicked) return '/welcome';

    // 4. Pair bo'lmagan → kod kiritish.
    if (!isPaired) return '/pairing';

    // 3. Onboarding (qiziqishlar) — faqat pair'dan keyin, bir marta.
    final onboardingSeen = prefs.getBool(kOnboardingSeenKey) ?? false;
    if (!onboardingSeen) return '/onboarding';

    // 4. Web preview — permission/UsageStats yo'q.
    if (kIsWeb) return '/dashboard';

    // 5. 5 ta sistema ruxsati — PARALLEL (avval ketma-ket await edi, ~0.3-0.6s
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
    return allGranted ? '/dashboard' : '/permission-setup';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/parvoz_logo_mark.svg',
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

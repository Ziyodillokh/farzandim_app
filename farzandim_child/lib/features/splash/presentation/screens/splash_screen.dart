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
import 'package:farzandim_child/features/consent/presentation/providers/consent_provider.dart';
import 'package:farzandim_child/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingSeenKey;
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
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

  Future<void> _route() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Parent Consent (Store compliance) — birinchi ochilishda majburiy.
    // `unknown` paytda SharedPreferences hali yuklanmagan, biroz kutamiz.
    var consent = ref.read(consentStateProvider);
    if (consent == ConsentState.unknown) {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        consent = ref.read(consentStateProvider);
        if (consent != ConsentState.unknown) break;
      }
    }
    if (consent == ConsentState.notGiven) {
      context.go('/consent');
      return;
    }

    final pairing = ref.read(pairingStateProvider);
    if (!pairing.isPaired) {
      // Pair bo'lmagan bola — to'g'ridan-to'g'ri kod kiritish ekraniga.
      // Onboarding (qiziqishlar) endi faqat KOD kiritilgandan keyin
      // ko'rsatiladi (pastdagi paired bloki).
      context.go('/pairing');
      return;
    }

    // ── Pair bo'lgan ──
    // Onboarding (qiziqishlar) hali ko'rilmagan bo'lsa — avval shuni
    // ko'rsatamiz. Bola tugatgach `onboarding_seen_v1=true` saqlanadi va
    // keyingi startup'larda to'g'ridan-to'g'ri permission/dashboard'ga.
    {
      final prefs = await SharedPreferences.getInstance();
      final onboardingSeen = prefs.getBool(kOnboardingSeenKey) ?? false;
      if (!mounted) return;
      if (!onboardingSeen) {
        context.go('/onboarding');
        return;
      }
    }

    // Web preview'da permission_handler / UsageStats — UnimplementedError.
    // Pair bo'lgan bo'lsa to'g'ridan-to'g'ri dashboard'ga.
    if (kIsWeb) {
      context.go('/dashboard');
      return;
    }

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

    if (!mounted) return;
    if (!allGranted) {
      context.go('/permission-setup');
      return;
    }

    context.go('/dashboard');
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

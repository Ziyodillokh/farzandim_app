// ─────────────────────────────────────────────────────────────────────
// SplashScreen — har startup'da pairing + permissions tekshiradi
// ─────────────────────────────────────────────────────────────────────
//
// Router uchun initial route. 800ms shield+logo ko'rsatadi va
// keyin quyidagicha yo'naltiradi:
//   - Pairing yo'q                                  → /welcome
//   - Pairing bor + 4 sistema ruxsati yo'q          → /permission-setup
//   - Pairing bor + barcha 4 ruxsat yoqilgan        → /dashboard
//
// 4 ta sistema ruxsati: locationAlways, ignoreBatteryOptimizations,
// PACKAGE_USAGE_STATS, SYSTEM_ALERT_WINDOW. Notification/camera —
// runtime perms — bu yerda tekshirilmaydi (kerak bo'lganda ad-hoc
// so'raladi). 800ms — SharedPreferences'dan pairing state'ni
// `PairingNotifier._loadFromStorage` tiklab ulgurishi uchun.

import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

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

    final pairing = ref.read(pairingStateProvider);
    if (!pairing.isPaired) {
      // Bola ilovasida birinchi ekran — kodni kiritish (Welcome o'tkazib
      // yuboriladi). Dizayn talabiga ko'ra ota-ona kodini darhol so'raydi.
      context.go('/pairing');
      return;
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
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.black,
                size: 50,
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

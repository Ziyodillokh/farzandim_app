// ─────────────────────────────────────────────────────────────────────
// PermissionSetupScreen — sistema-darajadagi 4 ta ruxsatni yig'ish
// ─────────────────────────────────────────────────────────────────────
//
// Pairing → /permissions (location/notification/camera) tugagach,
// shu ekran ochiladi va sistema sozlamalarini talab qiluvchi 4 ta
// ruxsatni yig'adi:
//   1. Joylashuv (background — locationAlways)
//   2. Batareya optimizatsiyasi (whitelist)
//   3. PACKAGE_USAGE_STATS (UsageStatsManager)
//   4. SYSTEM_ALERT_WINDOW (overlay)
//
// Hammasi yashil bo'lgach RestrictionService avtomatik boshlanadi
// va Dashboard'ga o'tiladi. Lifecycle resume → recheck.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionSetupScreen extends ConsumerStatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  ConsumerState<PermissionSetupScreen> createState() =>
      _PermissionSetupScreenState();
}

class _PermissionSetupScreenState
    extends ConsumerState<PermissionSetupScreen>
    with WidgetsBindingObserver {
  final _usageService = UsageStatsService();

  bool _locationGranted = false;
  bool _batteryOptimized = false;
  bool _usageStatsGranted = false;
  bool _overlayGranted = false;

  bool _checking = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
  }

  Future<void> _checkAll() async {
    if (_checking || _finishing) return;
    setState(() => _checking = true);

    final locStatus = await Permission.location.status;
    final bgLocStatus = await Permission.locationAlways.status;
    final locGranted = locStatus.isGranted && bgLocStatus.isGranted;

    final batteryStatus =
        await Permission.ignoreBatteryOptimizations.status;

    final usageGranted = await _usageService.hasPermission();
    final overlayGranted = await _usageService.hasOverlayPermission();

    if (!mounted) return;
    setState(() {
      _locationGranted = locGranted;
      _batteryOptimized = batteryStatus.isGranted;
      _usageStatsGranted = usageGranted;
      _overlayGranted = overlayGranted;
      _checking = false;
    });

    if (_allGranted) {
      await _finishSetup();
    }
  }

  bool get _allGranted =>
      _locationGranted &&
      _batteryOptimized &&
      _usageStatsGranted &&
      _overlayGranted;

  Future<void> _finishSetup() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    await _usageService.startRestrictionService();
    // app_usage + installed_apps Firestore sync timer'ini boshlash.
    ref.read(usageSyncServiceProvider)?.start();

    if (!mounted) return;
    context.go('/dashboard');
  }

  Future<void> _requestLocation() async {
    await Permission.location.request();
    await Permission.locationAlways.request();
    await _checkAll();
  }

  Future<void> _requestBattery() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _checkAll();
  }

  Future<void> _requestUsageStats() async {
    await _usageService.openSettings();
    // Resume lifecycle'da auto-recheck
  }

  Future<void> _requestOverlay() async {
    await _usageService.openOverlaySettings();
    // Resume lifecycle'da auto-recheck
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBottom,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'permissionSetup.title'.tr(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'permissionSetup.subtitle'.tr(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _PermissionStep(
                    number: 1,
                    icon: AppIcons.mapPin,
                    title: 'permissionSetup.step1Title'.tr(),
                    subtitle: 'permissionSetup.step1Subtitle'.tr(),
                    granted: _locationGranted,
                    onPressed:
                        _locationGranted ? null : _requestLocation,
                  ),
                  const SizedBox(height: 12),
                  _PermissionStep(
                    number: 2,
                    icon: Icons.battery_full,
                    title: 'permissionSetup.step2Title'.tr(),
                    subtitle: 'permissionSetup.step2Subtitle'.tr(),
                    granted: _batteryOptimized,
                    onPressed:
                        _batteryOptimized ? null : _requestBattery,
                  ),
                  const SizedBox(height: 12),
                  _PermissionStep(
                    number: 3,
                    icon: AppIcons.schedule,
                    title: 'permissionSetup.step3Title'.tr(),
                    subtitle: 'permissionSetup.step3Subtitle'.tr(),
                    granted: _usageStatsGranted,
                    onPressed:
                        _usageStatsGranted ? null : _requestUsageStats,
                  ),
                  const SizedBox(height: 12),
                  _PermissionStep(
                    number: 4,
                    icon: Icons.layers,
                    title: 'permissionSetup.step4Title'.tr(),
                    subtitle: 'permissionSetup.step4Subtitle'.tr(),
                    granted: _overlayGranted,
                    onPressed: _overlayGranted ? null : _requestOverlay,
                  ),
                  const SizedBox(height: 24),
                  if (!_allGranted)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'permissionSetup.autoContinueHint'.tr(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    this.onPressed,
  });

  final int number;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: granted
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: granted
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              granted ? AppIcons.check : icon,
              color: granted ? Colors.black : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'permissionSetup.stepNumber'.tr(
                    namedArgs: {
                      'number': '$number',
                      'title': title,
                    },
                  ),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (granted)
            const Icon(
              AppIcons.success,
              color: AppColors.primary,
              size: 24,
            )
          else
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                'permissionSetup.grantButton'.tr(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

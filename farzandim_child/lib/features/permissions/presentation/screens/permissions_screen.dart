// ─────────────────────────────────────────────────────────────────────
// PermissionsScreen — 3 ta ruxsatni so'rash
// ─────────────────────────────────────────────────────────────────────
//
// Pairing muvaffaqiyatli tugagandan keyin ko'rsatiladi.
// 3 ta ruxsat:
//   1. Location (joylashuv)     — bola qaerda ekanligi
//   2. Notification (bildirishnoma) — oilaning xabarlari
//   3. Camera (kamera)          — kelajak foto so'rovlari uchun
//
// Hammasi yoqilmaguncha "Davom etish" tugmasi disabled.

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/location/presentation/providers/location_provider.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:farzandim_child/shared/widgets/gradient_background.dart';
import 'package:farzandim_child/shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _cameraGranted = false;

  // Auto-prompt holati
  bool _isAutoRequesting = false;
  int _currentRequestIndex = 0;
  int _totalPermissions = 0;

  static const List<Permission> _autoPermissions = [
    Permission.locationWhenInUse,
    Permission.notification,
    Permission.camera,
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkPermissions();
    // Ekran ochilgach 800ms delay, keyin auto-prompt boshlanadi.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (!_allGranted) await _autoRequestPermissions();
    });
  }

  /// Init paytida joriy holatni tekshiramiz — agar foydalanuvchi
  /// avval ruxsat bergan bo'lsa, qayta so'ramaymiz.
  ///
  /// Har bir chaqiruv try/catch bilan — permission_handler ba'zi OEM
  /// qurilmalarida PlatformException tashlashi mumkin; ushlanmasa
  /// ilova crash bo'ladi (foydalanuvchi "ilovadan chiqib ketyapti").
  Future<void> _checkPermissions() async {
    _locationGranted = await _safeGranted(Permission.location);
    _notificationGranted = await _safeGranted(Permission.notification);
    _cameraGranted = await _safeGranted(Permission.camera);
    if (mounted) setState(() {});
  }

  /// `permission.isGranted` ni xavfsiz o'qiydi — xato bo'lsa `false`.
  Future<bool> _safeGranted(Permission permission) async {
    try {
      return await permission.isGranted;
    } catch (_) {
      return false;
    }
  }

  bool get _allGranted =>
      _locationGranted && _notificationGranted && _cameraGranted;

  /// Native permission dialog'larini ketma-ket avtomatik chiqaradi.
  /// Foydalanuvchi har biriga "Allow"/"Deny" bossa keyingisiga o'tadi.
  /// Hammasi tugab `_allGranted == true` bo'lsa Dashboard'ga o'tadi.
  Future<void> _autoRequestPermissions() async {
    setState(() {
      _isAutoRequesting = true;
      _currentRequestIndex = 0;
      _totalPermissions = _autoPermissions.length;
    });

    for (var i = 0; i < _autoPermissions.length; i++) {
      if (!mounted) return;
      setState(() => _currentRequestIndex = i);

      final permission = _autoPermissions[i];
      // Har bir so'rovni try/catch bilan — bitta permission xato bersa
      // butun oqim (va ilova) yiqilmasin, keyingisiga o'tamiz.
      //
      // MUHIM: auto-oqimda FAQAT foreground ruxsatlar (whenInUse, bildirishnoma,
      // kamera) so'raladi — ular ilova ichida oddiy dialog ko'rsatadi.
      // `locationAlways` (orqa fon) bu yerda SO'RALMAYDI: Android 11+ da u
      // majburan tizim Sozlamalariga olib chiqadi → foydalanuvchi "ilova o'zi
      // yopilib ketdi" deb o'ylaydi. Orqa fon ruxsati keyinroq, foydalanuvchi
      // location plitkasini o'zi bosganda (yoki permission-setup ekranida)
      // so'raladi.
      try {
        final status = await permission.status;
        if (!status.isGranted) {
          await permission.request();
        }
      } catch (_) {
        /* permission_handler xatosi — keyingi ruxsatga o'tamiz */
      }
      // Qisqa pauza — UX uchun (dialog'lar bir-biriga yopishmasin)
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    await _checkPermissions();

    setState(() => _isAutoRequesting = false);

    if (_allGranted && mounted) {
      await _onContinue();
    }
  }

  /// Background ("har doim") location ruxsati — whenInUse'dan KEYIN
  /// so'raladi. Bersa bola fonda ham kuzatiladi; rad etsa best-effort,
  /// oqim davom etadi (gating faqat whenInUse'ga qaraydi).
  Future<void> _requestLocationAlways() async {
    try {
      final always = await Permission.locationAlways.status;
      if (!always.isGranted) {
        await Permission.locationAlways.request();
      }
    } catch (_) {
      return;
    }
  }

  /// "Davom etish" — Location ruxsat tryPair() vaqtida bo'lmagan, shuning
  /// uchun LocationService shu yerda qayta ishga tushiriladi (paired
  /// state'dan parentUid/childId olib). Keyin /permission-setup ekraniga
  /// o'tib sistema-darajadagi 4 ta ruxsatni yig'amiz.
  Future<void> _onContinue() async {
    final pairing = ref.read(pairingStateProvider);
    if (pairing.isPaired &&
        pairing.parentUid != null &&
        pairing.childId != null) {
      final locationService = ref.read(locationServiceProvider);
      await locationService.start(
        parentUid: pairing.parentUid!,
        childId: pairing.childId!,
        childName: pairing.childName ?? 'Bola',
      );
    }
    if (mounted) context.go('/permission-setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                Text(
                  'permissions.title'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'permissions.subtitle'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 16),

                if (_isAutoRequesting) _buildAutoProgress(),

                const SizedBox(height: 16),

                _buildPermissionTile(
                  icon: AppIcons.mapPin,
                  title: 'permissions.locationTitle'.tr(),
                  description: 'permissions.locationDescription'.tr(),
                  granted: _locationGranted,
                  onTap: () async {
                    final status =
                        await Permission.locationWhenInUse.request();
                    // whenInUse berilgach "har doim" ruxsatini ham so'raymiz.
                    if (status.isGranted) {
                      await _requestLocationAlways();
                    }
                    if (mounted) {
                      setState(() => _locationGranted = status.isGranted);
                    }
                  },
                ),
                const SizedBox(height: 12),

                _buildPermissionTile(
                  icon: AppIcons.bell,
                  title: 'permissions.notificationTitle'.tr(),
                  description: 'permissions.notificationDescription'.tr(),
                  granted: _notificationGranted,
                  onTap: () async {
                    final status = await Permission.notification.request();
                    if (mounted) {
                      setState(() => _notificationGranted = status.isGranted);
                    }
                  },
                ),
                const SizedBox(height: 12),

                _buildPermissionTile(
                  icon: AppIcons.camera,
                  title: 'permissions.cameraTitle'.tr(),
                  description: 'permissions.cameraDescription'.tr(),
                  granted: _cameraGranted,
                  onTap: () async {
                    final status = await Permission.camera.request();
                    if (mounted) {
                      setState(() => _cameraGranted = status.isGranted);
                    }
                  },
                ),

                const Spacer(),

                if (!_isAutoRequesting)
                  PrimaryButton(
                    text: _allGranted
                        ? 'permissions.continueButton'.tr()
                        : 'permissions.enableAllButton'.tr(),
                    onPressed: _allGranted ? _onContinue : null,
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'permissions.autoRequesting'.tr(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'permissions.progress'.tr(namedArgs: {
                    'current': '${_currentRequestIndex + 1}',
                    'total': '$_totalPermissions',
                  }),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: granted ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: granted
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: granted ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: granted
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: granted ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (granted)
              const Icon(
                AppIcons.success,
                color: AppColors.primary,
                size: 24,
              )
            else
              const Icon(
                AppIcons.chevronRight,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

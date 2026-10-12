// ─────────────────────────────────────────────────────────────────────
// IosPermissionSetupScreen — iOS ruxsatlar ekrani (BLOKLAMAYDI)
// ─────────────────────────────────────────────────────────────────────
//
// Android ekranidan farqi:
//   • usage/overlay/batareya/Device Admin yo'q — iOS'da bunday ruxsatlar
//     mavjud emas (ilovalarni cheklash Family Controls orqali ishlaydi).
//   • "Davom etish" HAR DOIM faol. Apple 5.1.1(iv): ilova foydalanuvchini
//     ruxsat berishga majburlamasligi, rad etilsa ham ishlashi kerak.
//   • Ekran bir marta ko'rsatiladi ([kPermissionIntroSeenKey]); keyin
//     ruxsatlarni iPhone Sozlamalarida o'zgartirish mumkin.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:farzandim_child/features/permissions/presentation/widgets/permission_setup_widgets.dart';

/// iOS ruxsatlar ekrani ko'rilganmi — Splash shu bayroq bo'yicha uni
/// faqat birinchi marta ko'rsatadi.
const String kPermissionIntroSeenKey = 'permissions.iosIntroSeen.v1';

class IosPermissionSetupScreen extends ConsumerStatefulWidget {
  const IosPermissionSetupScreen({super.key});

  @override
  ConsumerState<IosPermissionSetupScreen> createState() =>
      _IosPermissionSetupScreenState();
}

class _IosPermissionSetupScreenState
    extends ConsumerState<IosPermissionSetupScreen>
    with WidgetsBindingObserver {
  bool _location = false;
  bool _notif = false;
  bool _steps = false;
  bool _checking = false;
  bool _recheckPending = false;

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
    if (state == AppLifecycleState.resumed) _checkAll();
  }

  static Future<bool> _isGranted(Permission permission) async {
    try {
      return (await permission.status).isGranted;
    } catch (e) {
      debugPrint('IosPermissionSetup: ${permission.toString()} status xato: $e');
      return false;
    }
  }

  /// Tekshiruv davom etayotganda kelgan so'rov tashlab yuborilmaydi —
  /// tugagach yana bir marta tekshiriladi (aks holda resume + so'rovdan
  /// keyingi tekshiruv ustma-ust tushib, toggle eski holatda qolardi).
  Future<void> _checkAll() async {
    if (_checking) {
      _recheckPending = true;
      return;
    }
    _checking = true;
    do {
      _recheckPending = false;
      final results = await Future.wait<bool>([
        // Fonda ishlash (ota-ona xaritasi, cheklovlar darhol yetishi) uchun
        // "Har doim" kerak — "Foydalanish paytida" yetarli emas.
        _isGranted(Permission.locationAlways),
        _isGranted(Permission.notification),
        _isGranted(Permission.sensors),
      ]);
      if (!mounted) break;
      setState(() {
        _location = results[0];
        _notif = results[1];
        _steps = results[2];
      });
    } while (_recheckPending);
    _checking = false;
  }

  /// Bir ruxsatni so'raydi. iOS'da rad etilgan ruxsat uchun tizim oynasi
  /// QAYTA chiqmaydi — shuning uchun Sozlamalar faqat ruxsat so'rovdan
  /// OLDIN rad etilgan bo'lsa ochiladi (foydalanuvchi o'zi qayta bosgan).
  /// Endigina "Ruxsat bermaslik"ni tanlagan foydalanuvchini Sozlamalarga
  /// olib o'tmaymiz (Apple 5.1.1 — bosim o'tkazmaslik).
  Future<PermissionStatus> _request(Permission permission) async {
    final before = await permission.status;
    if (before.isGranted) return before;
    if (before.isPermanentlyDenied || before.isRestricted) {
      await openAppSettings();
      return before;
    }
    return permission.request();
  }

  /// "Foydalanish paytida" → keyin "Har doim"ga ko'tarish taklifi (iOS uni
  /// bir marta ko'rsatadi). "Foydalanish paytida" berilganda permission_handler
  /// "Har doim"ni `permanentlyDenied` deb ko'rsatadi — shuning uchun taklif
  /// `_request` orqali emas, to'g'ridan so'raladi (aks holda bola taklifni
  /// ko'rmay Sozlamalarga otilardi). Taklif allaqachon ko'rsatilgan bo'lsa —
  /// qatorni qayta bosgan foydalanuvchiga Sozlamalar ochiladi.
  Future<void> _requestLocation() async {
    final whenInUse = await _request(Permission.locationWhenInUse);
    if (!whenInUse.isGranted) return;
    if (await Permission.locationAlways.isGranted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKeyAlwaysAsked) ?? false) {
      await openAppSettings();
      return;
    }
    await prefs.setBool(_prefsKeyAlwaysAsked, true);
    await Permission.locationAlways.request();
  }

  static const _prefsKeyAlwaysAsked = 'permissionSetup.iosLocationAlwaysAsked';

  Future<void> _requestSteps() async {
    final status = await _request(Permission.sensors);
    if (status.isGranted) {
      await ref.read(stepCounterServiceProvider)?.syncNow();
    }
  }

  Future<void> _onRowTap(Future<void> Function() request) async {
    try {
      await request();
    } catch (e) {
      debugPrint('IosPermissionSetup: so\'rov xato: $e');
    }
    await _checkAll();
  }

  Future<void> _onContinue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPermissionIntroSeenKey, true);
    } catch (e) {
      // Bayroq yozilmasa ekran keyingi safar yana chiqadi — bloklamaydi.
      debugPrint('IosPermissionSetup: bayroqni saqlab bo\'lmadi: $e');
    }
    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PermColors.bg,
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            right: -60,
            child: IgnorePointer(child: PermCornerGlow()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  Text(
                    'permissionSetup.title'.tr(),
                    style: GoogleFonts.unbounded(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'permissionSetup.iosSubtitle'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.45,
                      color: PermColors.dim,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        PermGroupCard(
                          rows: [
                            PermRow(
                              icon: Icons.location_on_rounded,
                              title: 'permissionSetup.locName'.tr(),
                              value: _location,
                              onChanged: () => _onRowTap(_requestLocation),
                            ),
                            PermRow(
                              icon: Icons.notifications_rounded,
                              title: 'permissionSetup.notifName'.tr(),
                              value: _notif,
                              onChanged: () => _onRowTap(
                                () => _request(Permission.notification),
                              ),
                            ),
                            PermRow(
                              icon: Icons.directions_walk_rounded,
                              title: 'permissionSetup.stepsName'.tr(),
                              value: _steps,
                              onChanged: () => _onRowTap(_requestSteps),
                            ),
                          ],
                        ),
                        if (!_location) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'permissionSetup.iosLocationAlwaysHint'.tr(),
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                height: 1.45,
                                color: PermColors.blueLight,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'permissionSetup.iosFootnote'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              height: 1.45,
                              color: PermColors.dim,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Ekran vaqti (Family Controls) — ixtiyoriy, ota-ona
                        // yonida bo'lganda sozlanadi (keyin Sozlamalarda ham).
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => context.push('/screen-time'),
                            icon: const Icon(
                              Icons.hourglass_bottom_rounded,
                              color: PermColors.blueLight,
                              size: 20,
                            ),
                            label: Text(
                              'permissionSetup.iosScreenTimeLink'.tr(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PermColors.blueLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PermNextButton(
                    enabled: true,
                    label: 'permissionSetup.continue'.tr(),
                    onTap: _onContinue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

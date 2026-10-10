// ─────────────────────────────────────────────────────────────────────
// PermissionSetupScreen — barcha ruxsatlar bitta sahifada (Parvoz redizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Asosiy: Joylashuv, Bildirishnomalar, Ilova statistikasi.
// Yordamchi: Boshqa ilovalarni ko'rsatish (overlay), Quvvatni
//            optimallashtirmaslik (battery).
// Har birida yashil toggle — bosilsa tegishli tizim so'rovi ochiladi.
// Lifecycle resume → recheck. Hammasi yoqilgach "Keyingisi" (ko'k) faollashadi.
// Web preview'da permission API yo'q — mock toggle + tugma doim faol.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/uninstall_protection_service.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/features/permissions/presentation/screens/location_disclosure_screen.dart';
import 'package:farzandim_child/features/permissions/presentation/widgets/permission_setup_widgets.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionSetupScreen extends ConsumerStatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  ConsumerState<PermissionSetupScreen> createState() =>
      _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends ConsumerState<PermissionSetupScreen>
    with WidgetsBindingObserver {
  final UsageStatsService _svc = UsageStatsService();

  bool _location = false; // Joylashuv (locationAlways)
  bool _notif = false; // Bildirishnomalar
  bool _usage = false; // Ilova statistikasi (usage stats)
  bool _overlay = false; // Boshqa ilovalar ustida
  bool _battery = false; // Quvvat optimizatsiyasi
  bool _uninstallGuard = false; // O'chirishni taqiqlash (Device Admin)
  // ⏸️ _a11y VAQTINCHA OLIB TASHLANDI — qarang shu fayldagi eski
  // "_requestAccessibility" o'rnidagi izoh va AndroidManifest.xml.

  bool _checking = false;

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

  Future<bool> _safeStatus(Future<PermissionStatus> Function() fn) async {
    try {
      return (await fn()).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _safe(Future<bool> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkAll() async {
    if (_checking || kIsWeb) return;
    setState(() => _checking = true);

    final location = await _safeStatus(() => Permission.locationAlways.status);
    final notif = await _safeStatus(() => Permission.notification.status);
    final usage = await _safe(_svc.hasPermission);
    final overlay = await _safe(_svc.hasOverlayPermission);
    final battery = await _safeStatus(
      () => Permission.ignoreBatteryOptimizations.status,
    );
    final uninstallGuard = await _safe(uninstallProtectionService.isActive);

    if (!mounted) return;
    setState(() {
      _location = location;
      _notif = notif;
      _usage = usage;
      _overlay = overlay;
      _battery = battery;
      _uninstallGuard = uninstallGuard;
      _checking = false;
    });
  }

  Future<void> _toggle({
    required bool current,
    required Future<void> Function() request,
    required void Function(bool) setMock,
  }) async {
    if (kIsWeb) {
      setState(() => setMock(!current));
      return;
    }
    try {
      await request();
    } catch (_) {
      /* tizim sozlamasi ochilmasa jim */
    }
    await _checkAll();
  }

  // Bildirishnoma ruxsati — rad etilgan HAR QANDAY holatda tizim
  // sozlamalariga yo'naltiramiz (aks holda tugma abadiy o'chiq qolib,
  // foydalanuvchi qamaladi — bildirishnoma endi majburiy gate, qarang
  // `_allGranted`).
  //
  // ⚠️ Nega faqat `isPermanentlyDenied` YETARLI EMAS: Android 13 dan PAST
  // versiyalarda POST_NOTIFICATIONS runtime-ruxsat sifatida mavjud emas —
  // permission_handler `areNotificationsEnabled()` ni tekshiradi va
  // `request()` hech qanday tizim dialogini KO'RSATMAY, to'g'ridan-to'g'ri
  // `denied` qaytaradi (permanentlyDenied EMAS). Foydalanuvchi bildirishnomani
  // qo'lda o'chirgan bo'lsa, yagona yo'l — ilova sozlamalarini ochish.
  Future<void> _requestNotif() async {
    final s = await Permission.notification.request();
    if (!s.isGranted) await openAppSettings();
  }

  // ⏸️ _requestAccessibility() VAQTINCHA OLIB TASHLANDI (2026-08-06):
  // AccessibilityService Play tekshiruvidan o'tmadi (APK yuklab olish
  // bosqichida yiqiladi) — avval accessibility'siz reliz chiqarib,
  // tasdiqlangач alohida yangilanish sifatida qaytaramiz. Kotlin fayllar
  // (BlockAccessibilityService.kt, BlockPolicy.kt) va disclosure ekrani
  // TEGILMAGAN — manifestda ro'yxatdan chiqarilgani uchun ishlamayapti,
  // xolos. Qarang: docs/BLOKLASH-QUVVATI-VA-A11Y-QARORI.md (2.4-band).

  /// Joylashuv — foreground ("ishlatilganda") + fon ("har doim").
  ///
  /// ⚠️ Play MAJBURIY talabi (2026-08-04 rad etish xati — "Inadequate
  /// Prominent Disclosure"): FON joylashuvi (`Permission.locationAlways`,
  /// ACCESS_BACKGROUND_LOCATION) so'ralishidan OLDIN alohida, aynan shu
  /// ruxsatga bog'liq oshkora tushuntirish ko'rsatilishi shart — umumiy
  /// consent ekrani (`/consent`) YETARLI EMAS. Qarang: LocationDisclosureScreen.
  Future<void> _requestLocation() async {
    final w = await Permission.locationWhenInUse.request();
    if (!w.isGranted) {
      // Rad etilgan har qanday holatda sozlamalarga yo'naltiramiz — aks holda
      // toggle abadiy o'chiq qolib, foydalanuvchi shu ekranda qamaladi.
      await openAppSettings();
      return;
    }
    if (!mounted) return;

    // Fon joylashuvidan OLDIN — Play majburiy oshkora tushuntirish.
    final disclosed = await LocationDisclosureScreen.show(context);
    if (!disclosed || !mounted) return;

    // ⚠️ Android 11+ (API 30+): ACCESS_BACKGROUND_LOCATION tizim dialogi
    // BILAN BERILMAYDI — `request()` hech qanday oyna ko'rsatmasdan `denied`
    // qaytaradi. Yagona yo'l — foydalanuvchini ilova sozlamalariga olib
    // borish ("Ruxsatlar → Joylashuv → Har doim ruxsat berish"). Bu fallback
    // bo'lmasa toggle hech qachon yonmaydi va ekran dead-end bo'ladi
    // (Play reviewer'i ham aynan shu yerda tiqilib qolgan bo'lishi mumkin).
    final always = await Permission.locationAlways.request();
    if (always.isGranted || !mounted) return;
    await _showAlwaysLocationHint();
  }

  /// Fon joylashuvi tizim dialogisiz beriladigan holat uchun qisqa yo'riqnoma
  /// (Android 11+), so'ng ilova sozlamalarini ochadi.
  Future<void> _showAlwaysLocationHint() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12171E),
        title: Text(
          'permissionSetup.alwaysLocTitle'.tr(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'permissionSetup.alwaysLocBody'.tr(),
          style: GoogleFonts.poppins(
            color: PermColors.dim,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'permissionSetup.alwaysLocLater'.tr(),
              style: GoogleFonts.poppins(color: PermColors.dim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'permissionSetup.alwaysLocOpen'.tr(),
              style: GoogleFonts.poppins(
                color: PermColors.blueLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (proceed ?? false) await openAppSettings();
  }

  // Majburiy ruxsatlar: joylashuv/foydalanish/overlay/batareya + BILDIRISHNOMA.
  // Bildirishnoma 2026-08-10 dan majburiy: Google Play "Stalkerware/Monitoring"
  // siyosati monitoring ilovadan doimiy KO'RINIB turadigan bildirishnomani
  // talab qiladi — Android 13+ da POST_NOTIFICATIONS rad etilsa foreground
  // bildirishnoma status-barda chiqmaydi va talab amalda buziladi. Qamalib
  // qolish yo'q: _requestNotif isPermanentlyDenied'da openAppSettings ochadi.
  // "O'chirishni taqiqlash" (Device Admin) IXTIYORIY bo'lib qoladi.
  bool get _allGranted =>
      _location && _usage && _overlay && _battery && _notif;

  void _onNext() {
    if (!kIsWeb && !_allGranted) return;
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
                  // Figma: sarlavha tepadan aniq pastroqda boshlanadi.
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
                    'permissionSetup.subtitle'.tr(),
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
                        PermSectionLabel('permissionSetup.groupMain'.tr()),
                        const SizedBox(height: 10),
                        PermGroupCard(
                          rows: [
                            PermRow(
                              icon: Icons.location_on_rounded,
                              title: 'permissionSetup.locName'.tr(),
                              value: _location,
                              onChanged: () => _toggle(
                                current: _location,
                                request: _requestLocation,
                                setMock: (b) => _location = b,
                              ),
                            ),
                            PermRow(
                              icon: Icons.notifications_rounded,
                              title: 'permissionSetup.notifName'.tr(),
                              value: _notif,
                              onChanged: () => _toggle(
                                current: _notif,
                                request: _requestNotif,
                                setMock: (b) => _notif = b,
                              ),
                            ),
                            PermRow(
                              icon: Icons.insights_rounded,
                              title: 'permissionSetup.usageName'.tr(),
                              value: _usage,
                              onChanged: () => _toggle(
                                current: _usage,
                                request: _svc.openSettings,
                                setMock: (b) => _usage = b,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        PermSectionLabel('permissionSetup.groupHelper'.tr()),
                        const SizedBox(height: 10),
                        PermGroupCard(
                          rows: [
                            PermRow(
                              icon: Icons.layers_rounded,
                              title: 'permissionSetup.overlayName'.tr(),
                              value: _overlay,
                              onChanged: () => _toggle(
                                current: _overlay,
                                request: _svc.openOverlaySettings,
                                setMock: (b) => _overlay = b,
                              ),
                            ),
                            PermRow(
                              icon: Icons.battery_charging_full_rounded,
                              title: 'permissionSetup.batteryName'.tr(),
                              value: _battery,
                              onChanged: () => _toggle(
                                current: _battery,
                                request: Permission
                                    .ignoreBatteryOptimizations
                                    .request,
                                setMock: (b) => _battery = b,
                              ),
                            ),
                            // O'chirishni taqiqlash — Device Admin. Yoqilsa
                            // bola ilovani ota-ona ruxsatisiz o'chira olmaydi.
                            PermRow(
                              icon: Icons.shield_rounded,
                              title: 'permissionSetup.uninstallProtectionName'
                                  .tr(),
                              value: _uninstallGuard,
                              onChanged: () => _toggle(
                                current: _uninstallGuard,
                                request: uninstallProtectionService
                                    .requestActivation,
                                setMock: (b) => _uninstallGuard = b,
                              ),
                            ),
                            // ⏸️ "Tez bloklash" (AccessibilityService) qatori
                            // VAQTINCHA OLIB TASHLANDI — qarang initState
                            // ustidagi izoh.
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  PermNextButton(
                    enabled: kIsWeb || _allGranted,
                    onTap: _onNext,
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

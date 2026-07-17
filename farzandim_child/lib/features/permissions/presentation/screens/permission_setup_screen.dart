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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

// ════════════ Parvoz tokenlar (lokal, ko'k) ════════════
const _bg = Color(0xFF02060D);
const _blue = Color(0xFF216BFF);
const _blueLight = Color(0xFF3C82FF);
const _green = Color(0xFF34C759);
const _dim = Color(0x99FFFFFF);

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

  // Bildirishnoma ruxsati — doimiy rad etilgan bo'lsa tizim sozlamalariga
  // yo'naltiramiz (aks holda tugma abadiy o'chiq qolib, foydalanuvchi qamaladi).
  Future<void> _requestNotif() async {
    final s = await Permission.notification.request();
    if (s.isPermanentlyDenied) await openAppSettings();
  }

  Future<void> _requestLocation() async {
    final w = await Permission.locationWhenInUse.request();
    if (w.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    if (w.isGranted) await Permission.locationAlways.request();
  }

  bool get _allGranted =>
      _location && _notif && _usage && _overlay && _battery && _uninstallGuard;

  void _onNext() {
    if (!kIsWeb && !_allGranted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned(
            top: -150,
            right: -60,
            child: IgnorePointer(child: _CornerGlow()),
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
                      color: _dim,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _SectionLabel('permissionSetup.groupMain'.tr()),
                        const SizedBox(height: 10),
                        _GroupCard(
                          rows: [
                            _PermRow(
                              icon: Icons.location_on_rounded,
                              title: 'permissionSetup.locName'.tr(),
                              value: _location,
                              onChanged: () => _toggle(
                                current: _location,
                                request: _requestLocation,
                                setMock: (b) => _location = b,
                              ),
                            ),
                            _PermRow(
                              icon: Icons.notifications_rounded,
                              title: 'permissionSetup.notifName'.tr(),
                              value: _notif,
                              onChanged: () => _toggle(
                                current: _notif,
                                request: _requestNotif,
                                setMock: (b) => _notif = b,
                              ),
                            ),
                            _PermRow(
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
                        _SectionLabel('permissionSetup.groupHelper'.tr()),
                        const SizedBox(height: 10),
                        _GroupCard(
                          rows: [
                            _PermRow(
                              icon: Icons.layers_rounded,
                              title: 'permissionSetup.overlayName'.tr(),
                              value: _overlay,
                              onChanged: () => _toggle(
                                current: _overlay,
                                request: _svc.openOverlaySettings,
                                setMock: (b) => _overlay = b,
                              ),
                            ),
                            _PermRow(
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
                            _PermRow(
                              icon: Icons.shield_rounded,
                              title: "O'chirishni taqiqlash",
                              value: _uninstallGuard,
                              onChanged: () => _toggle(
                                current: _uninstallGuard,
                                request: uninstallProtectionService
                                    .requestActivation,
                                setMock: (b) => _uninstallGuard = b,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  _NextButton(enabled: kIsWeb || _allGranted, onTap: _onNext),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Bo'lim sarlavhasi ════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xCCFFFFFF),
        ),
      ),
    );
  }
}

// ════════════ Guruh kartasi (shisha) ════════════
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(
          const Divider(
            height: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: Color(0x14FFFFFF),
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
        ),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(children: children),
    );
  }
}

// ════════════ Bitta ruxsat qatori ════════════
class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF12171E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Toggle(value: value, onTap: onChanged),
        ],
      ),
    );
  }
}

// ════════════ Yashil toggle ════════════
class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onTap});
  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? _green : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════ "Keyingisi" tugma (ko'k) ════════════
class _NextButton extends StatelessWidget {
  const _NextButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_blueLight, _blue],
            ),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'permissionSetup.next'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Burchak ko'k yog'du ════════════
class _CornerGlow extends StatelessWidget {
  const _CornerGlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x40216BFF), Color(0x00216BFF)],
          stops: [0, 0.7],
        ),
      ),
    );
  }
}

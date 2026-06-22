// ─────────────────────────────────────────────────────────────────────
// PermissionSetupScreen — Pair'dan keyingi ruxsat yig'ish ekrani
// ─────────────────────────────────────────────────────────────────────
//
// FAQAT 4 ta ENG ZARUR ruxsat (avval 10 ta edi — juda ko'p edi). Qolgan
// ixtiyoriy ruxsatlar (geolokatsiya, mikrofon, OEM autostart va h.k.)
// kerak bo'lsa keyin Sozlamalar → Ruxsatlar ekranidan beriladi.
//   1.  POST_NOTIFICATIONS                       — Bildirishnomalar (FCM)
//   2.  PACKAGE_USAGE_STATS                      — Ilova nazorati
//   3.  SYSTEM_ALERT_WINDOW (overlay)            — Bloklash ekranini ko'rsatish
//   4.  ignoreBatteryOptimizations               — Xizmat tirik qolishi
//
// Lifecycle resume → recheck (sistema sozlamalaridan qaytgach).
// Web preview'da Android API'lar UnimplementedError beradi —
// har biri try/catch bilan o'ralib mock 'false' qaytaradi.
// "Keyingisi" tugma'si — 4 tasi yashil bo'lganida yashil rangda,
// aks holda kulrang/disabled. Web'da har doim enabled (mock holat).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/usage_stats_service.dart';
import 'package:farzandim_child/shared/widgets/parvoz_glass.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  final UsageStatsService _usage = UsageStatsService();

  // ─── Toggle holatlari (faqat 4 ta eng zarur) ──────────────────────
  bool _notif = false; // 1 — POST_NOTIFICATIONS
  bool _usageStats = false; // 2 — PACKAGE_USAGE_STATS (ilova nazorati)
  bool _overlay = false; // 3 — SYSTEM_ALERT_WINDOW (bloklash ekrani)
  bool _battery = false; // 4 — ignoreBatteryOptimizations (xizmat tirik)

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
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
  }

  Future<bool> _safeStatus(Future<PermissionStatus> Function() fn) async {
    try {
      final s = await fn();
      return s.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkAll() async {
    if (_checking) return;
    if (kIsWeb) {
      // Web'da permission_handler UnimplementedError tashlaydi — saqlab
      // qo'yilgan toggle holatini buzmaslik uchun shu yerda qaytamiz.
      return;
    }
    setState(() => _checking = true);

    final overlay = await _safe(_usage.hasOverlayPermission);
    final batt =
        await _safeStatus(() => Permission.ignoreBatteryOptimizations.status);
    final usage = await _safe(_usage.hasPermission);
    final notif = await _safeStatus(() => Permission.notification.status);

    if (!mounted) return;
    setState(() {
      _overlay = overlay;
      _battery = batt;
      _usageStats = usage;
      _notif = notif;
      _checking = false;
    });
  }

  Future<bool> _safe(Future<bool> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return false;
    }
  }

  // ─── Per-permission request handler'lar ─────────────────────────────
  Future<void> _toggle({
    required bool current,
    required Future<void> Function() request,
    required void Function(bool) setMock,
  }) async {
    if (kIsWeb) {
      // Web preview — mock toggle (haqiqiy permission API yo'q).
      setState(() => setMock(!current));
      return;
    }
    try {
      await request();
    } catch (_) {
      /* sistemali sozlama ochilmasa jim */
    }
    await _checkAll();
  }

  bool get _allGranted => _notif && _usageStats && _overlay && _battery;

  void _onNext() {
    // Mobile'da hammasi yoqilmasa tugma disabled — bu yerda safety check.
    if (!kIsWeb && !_allGranted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parvozBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // 1 — Bildirishnoma (FCM)
                    _PermissionCard(
                      title: 'permissionSetup.p_notif'.tr(),
                      value: _notif,
                      onChanged: (v) => _toggle(
                        current: _notif,
                        request: () => Permission.notification.request(),
                        setMock: (b) => _notif = b,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 2 — Ilova nazorati (usage stats)
                    _PermissionCard(
                      title: 'permissionSetup.p_usage'.tr(),
                      value: _usageStats,
                      onChanged: (v) => _toggle(
                        current: _usageStats,
                        request: () => _usage.openSettings(),
                        setMock: (b) => _usageStats = b,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 3 — Ilova ustida ko'rsatish (overlay → bloklash ekrani)
                    _PermissionCard(
                      title: 'permissionSetup.p_overlay'.tr(),
                      hint: 'permissionSetup.p_overlayHint'.tr(),
                      value: _overlay,
                      onChanged: (v) => _toggle(
                        current: _overlay,
                        request: () => _usage.openOverlaySettings(),
                        setMock: (b) => _overlay = b,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 4 — Quvvat optimizatsiyasi (xizmat tirik qolishi)
                    _PermissionCard(
                      title: 'permissionSetup.p_battery'.tr(),
                      value: _battery,
                      onChanged: (v) => _toggle(
                        current: _battery,
                        request: () =>
                            Permission.ignoreBatteryOptimizations.request(),
                        setMock: (b) => _battery = b,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _buildNextButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Device name — device_info_plus dan o'qib ko'rsatish mumkin,
    // hozircha ringtone-safe placeholder.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Xiaomi-23110NRD0DA',
            style: TextStyle(
              color: AppColors.parvozTextDim,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'permissionSetup.title'.tr(),
          style: const TextStyle(
            color: AppColors.parvozText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    // Web preview'da har doim enabled — chunki permission API yo'q.
    // Mobile'da hammasi yoqilmaguncha disabled (kulrang).
    final enabled = kIsWeb ? true : _allGranted;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? _onNext : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.parvozGreen,
          disabledBackgroundColor: AppColors.parvozSurfaceHigh,
          foregroundColor: AppColors.parvozOnGreen,
          disabledForegroundColor: AppColors.parvozTextDim,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'permissionSetup.next'.tr(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Yagona ruxsat kartasi ─────────────────────────────────────────────
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String title;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: parvozGlassFlat(radius: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.parvozText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    style: const TextStyle(
                      color: AppColors.parvozTextDim,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Custom iOS-style toggle — Material Switch ranglarini
          // material 3 inconsistent qiladi, shu sabab custom yozildi.
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value
                    ? AppColors.parvozGreen
                    : AppColors.parvozSurfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: value
                      ? AppColors.parvozGreen
                      : AppColors.parvozBorderStrong,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? AppColors.parvozOnGreen : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ChildSettingsScreen — "Bola sozlamalari" (nazorat hub, Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard'dagi "Bola sozlamalari" kartasidan ochiladi. Profil kartasi +
// nazorat menyulari:
//   • Manzillar               → geo-zonalar ro'yxati
//   • Ilovalarni bloklash      → showBlockAppsSheet (tortiladigan varaq)
//   • Kunlik vaqt limiti       → showDailyLimitSheet
//   • Rejimlar                 → showRejimlarSheet
//   • Notanish manbaalar       → inline toggle (blockUnknownSources)
//
// Widgetlar `controls_setup_screen`dagilar bilan bir xil uslubda (nusxa) —
// dizayn birligi uchun.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/block_apps_screen.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/daily_limit_sheet.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/repositories/backend_child_repository.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/geo_zones/presentation/providers/geo_zones_provider.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/features/schedules/presentation/screens/rejimlar_sheet.dart';
import 'package:farzandim/features/settings/presentation/plan_gate.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (controls_setup bilan bir xil) ════════════
const _bg = Color(0xFF00060A);
const _green = Color(0xFF34C759); // toggle ON
const _card = Color(0xFF12171E); // karta foni
const _chipBg = Color(0xFF1B2128); // ikon doirasi
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

IconData _batteryIcon(int level) {
  if (level >= 60) return SolarIconsBold.batteryFull;
  return SolarIconsBold.batteryHalf;
}

/// Bola sozlamalari hub ekrani.
class ChildSettingsScreen extends ConsumerWidget {
  /// `ChildSettingsScreen` konstruktor.
  const ChildSettingsScreen({
    required this.childId,
    this.initialChild,
    super.key,
  });

  /// Bola id'si (marshrut path parametri).
  final String childId;

  /// `state.extra` orqali kelgan Child — provider race'ni chetlash uchun.
  final Child? initialChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId)) ?? initialChild;

    // Real sanoqlar (sub-matnlar uchun).
    final restrictions = ref.watch(restrictionsProvider(childId)).valueOrNull;
    final blockedCount = restrictions == null
        ? 0
        : restrictions.where((r) => r.isBlocked).length;
    final limitCount = restrictions == null
        ? 0
        : restrictions.where((r) => !r.isBlocked && r.limitMinutes > 0).length;
    final scheduleCount =
        ref.watch(schedulesProvider(childId)).valueOrNull?.length ?? 0;
    final zoneCount =
        ref.watch(geoZonesProvider(childId)).valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: orqaga + sarlavha ──
            Padding(
              // Tepa chetga yopishmasin — status-bar balandligicha pastroq
              // (web/emulyatorda SafeArea top=0, shuning uchun aniq bo'shliq).
              padding: const EdgeInsets.fromLTRB(20, 54, 20, 12),
              child: Row(
                children: [
                  _BackButton(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.dashboard);
                      }
                    },
                  ),
                  const SizedBox(width: 14),
                  Text('childSettings.headerTitle'.tr(), style: _unb(22)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  // ── Profil kartasi ──
                  if (child != null)
                    _ProfileCard(
                      child: child,
                      onEdit: () => context.push(
                        AppRoutes.editChildPath(child.id),
                        extra: child,
                      ),
                    ),
                  if (child != null) const SizedBox(height: 14),

                  // ── Manzillar ──
                  _NavCard(
                    icon: SolarIconsBold.map,
                    title: 'geoZones.headerTitle'.tr(),
                    subtitle: zoneCount == 0
                        ? 'childSettings.noZones'.tr()
                        : 'childSettings.zonesCount'.tr(
                            namedArgs: {'count': '$zoneCount'},
                          ),
                    onTap: () => guardPaid(
                      context,
                      ref,
                      onAllowed: () =>
                          context.push(AppRoutes.geoZonesPath(childId)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Ilovalarni bloklash ──
                  _NavCard(
                    icon: SolarIconsBold.widget_3,
                    title: 'controlsSetup.blockApps.title'.tr(),
                    subtitle: blockedCount == 0
                        ? 'controlsSetup.blockApps.empty'.tr()
                        : 'controlsSetup.blockApps.count'.tr(
                            namedArgs: {'count': '$blockedCount'},
                          ),
                    onTap: () => guardPaid(
                      context,
                      ref,
                      onAllowed: () =>
                          showBlockAppsSheet(context, childId: childId),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Kunlik vaqt limiti ──
                  _NavCard(
                    svgAsset: 'assets/icons/ic_clock_duotone.svg',
                    title: 'controlsSetup.timeLimit.title'.tr(),
                    subtitle: limitCount == 0
                        ? 'controlsSetup.timeLimit.empty'.tr()
                        : 'controlsSetup.timeLimit.count'.tr(
                            namedArgs: {'count': '$limitCount'},
                          ),
                    onTap: () => guardPaid(
                      context,
                      ref,
                      onAllowed: () =>
                          showDailyLimitSheet(context, childId: childId),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Rejimlar ──
                  _NavCard(
                    icon: SolarIconsBold.sortByTime,
                    title: 'controlsSetup.schedules.title'.tr(),
                    subtitle: scheduleCount == 0
                        ? 'controlsSetup.schedules.empty'.tr()
                        : 'controlsSetup.schedules.count'.tr(
                            namedArgs: {'count': '$scheduleCount'},
                          ),
                    onTap: () => guardPaid(
                      context,
                      ref,
                      onAllowed: () =>
                          showRejimlarSheet(context, childId: childId),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Notanish manbaalar (toggle) ──
                  _UnknownSourcesCard(
                    childId: childId,
                    initialValue: child?.blockUnknownSources ?? false,
                  ),
                  const SizedBox(height: 8),

                  // ── O'chirishni taqiqlash (Device Admin toggle) ──
                  _UninstallProtectionCard(
                    childId: childId,
                    initialValue: child?.blockUninstall ?? false,
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

// ════════════ Orqaga tugmasi ════════════

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _fieldBorder),
        ),
        child: const Icon(
          SolarIconsOutline.arrowLeft,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ════════════ Profil kartasi ════════════

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child, required this.onEdit});

  final Child child;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final battery = child.deviceInfo?.batteryLevel;
    final rawDevice = (child.deviceModel?.isNotEmpty ?? false)
        ? child.deviceModel!
        : (child.deviceInfo?.deviceModel ?? '');
    final clean = rawDevice.trim();
    // "null null" kabi buzuq qiymatlarni yashiramiz.
    final device = (clean.isEmpty || clean.toLowerCase().contains('null'))
        ? '—'
        : clean;
    return _CardShell(
      child: Row(
        children: [
          ChildAvatar(child: child, size: 52, showBorder: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(18, ls: -0.3),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(13, c: _dim),
                      ),
                    ),
                    if (battery != null) ...[
                      const SizedBox(width: 6),
                      Text('•', style: _pop(13, c: _dim)),
                      const SizedBox(width: 6),
                      Icon(_batteryIcon(battery), size: 15, color: _dim),
                      const SizedBox(width: 3),
                      Text('$battery%', style: _pop(13, c: _dim)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: const Icon(
              SolarIconsOutline.pen,
              size: 22,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════ Umumiy karta / ikon widgetlari ════════════

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _fieldBorder),
        ),
        child: child,
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({this.icon, this.svgAsset})
    : assert(
        icon != null || svgAsset != null,
        'icon yoki svgAsset berilishi shart',
      );

  /// Font-ikon (Solar). `svgAsset` berilsa e'tiborsiz qoldiriladi.
  final IconData? icon;

  /// SVG asset yo'li — duotone kabi font paketda yo'q ikonlar uchun.
  final String? svgAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _chipBg, shape: BoxShape.circle),
      child: svgAsset != null
          ? SvgPicture.asset(svgAsset!, width: 24, height: 24)
          : Icon(icon, size: 22, color: Colors.white),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.svgAsset,
  }) : assert(
         icon != null || svgAsset != null,
         'icon yoki svgAsset berilishi shart',
       );

  final IconData? icon;
  final String? svgAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: onTap,
      child: Row(
        children: [
          _IconChip(icon: icon, svgAsset: svgAsset),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(16, ls: -0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(13, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(SolarIconsOutline.altArrowRight, size: 20, color: _dim),
        ],
      ),
    );
  }
}

/// Notanish manbaalar — inline toggle (optimistik + xato'da qaytarish).
class _UnknownSourcesCard extends ConsumerStatefulWidget {
  const _UnknownSourcesCard({
    required this.childId,
    required this.initialValue,
  });

  final String childId;
  final bool initialValue;

  @override
  ConsumerState<_UnknownSourcesCard> createState() =>
      _UnknownSourcesCardState();
}

class _UnknownSourcesCardState extends ConsumerState<_UnknownSourcesCard> {
  late bool _blocked = widget.initialValue;
  bool _saving = false;

  @override
  void didUpdateWidget(_UnknownSourcesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && oldWidget.initialValue != widget.initialValue) {
      _blocked = widget.initialValue;
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    final previous = _blocked;
    setState(() {
      _blocked = value;
      _saving = true;
    });
    try {
      await ref
          .read(backendChildRepositoryProvider)
          .setBlockUnknownSources(widget.childId, value: value);
      ref.read(childrenRefreshTickProvider.notifier).state++;
    } catch (_) {
      if (mounted) {
        setState(() => _blocked = previous);
        AppToast.error(context, 'controlsSetup.unknownSources.errorSnack'.tr());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        children: [
          const _IconChip(icon: SolarIconsBold.questionCircle),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'controlsSetup.unknownSources.title'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(16, ls: -0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  'controlsSetup.unknownSources.subtitle'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(13, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppSwitch(
            value: _blocked,
            onChanged: _saving ? null : _onChanged,
            activeColor: _green,
          ),
        ],
      ),
    );
  }
}

/// O'chirishni taqiqlash — inline toggle (Device Admin). Yoqilsa bola
/// Farzandim'ni telefonidan o'chira olmaydi. Optimistik + xato'da qaytarish.
class _UninstallProtectionCard extends ConsumerStatefulWidget {
  const _UninstallProtectionCard({
    required this.childId,
    required this.initialValue,
  });

  final String childId;
  final bool initialValue;

  @override
  ConsumerState<_UninstallProtectionCard> createState() =>
      _UninstallProtectionCardState();
}

class _UninstallProtectionCardState
    extends ConsumerState<_UninstallProtectionCard> {
  late bool _blocked = widget.initialValue;
  bool _saving = false;

  @override
  void didUpdateWidget(_UninstallProtectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && oldWidget.initialValue != widget.initialValue) {
      _blocked = widget.initialValue;
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_saving) return;
    final previous = _blocked;
    setState(() {
      _blocked = value;
      _saving = true;
    });
    try {
      await ref
          .read(backendChildRepositoryProvider)
          .setBlockUninstall(widget.childId, value: value);
      ref.read(childrenRefreshTickProvider.notifier).state++;
    } catch (_) {
      if (mounted) {
        setState(() => _blocked = previous);
        AppToast.error(
          context,
          'childSettings.uninstallProtection.errorSnack'.tr(),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        children: [
          const _IconChip(icon: SolarIconsBold.shieldMinimalistic),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "O'chirishni taqiqlash",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(16, ls: -0.3),
                ),
                const SizedBox(height: 3),
                Text(
                  'childSettings.uninstallProtection.subtitle'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(13, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppSwitch(
            value: _blocked,
            onChanged: _saving ? null : _onChanged,
            activeColor: _green,
          ),
        ],
      ),
    );
  }
}

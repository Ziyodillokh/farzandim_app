// ─────────────────────────────────────────────────────────────────────
// ControlPolicyScreen — "Nazorat siyosati" (standalone hub, Parvoz dizayn)
// ─────────────────────────────────────────────────────────────────────
//
// Ekran vaqti sahifasidagi "Nazorat siyosati" tugmasidan ochiladi. Onboarding
// `ControlsSetupScreen`ning wizard-siz (qadam indikatori/Keyingisi tugmasisiz)
// varianti: orqaga tugma + sarlavha + AYNAN o'sha 4 nazorat kartasi. Kartalar
// uslubi `child_settings_screen`/`controls_setup_screen` bilan bir xil (nusxa)
// — dizayn birligi uchun.
//
//   1. Ilovalarni bloklash   → showBlockAppsSheet (tortiladigan varaq)
//   2. Kunlik vaqt limiti      → showDailyLimitSheet
//   3. Rejimlar                → showRejimlarSheet
//   4. Notanish manbaalar      → inline toggle (blockUnknownSources)

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/block_apps_screen.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/daily_limit_sheet.dart';
import 'package:farzandim/features/child_management/data/repositories/backend_child_repository.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/features/schedules/presentation/screens/rejimlar_sheet.dart';
import 'package:farzandim/features/settings/presentation/plan_gate.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (child_settings bilan bir xil) ════════════
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

/// "Nazorat siyosati" hub ekrani — 4 ta nazorat kartasi.
class ControlPolicyScreen extends ConsumerWidget {
  /// `ControlPolicyScreen` konstruktor.
  const ControlPolicyScreen({required this.childId, super.key});

  /// Bola id'si (marshrut path parametri).
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real sanoqlar (kartalar sub-matni uchun).
    final restrictions = ref.watch(restrictionsProvider(childId)).valueOrNull;
    final blockedCount = restrictions == null
        ? 0
        : restrictions.where((r) => r.isBlocked).length;
    final limitCount = restrictions == null
        ? 0
        : restrictions.where((r) => !r.isBlocked && r.limitMinutes > 0).length;
    final scheduleCount =
        ref.watch(schedulesProvider(childId)).valueOrNull?.length ?? 0;
    final child = ref.watch(childByIdProvider(childId));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: orqaga + sarlavha (child_settings bilan bir xil) ──
            Padding(
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
                  Text('dashboard.screenTimePolicy'.tr(), style: _unb(22)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
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
                  const SizedBox(height: 12),

                  // ── Kunlik vaqt limiti ──
                  _NavCard(
                    icon: SolarIconsOutline.clockCircle,
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
                  const SizedBox(height: 12),

                  // ── Rejimlar ──
                  _NavCard(
                    icon: SolarIconsOutline.sortByTime,
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
                  const SizedBox(height: 12),

                  // ── Notanish manbaalar (toggle) ──
                  _UnknownSourcesCard(
                    childId: childId,
                    initialValue: child?.blockUnknownSources ?? false,
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

// ════════════ Karta / ikon widgetlari ════════════

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(color: _chipBg, shape: BoxShape.circle),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }
}

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

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: onTap,
      child: Row(
        children: [
          _IconChip(icon: icon),
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
                  maxLines: 1,
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

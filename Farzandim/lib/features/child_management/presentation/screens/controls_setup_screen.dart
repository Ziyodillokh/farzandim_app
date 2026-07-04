// ─────────────────────────────────────────────────────────────────────
// ControlsSetupScreen — "Nazorat o'rnating" (Parvoz dizayn, wizard 2-qadam)
// ─────────────────────────────────────────────────────────────────────
//
// Bola qo'shilgandan keyin (oila kodidan oldin) ochiladi. Ota-ona shu yerda
// asosiy cheklovlarni sozlaydi:
//   1. Ilovalarni bloklash   → showBlockAppsSheet (tortiladigan varaq)
//   2. Kunlik vaqt limiti     → showDailyLimitSheet (tortiladigan varaq)
//   3. Rejimlar                → showRejimlarSheet (tortiladigan varaq)
//   4. Notanish manbaalar      → inline toggle (blockUnknownSources)
// Pastdagi "Keyingisi" → oila kodi (family-code) ekrani.
//
// Kartalar sub-matni real holatdan: bloklangan/limit/rejim sonlari
// `restrictionsProvider` / `schedulesProvider`'dan. Toggle device-policy
// setteri orqali (optimistik + xato'da qaytarish).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/block_apps_screen.dart';
import 'package:farzandim/features/app_restrictions/presentation/screens/daily_limit_sheet.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/data/repositories/backend_child_repository.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/features/schedules/presentation/screens/rejimlar_sheet.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Parvoz tokenlar (lokal — add_child bilan bir xil) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _green = Color(0xFF34C759); // toggle ON (notanish manbaalar)
const _card = Color(0xFF12171E); // nazorat kartasi foni
const _chipBg = Color(0xFF1B2128); // ikon doirasi
const _stepInactive = Color(0xFF1B2128);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _line = Color(0x1AFFFFFF); // qadam chizig'i (oq 10%)
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

/// Nazorat o'rnatish ekrani — bola qo'shilgandan keyingi 2-qadam.
class ControlsSetupScreen extends ConsumerWidget {
  /// `ControlsSetupScreen` konstruktor.
  const ControlsSetupScreen({
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
    // Real sanoqlar — yangi bolada hammasi bo'sh (0).
    final restrictions = ref.watch(restrictionsProvider(childId)).valueOrNull;
    final blockedCount = restrictions == null
        ? 0
        : restrictions.where((r) => r.isBlocked).length;
    final limitCount = restrictions == null
        ? 0
        : restrictions.where((r) => !r.isBlocked && r.limitMinutes > 0).length;
    final scheduleCount =
        ref.watch(schedulesProvider(childId)).valueOrNull?.length ?? 0;

    final child = ref.watch(childByIdProvider(childId)) ?? initialChild;

    final scaffold = Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned(
            top: -70,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: _Glow())),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const _StepIndicator(),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'controlsSetup.title'.tr(),
                              maxLines: 1,
                              style: _unb(28),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'controlsSetup.subtitle'.tr(),
                          style: _pop(14, c: _dim),
                        ),
                        const SizedBox(height: 28),
                        _NavCard(
                          icon: SolarIconsBold.widget_6,
                          title: 'controlsSetup.blockApps.title'.tr(),
                          subtitle: blockedCount == 0
                              ? 'controlsSetup.blockApps.empty'.tr()
                              : 'controlsSetup.blockApps.count'.tr(
                                  namedArgs: {'count': '$blockedCount'},
                                ),
                          onTap: () =>
                              showBlockAppsSheet(context, childId: childId),
                        ),
                        const SizedBox(height: 12),
                        _NavCard(
                          icon: SolarIconsOutline.clockCircle,
                          title: 'controlsSetup.timeLimit.title'.tr(),
                          subtitle: limitCount == 0
                              ? 'controlsSetup.timeLimit.empty'.tr()
                              : 'controlsSetup.timeLimit.count'.tr(
                                  namedArgs: {'count': '$limitCount'},
                                ),
                          onTap: () =>
                              showDailyLimitSheet(context, childId: childId),
                        ),
                        const SizedBox(height: 12),
                        _NavCard(
                          icon: SolarIconsOutline.sortByTime,
                          title: 'controlsSetup.schedules.title'.tr(),
                          subtitle: scheduleCount == 0
                              ? 'controlsSetup.schedules.empty'.tr()
                              : 'controlsSetup.schedules.count'.tr(
                                  namedArgs: {'count': '$scheduleCount'},
                                ),
                          onTap: () =>
                              showRejimlarSheet(context, childId: childId),
                        ),
                        const SizedBox(height: 12),
                        _UnknownSourcesCard(
                          childId: childId,
                          initialValue: child?.blockUnknownSources ?? false,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: _PrimaryButton(
                    label: 'controlsSetup.next'.tr(),
                    onTap: () {
                      // Keyingi qadam: manzillar (geo-zonalar) o'rnatish.
                      if (child != null) {
                        context.go(
                          AppRoutes.addressesSetupPath(child.id),
                          extra: child,
                        );
                      } else {
                        context.go(AppRoutes.addressesSetupPath(childId));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // Bu sahifa wizard qadami — orqaga tugmasi yo'q (rasmga mos), lekin
    // Android apparat "orqa" tugmasi ilovadan chiqarmasligi uchun
    // dashboard'ga qaytaramiz (go() stack'ni bo'shatgani sabab).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.dashboard);
      },
      child: scaffold,
    );
  }
}

// ════════════ Fon yog'dusi ════════════

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 280,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [_blue.withValues(alpha: 0.22), const Color(0x00216BFF)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

// ════════════ Qadam indikatori (2-qadam faol) ════════════

class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // 1-qadam bajarilgan (bola ma'lumotlari to'ldirilgan) — ko'k.
        _StepCircle(icon: SolarIconsBold.peopleNearby, completed: true),
        _StepLine(filled: true),
        _StepCircle(icon: SolarIconsBold.clipboardCheck, active: true),
        _StepLine(),
        _StepCircle(icon: SolarIconsBold.map),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.icon,
    this.active = false,
    this.completed = false,
  });

  final IconData icon;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    // Faol yoki bajarilgan qadam ko'k to'ldiriladi; yog'du faqat faolda.
    final filled = active || completed;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? _blue : _stepInactive,
        border: filled ? null : Border.all(color: _fieldBorder),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 24,
        color: filled ? Colors.white : Colors.white.withValues(alpha: 0.75),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({this.filled = false});

  /// Bajarilgan qadamlar orasidagi chiziq ko'k bo'ladi.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          height: 2,
          child: ColoredBox(color: filled ? _blue : _line),
        ),
      ),
    );
  }
}

// ════════════ Nazorat kartalari ════════════

/// Dumaloq ikon-chip — qora doira + oq Solar ikon.
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

/// Karta qobig'i — qora yumshoq quti (bosiladigan / statik).
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

/// Navigatsiya karta — ikon + sarlavha + sub-matn + o'ng chevron.
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
    // Backenddan yangi qiymat kelsa qayta urug'lantiramiz — lekin saqlash
    // davom etayotgan bo'lsa, foydalanuvchi tanlovi ustun.
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
      // invalidate emas — recompute (tick): ro'yxat bo'shab ketmaydi,
      // shu sabab toggle ON->OFF->ON miltillamaydi (children_provider docs).
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
                  maxLines: 1,
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

// ════════════ Primary tugma ════════════

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: _pop(16, w: FontWeight.w500)),
            const SizedBox(width: 10),
            const Icon(
              SolarIconsOutline.arrowRight,
              size: 18,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

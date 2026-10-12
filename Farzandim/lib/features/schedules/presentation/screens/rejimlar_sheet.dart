// ─────────────────────────────────────────────────────────────────────
// RejimlarSheet — "Rejimlar" (jadvallar, Parvoz tortiladigan sheet)
// ─────────────────────────────────────────────────────────────────────
//
// Pastdan chiqadigan modal sheet (tepaga tortilsa kengayadi, pastga
// tortilsa yopiladi). Bolaning HAMMA rejimlari ro'yxati: har karta —
// nom + bloklanadigan ilovalar xulosasi ("N ta ilova" yoki iPhone'da
// "iPhone ilovalari bloklanadi"), yoqish/o'chirish kaliti, "Sozlash" va
// o'chirish (tasdiq bilan). "Sozlash" aynan SHU rejimning `blockedApps`'ini
// tahrirlaydi (rejim vaqt oynasida bloklanadi; global 24/7 bloklash emas):
// Android → ilovalar tanlagichi, iPhone → "tanlangan ilovalarni bloklash"
// kaliti. "Saqlash" sheet'ni yopadi.
//
// Ma'lumot: `schedulesProvider(childId)`; harakatlar
// `scheduleActionsProvider` (updateSchedule / toggleActive / deleteSchedule).

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/schedules/data/models/ios_routine_rules.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/features/schedules/presentation/screens/add_rejim_sheet.dart';
import 'package:farzandim/features/schedules/presentation/widgets/routine_apps_editor.dart';
import 'package:farzandim/shared/widgets/app_switch.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF12171E);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%
const _green = Color(0xFF34C759); // toggle ON
const _danger = Color(0xFFFF5A5D);

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.3,
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

/// "Rejimlar"ni tortiladigan modal sheet sifatida ochadi.
void showRejimlarSheet(BuildContext context, {required String childId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _RejimlarSheet(childId: childId),
  );
}

/// Drag qobig'i — tepaga/pastga tortiladi, minimumga yaqin tortilsa yopiladi.
class _RejimlarSheet extends StatefulWidget {
  const _RejimlarSheet({required this.childId});

  final String childId;

  @override
  State<_RejimlarSheet> createState() => _RejimlarSheetState();
}

class _RejimlarSheetState extends State<_RejimlarSheet> {
  bool _opened = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _opened = true);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        if (n.extent >= 0.85) _opened = true;
        if (_opened && !_dismissing && n.extent <= 0.46) {
          _dismissing = true;
          Navigator.of(context).maybePop();
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.45,
        maxChildSize: 0.96,
        snap: true,
        snapSizes: const [0.9],
        expand: false,
        builder: (ctx, scrollController) => _RejimlarBody(
          childId: widget.childId,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

// ════════════ Sheet mazmuni ════════════

class _RejimlarBody extends ConsumerWidget {
  const _RejimlarBody({required this.childId, required this.scrollController});

  final String childId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(schedulesProvider(childId)).valueOrNull ?? const [];
    final isIos = ref.watch(
      childByIdProvider(childId).select((c) => c?.isIosDevice ?? false),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'rejimlar.title'.tr(),
                textAlign: TextAlign.center,
                style: _unb(18, w: FontWeight.w700, ls: -0.4),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final s in all) ...[
                      _ScheduleCard(
                        key: ValueKey(s.id),
                        childId: childId,
                        schedule: s,
                        isIos: isIos,
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                    _AddButton(
                      onTap: () => showAddRejimSheet(context, childId: childId),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _SaveButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Rejim kartasi ════════════

/// Bitta rejim kartasi: nom + ilovalar xulosasi + yoqish kaliti, pastda
/// "Sozlash" va o'chirish. Kalit optimistik (xatoda qaytariladi).
class _ScheduleCard extends ConsumerStatefulWidget {
  const _ScheduleCard({
    required this.childId,
    required this.schedule,
    required this.isIos,
    super.key,
  });

  final String childId;
  final Schedule schedule;
  final bool isIos;

  @override
  ConsumerState<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<_ScheduleCard> {
  late bool _active = widget.schedule.isActive;
  bool _toggling = false;

  @override
  void didUpdateWidget(_ScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_toggling && oldWidget.schedule.isActive != widget.schedule.isActive) {
      _active = widget.schedule.isActive;
    }
  }

  String get _label => widget.schedule.title.isNotEmpty
      ? widget.schedule.title
      : widget.schedule.type.label;

  /// "N ta ilova" yoki iPhone'da "iPhone ilovalari bloklanadi".
  String get _subtitle {
    final apps = widget.schedule.blockedApps;
    if (widget.isIos) {
      return routineBlocksIosApps(apps)
          ? 'rejimlar.iosAppsBlocked'.tr()
          : 'rejimlar.iosAppsNotBlocked'.tr();
    }
    return 'rejimlar.appsCount'.tr(namedArgs: {'count': '${apps.length}'});
  }

  Future<void> _onToggle(bool value) async {
    if (_toggling) return;
    final previous = _active;
    setState(() {
      _active = value;
      _toggling = true;
    });
    final result = await ref
        .read(scheduleActionsProvider.notifier)
        .toggleActive(
          childId: widget.childId,
          scheduleId: widget.schedule.id,
          current: widget.schedule,
          isActive: value,
        );
    if (!mounted) return;
    setState(() {
      _toggling = false;
      if (!result.isSuccess) _active = previous;
    });
    if (!result.isSuccess) {
      AppToast.error(context, 'errors.generic'.tr());
    }
  }

  Future<void> _onConfigure() => editRoutineApps(
    context,
    ref,
    childId: widget.childId,
    schedule: widget.schedule,
    isIos: widget.isIos,
  );

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('rejimlar.deleteTitle'.tr(), style: _unb(18)),
        content: Text(
          'rejimlar.deleteContent'.tr(namedArgs: {'name': _label}),
          style: _pop(14, c: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr(), style: _pop(14)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'common.delete'.tr(),
              style: _pop(14, w: FontWeight.w600, c: _danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(scheduleActionsProvider.notifier)
        .deleteSchedule(
          childId: widget.childId,
          scheduleId: widget.schedule.id,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      AppToast.success(context, 'rejimlar.deleted'.tr());
    } else {
      AppToast.error(context, 'errors.generic'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _unb(16),
                    ),
                    const SizedBox(height: 3),
                    Text(_subtitle, style: _pop(13, c: _dim)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppSwitch(
                value: _active,
                onChanged: _toggling ? null : _onToggle,
                activeColor: _green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SozlashButton(onTap: _onConfigure)),
              const SizedBox(width: 10),
              _DeleteButton(onTap: _onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ixcham shisha "Sozlash" tugmasi (secondary).
class _SozlashButton extends StatelessWidget {
  const _SozlashButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 42,
        child: ParvozGlass(
          height: 42,
          child: Text(
            'rejimlar.configure'.tr(),
            style: _pop(13, w: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// O'chirish tugmasi (qizil chiziqli yumaloq) — tasdiq dialogini ochadi.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _danger.withValues(alpha: 0.5)),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          size: 20,
          color: _danger,
        ),
      ),
    );
  }
}

/// "+ Rejim qo'shish +" — markazlashgan, ikki yonida plus.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'rejimlar.addSchedule'.tr(),
              style: _pop(15, w: FontWeight.w500),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.add_rounded, size: 20, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ════════════ Saqlash tugmasi ════════════

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: true,
        child: Text('rejimlar.save'.tr(), style: _pop(16, w: FontWeight.w500)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// RejimlarSheet — "Rejimlar" (jadvallar, Parvoz tortiladigan sheet)
// ─────────────────────────────────────────────────────────────────────
//
// Pastdan chiqadigan modal sheet (tepaga tortilsa kengayadi, pastga
// tortilsa yopiladi). Ikki rejim: "Uyqu vaqti" (sleep) va "Maktab vaqti"
// (school) — har biri "N ta ilova" + "Sozlash" shisha tugma. Sozlash
// mavjud (ishlayotgan) jadval editoriga olib boradi. "Rejim qo'shish"
// hozircha "Tez kunda". "Saqlash" sheet'ni yopadi.
//
// Ma'lumot: `schedulesProvider(childId)` — type bo'yicha sleep/school
// topiladi; sanoq = `schedule.blockedApps.length`.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/schedules/data/models/schedule.dart';
import 'package:farzandim/features/schedules/presentation/providers/schedule_providers.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _card = Color(0xFF12171E);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%

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

  Schedule? _byType(List<Schedule> all, ScheduleType type) {
    for (final s in all) {
      if (s.type == type) return s;
    }
    return null;
  }

  void _openEditor(BuildContext context) {
    // Avval sheet'ni yopamiz, keyin editorga o'tamiz (sos_alert_dialog
    // pattern) — modal stack'da osilib qolmasin, orqaga to'g'ri ishlasin.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRoutes.schedulesPath(childId));
  }

  void _comingSoon(BuildContext context) =>
      AppToast.info(context, 'dashboard.comingSoon'.tr());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(schedulesProvider(childId)).valueOrNull ?? const [];
    final sleep = _byType(all, ScheduleType.sleep);
    final school = _byType(all, ScheduleType.school);

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
                    _ScheduleCard(
                      label: 'rejimlar.sleepTitle'.tr(),
                      appCount: sleep?.blockedApps.length ?? 0,
                      onConfigure: () => _openEditor(context),
                    ),
                    const SizedBox(height: 10),
                    _ScheduleCard(
                      label: 'rejimlar.schoolTitle'.tr(),
                      appCount: school?.blockedApps.length ?? 0,
                      onConfigure: () => _openEditor(context),
                    ),
                    const SizedBox(height: 18),
                    _AddButton(onTap: () => _comingSoon(context)),
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.label,
    required this.appCount,
    required this.onConfigure,
  });

  final String label;
  final int appCount;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _unb(16),
                ),
                const SizedBox(height: 3),
                Text(
                  'rejimlar.appsCount'.tr(namedArgs: {'count': '$appCount'}),
                  style: _pop(13, c: _dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SozlashButton(onTap: onConfigure),
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
        width: 104,
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

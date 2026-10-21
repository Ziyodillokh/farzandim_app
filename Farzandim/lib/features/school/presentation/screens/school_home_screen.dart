// ─────────────────────────────────────────────────────────────────────
// SchoolHomeScreen — "Maktab" (Parvoz School, ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// Sozlamalardagi "Maktab" qatori va dashboard kartasidan ochiladi.
//   - bog'lanish yo'q → taklif kodi CTA;
//   - har maktab kartasi: logo, o'quvchilar (bugungi holat, farzandga
//     moslash) va aloqani uzish (tasdiqlash oynasi bilan);
//   - bo'limlar: E'lonlar (o'qilmaganlar soni), Davomat, Erta ketish,
//     To'lovlar;
//   - pull-to-refresh: ro'yxat, davomat va o'qilmaganlar soni;
//   - `?remind=<studentId>` (push `SCHOOL_MODE_REMIND`) — ro'yxat kelgach
//     School Mode yo'l-yo'rig'i bir marta ochiladi.
// Backend'da bo'lim yo'q (404 `code`siz) → "hozircha mavjud emas".

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_announcement_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_refresh.dart';
import 'package:farzandim/features/school/presentation/widgets/school_link_card.dart';
import 'package:farzandim/features/school/presentation/widgets/school_mode_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/features/school/presentation/widgets/student_child_match_sheet.dart';
import 'package:farzandim/features/settings/presentation/plan_gate.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _chipBg = Color(0xFF1B2128);
const _sheetBg = Color(0xFF0B1016);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%
const _danger = Color(0xFFFF5A5D);

/// Tortib yangilashda spinner shundan ortiq aylanmaydi.
const Duration _refreshTimeout = Duration(seconds: 8);

TextStyle _unb(double size) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: Colors.white,
  letterSpacing: -0.4,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Maktab bosh sahifasi.
class SchoolHomeScreen extends ConsumerStatefulWidget {
  const SchoolHomeScreen({this.remindStudentId, super.key});

  /// School Mode eslatmasidagi o'quvchi (`?remind=`).
  final String? remindStudentId;

  @override
  ConsumerState<SchoolHomeScreen> createState() => _SchoolHomeScreenState();
}

class _SchoolHomeScreenState extends ConsumerState<SchoolHomeScreen> {
  /// Aloqasi uzilayotgan vasiy yozuvi (tugmada spinner).
  String? _unlinkingId;

  bool _remindHandled = false;

  @override
  void initState() {
    super.initState();
    final studentId = widget.remindStudentId?.trim() ?? '';
    if (studentId.isEmpty) return;
    ref.listenManual<AsyncValue<SchoolLinks>>(
      schoolLinksProvider,
      (_, next) => _remind(next, studentId),
      fireImmediately: true,
    );
  }

  /// Yangi ro'yxat kelgach bir marta — School Mode yo'l-yo'rig'i.
  void _remind(AsyncValue<SchoolLinks> next, String studentId) {
    final links = next.valueOrNull;
    if (_remindHandled || next.isLoading || links == null) return;
    _remindHandled = true;
    if (!links.available) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showSchoolModeGuidance(
          context,
          ref,
          links: links,
          studentId: studentId,
        ),
      );
    });
  }

  Future<void> _refresh() async {
    invalidateSchoolData(ref.invalidate);
    try {
      await ref.read(schoolLinksProvider.future).timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ro'yxat o'zi yangilanadi.
    } on Object catch (e) {
      // Oldingi ro'yxat ekranda qoladi — sababini qisqa xabar bilan aytamiz.
      if (!mounted) return;
      AppToast.error(context, SchoolFailure.fromError(e).messageKey.tr());
    }
  }

  void _openLink() => unawaited(context.push(AppRoutes.schoolLink));

  void _openStudent(LinkedStudent student) =>
      unawaited(context.push(AppRoutes.schoolAttendancePath(student.id)));

  Future<void> _openMatch(SchoolLinks links, LinkedStudent student) async {
    final addChild = await showStudentChildMatchSheet(
      context,
      links: links,
      studentIds: [student.id],
    );
    // Farzand yo'q — avval bola qo'shiladi (tarif limiti ham tekshiriladi).
    if (addChild && mounted) guardAddChild(context, ref);
  }

  /// Bitta o'quvchi bo'lsa — darhol uning davomati; bir nechta — tanlash.
  Future<void> _openAttendance(List<LinkedStudent> students) async {
    if (students.isEmpty) return;
    final student = students.length == 1
        ? students.single
        : await _pickStudent(students);
    if (student == null || !mounted) return;
    _openStudent(student);
  }

  Future<LinkedStudent?> _pickStudent(List<LinkedStudent> students) {
    return showModalBottomSheet<LinkedStudent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _sheetBg,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _StudentPicker(
        students: students,
        onPick: (student) => Navigator.of(sheetContext).pop(student),
      ),
    );
  }

  Future<void> _confirmUnlink(SchoolLink link) async {
    if (_unlinkingId != null) return;
    // Notifier await'dan OLDIN olinadi — sahifa yopilsa ham `ref` kerak emas.
    final actions = ref.read(schoolActionsProvider.notifier);
    final schoolName = link.school.displayName.isEmpty
        ? 'school.title'.tr()
        : link.school.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _cardBorder),
        ),
        title: Text('school.home.unlinkTitle'.tr(), style: _unb(17)),
        content: Text(
          'school.home.unlinkBody'.tr(namedArgs: {'school': schoolName}),
          style: _pop(14, c: _dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.cancel'.tr(), style: _pop(15, c: _dim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'school.home.unlinkConfirm'.tr(),
              style: _pop(15, w: FontWeight.w600, c: _danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unlinkingId = link.guardianId);
    final result = await actions.unlink(link.guardianId);
    if (!mounted) return;
    setState(() => _unlinkingId = null);
    if (result.isSuccess) {
      AppToast.success(context, 'school.home.unlinked'.tr());
    } else {
      AppToast.error(context, result.error ?? 'errors.generic'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(schoolLinksProvider);
    final links = async.valueOrNull;

    final Widget body;
    if (links == null) {
      body = async.hasError
          ? SchoolErrorView(
              error: async.error,
              onRetry: () => ref.invalidate(schoolLinksProvider),
            )
          : const SchoolLoadingView();
    } else if (!links.available) {
      body = SchoolMessageView(
        icon: SolarIconsBold.squareAcademicCap,
        title: 'school.title'.tr(),
        message: 'school.errors.unavailable'.tr(),
      );
    } else {
      body = RefreshIndicator(
        color: _blue,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: links.hasLinks
            ? _linkedList(links)
            : SchoolMessageView(
                icon: SolarIconsBold.squareAcademicCap,
                title: 'school.home.emptyTitle'.tr(),
                message: 'school.home.emptySubtitle'.tr(),
                actionLabel: 'school.home.enterCode'.tr(),
                onAction: _openLink,
              ),
      );
    }
    return SchoolScaffold(title: 'school.title'.tr(), body: body);
  }

  Widget _linkedList(SchoolLinks links) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      children: [
        for (final link in links.links) ...[
          SchoolLinkCard(
            link: link,
            children: links.children,
            unlinking: _unlinkingId == link.guardianId,
            onOpenStudent: _openStudent,
            onMatch: (student) => _openMatch(links, student),
            onUnlink: () => _confirmUnlink(link),
          ),
          const SizedBox(height: 12),
        ],
        _SectionTiles(onAttendance: () => _openAttendance(links.students)),
        const SizedBox(height: 16),
        ParvozSecondaryButton(
          label: 'school.home.addAnother'.tr(),
          leading: const Icon(
            SolarIconsBold.addCircle,
            size: 22,
            color: Colors.white,
          ),
          onPressed: _openLink,
        ),
      ],
    );
  }
}

/// 2x2 bo'limlar: E'lonlar, Davomat, Erta ketish, To'lovlar.
class _SectionTiles extends ConsumerWidget {
  const _SectionTiles({required this.onAttendance});

  final VoidCallback onAttendance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(schoolUnreadCountProvider).valueOrNull ?? 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Tile(
                icon: SolarIconsBold.letterUnread,
                label: 'school.announcements.title'.tr(),
                badge: unread,
                onTap: () => context.push(AppRoutes.schoolAnnouncements),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                icon: SolarIconsBold.calendarMark,
                label: 'school.attendance.title'.tr(),
                onTap: onAttendance,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Tile(
                icon: SolarIconsBold.walking,
                label: 'school.earlyExit.title'.tr(),
                onTap: () => context.push(AppRoutes.schoolEarlyExits),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                icon: SolarIconsBold.billList,
                label: 'school.payments.title'.tr(),
                onTap: () => context.push(AppRoutes.schoolPayments),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// O'qilmaganlar soni (0 — belgi yo'q).
  final int badge;

  @override
  Widget build(BuildContext context) {
    // Ekran o'quvchi: "E'lonlar, 3" — tugma sifatida.
    return Semantics(
      container: true,
      button: true,
      label: label,
      value: badge > 0 ? '$badge' : null,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 108,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: _chipBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 22, color: Colors.white),
                  ),
                  const Spacer(),
                  if (badge > 0) _Badge(count: badge),
                ],
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _pop(15, w: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: _pop(12, w: FontWeight.w600),
      ),
    );
  }
}

/// Davomat uchun o'quvchi tanlash varag'i (bir nechta o'quvchi bo'lsa).
class _StudentPicker extends StatelessWidget {
  const _StudentPicker({required this.students, required this.onPick});

  final List<LinkedStudent> students;
  final ValueChanged<LinkedStudent> onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'school.home.pickStudent'.tr(),
              textAlign: TextAlign.center,
              style: _unb(16),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final student in students)
                    ListTile(
                      onTap: () => onPick(student),
                      leading: const Icon(
                        SolarIconsBold.backpack,
                        color: Colors.white,
                      ),
                      title: Text(
                        student.fullName,
                        style: _pop(15, w: FontWeight.w500),
                      ),
                      subtitle: student.className.isEmpty
                          ? null
                          : Text(
                              'school.classLabel'.tr(
                                namedArgs: {'name': student.className},
                              ),
                              style: _pop(13, c: _dim),
                            ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

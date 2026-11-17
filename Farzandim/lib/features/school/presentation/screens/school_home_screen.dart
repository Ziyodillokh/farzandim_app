// ─────────────────────────────────────────────────────────────────────
// SchoolHomeScreen — "Maktab" (Parvoz School, ota-ona ko'rinishi)
// ─────────────────────────────────────────────────────────────────────
//
// Sozlamalardagi "Maktab" qatori va dashboard kartasidan ochiladi.
//   - bog'lanish yo'q → taklif kodi CTA;
//   - "Bugun": har farzandning bugungi holati (P02);
//   - bo'limlar (2×2): E'lonlar, To'lovlar, Davomat, Bog'lanish — har biri
//     o'z holati bilan (erta ketish — farzand sahifasida);
//   - maktablar: yig'iq qator, bosilsa o'quvchilar (farzandga moslash) va
//     aloqani uzish; e'tibor talab qilgani (tasdiq, moslash) ochiq turadi;
//   - pull-to-refresh: ro'yxat, davomat va o'qilmaganlar soni;
//   - `?remind=<studentId>` (push `SCHOOL_MODE_REMIND`) — ro'yxat kelgach
//     School Mode yo'l-yo'rig'i bir marta ochiladi.
// Backend'da bo'lim yo'q (404 `code`siz) → "hozircha mavjud emas".

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/home/presentation/home_shell.dart';
import 'package:farzandim/features/home/presentation/start_screen.dart';
import 'package:farzandim/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:farzandim/features/notifications/presentation/screens/notifications_sheet.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_refresh.dart';
import 'package:farzandim/features/school/presentation/widgets/school_link_card.dart';
import 'package:farzandim/features/school/presentation/widgets/school_mode_sheet.dart';
import 'package:farzandim/features/school/presentation/widgets/school_section_tiles.dart';
import 'package:farzandim/features/school/presentation/widgets/school_today_card.dart';
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

  /// Foydalanuvchi ochgan / yiqqan maktablar (vasiy yozuvi → ochiqmi).
  /// Yo'q bo'lsa — e'tibor talab qilgani ochiq, qolgani yig'iq.
  Map<String, bool> _expanded = const {};

  bool _isExpanded(SchoolLink link) =>
      _expanded[link.guardianId] ?? schoolLinkNeedsAttention(link);

  void _toggle(SchoolLink link) => setState(
    () => _expanded = {..._expanded, link.guardianId: !_isExpanded(link)},
  );

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

  /// O'quvchi kartasi — "Farzandim maktabda" (statistika).
  void _openStudent(LinkedStudent student) =>
      unawaited(context.push(AppRoutes.schoolStudentPath(student.id)));

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
    unawaited(context.push(AppRoutes.schoolAttendancePath(student.id)));
  }

  Future<LinkedStudent?> _pickStudent(List<LinkedStudent> students) {
    return showModalBottomSheet<LinkedStudent>(
      useRootNavigator: true,
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
        child: links.hasLinks ? _linkedList(links) : _empty(),
      );
    }
    // Maktab — asosiy tab: orqaga tugmasi yo'q, pastda tab paneli.
    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TabHeader(onAdd: (links?.hasLinks ?? false) ? _openLink : null),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  /// Maktabga hali ulanmagan: nima beradi, qanday ulanadi, kod qayerdan.
  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, kHomeNavReserve + 12),
      children: [
        Text('home.school.emptySubtitle'.tr(), style: _pop(14.5, c: _dim)),
        const SizedBox(height: 20),
        StartOptionCard(
          icon: SolarIconsBold.squareAcademicCap,
          color: _blue,
          title: 'home.start.schoolTitle'.tr(),
          body: 'home.start.schoolBody'.tr(),
          points: [
            'home.start.schoolPoint1'.tr(),
            'home.start.schoolPoint2'.tr(),
          ],
          action: 'home.start.schoolAction'.tr(),
          onTap: _openLink,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(SolarIconsBold.infoCircle, size: 22, color: _blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'home.school.codeWhereTitle'.tr(),
                      style: _pop(14.5, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'home.school.codeWhereBody'.tr(),
                      style: _pop(13.5, c: _dim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linkedList(SchoolLinks links) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, kHomeNavReserve + 12),
      children: [
        if (links.students.isNotEmpty) ...[
          _SectionTitle('home.school.today'.tr()),
          SchoolTodayStudents(links: links, onOpen: _openStudent),
          const SizedBox(height: 10),
        ],
        _SectionTitle('home.school.sections'.tr()),
        SchoolSectionTiles(
          students: links.students,
          onAttendance: () => _openAttendance(links.students),
        ),
        const SizedBox(height: 22),
        _SectionTitle('home.school.schools'.tr()),
        for (final link in links.links) ...[
          SchoolLinkCard(
            link: link,
            children: links.children,
            expanded: _isExpanded(link),
            onToggle: () => _toggle(link),
            unlinking: _unlinkingId == link.guardianId,
            onOpenStudent: _openStudent,
            onMatch: (student) => _openMatch(links, student),
            onUnlink: () => _confirmUnlink(link),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Tab sarlavhasi: «Maktab» va (ulangan bo'lsa) yangi maktab / farzand
/// qo'shish tugmasi.
class _TabHeader extends ConsumerWidget {
  const _TabHeader({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text('home.tabs.school'.tr(), style: _unb(26)),
            ),
          ),
          // Bildirishnomalar (maktab push'lari ham) — tab emas, shu yerda.
          _HeaderIcon(
            icon: SolarIconsBold.bell,
            label: 'notifications.listTitle'.tr(),
            showDot: unread > 0,
            onTap: () => NotificationsSheet.show(context),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            _HeaderIcon(
              icon: SolarIconsBold.addCircle,
              label: 'school.home.addAnother'.tr(),
              onTap: onAdd!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sarlavhadagi 44 px dumaloq tugma (ixtiyoriy qizil nuqta bilan).
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _card,
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(icon, size: 21, color: Colors.white),
            ),
            if (showDot)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _danger,
                    border: Border.all(color: _card, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: _dim,
        ),
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

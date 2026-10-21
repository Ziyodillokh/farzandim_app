// ─────────────────────────────────────────────────────────────────────
// SchoolAttendanceScreen — o'quvchining oylik davomati
// ─────────────────────────────────────────────────────────────────────
//
// Marshrut: `AppRoutes.schoolAttendancePath(studentId, month: 'YYYY-MM')`
// (push `school_attendance` — `date` oyi bilan). Oy almashtirgich (joriy
// oydan keyinga o'tilmaydi, 12 oy orqaga), kelish foizi va holatlar soni,
// kalendar va kunlar ro'yxati (kirish/chiqish vaqtlari). Pull-to-refresh.
// Ma'lumot: `monthAttendanceProvider` (dashboard kartasi bilan umumiy kesh).

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/school_failure.dart';
import 'package:farzandim/features/school/presentation/attendance_view_models.dart';
import 'package:farzandim/features/school/presentation/providers/school_attendance_providers.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/features/school/presentation/school_format.dart';
import 'package:farzandim/features/school/presentation/widgets/attendance_calendar.dart';
import 'package:farzandim/features/school/presentation/widgets/attendance_summary.dart';
import 'package:farzandim/features/school/presentation/widgets/school_ui.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

// ════════════ Tokenlar (lokal) ════════════
const _card = Color(0xFF1A1F23);
const _cardBorder = Color(0x1FFFFFFF); // oq 12%
const _chipBg = Color(0xFF1B2128);
const _blue = Color(0xFF216BFF);
const _dim = Color(0x99FFFFFF); // oq 60%

/// Oy almashtirgich shuncha oy orqaga boradi (o'tgan o'quv yili ham).
const int _maxMonthsBack = 12;

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

class SchoolAttendanceScreen extends ConsumerStatefulWidget {
  const SchoolAttendanceScreen({
    required this.studentId,
    this.month,
    super.key,
  });

  final String studentId;

  /// "YYYY-MM" (`?month=`); `null`, buzuq yoki kelajak — joriy oy.
  final String? month;

  @override
  ConsumerState<SchoolAttendanceScreen> createState() =>
      _SchoolAttendanceScreenState();
}

class _SchoolAttendanceScreenState
    extends ConsumerState<SchoolAttendanceScreen> {
  final String _current = currentSchoolMonth();
  late String _month = resolveSchoolMonth(widget.month, current: _current);

  MonthAttendanceArgs get _args => (studentId: widget.studentId, month: _month);

  /// Ko'rsatish mumkin bo'lgan eng eski oy.
  String get _earliest => shiftSchoolMonth(_current, -_maxMonthsBack) ?? '';

  bool get _canGoBack => _month.compareTo(_earliest) > 0;
  bool get _canGoForward => _month.compareTo(_current) < 0;

  void _shift(int delta) {
    final next = shiftSchoolMonth(_month, delta);
    if (next == null ||
        next.compareTo(_current) > 0 ||
        next.compareTo(_earliest) < 0) {
      return;
    }
    setState(() => _month = next);
  }

  Future<void> _refresh() async {
    final args = _args;
    ref.invalidate(monthAttendanceProvider(args));
    try {
      await ref
          .read(monthAttendanceProvider(args).future)
          .timeout(_refreshTimeout);
    } on TimeoutException {
      // Javob kechikdi — spinner yopiladi, kelganda ekran o'zi yangilanadi.
    } on Object catch (e) {
      // Oldingi ma'lumot ekranda qoladi — sababini qisqa xabar bilan aytamiz.
      if (!mounted) return;
      AppToast.error(context, SchoolFailure.fromError(e).messageKey.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = tashkentTodayStr();
    final async = ref.watch(monthAttendanceProvider(_args));
    final attendance = async.valueOrNull;

    final Widget content;
    if (attendance != null) {
      content = _MonthContent(attendance: attendance, today: today);
    } else if (async.hasError) {
      content = SizedBox(
        height: 380,
        child: SchoolErrorView(
          error: async.error,
          onRetry: () => ref.invalidate(monthAttendanceProvider(_args)),
        ),
      );
    } else {
      content = const SizedBox(height: 260, child: SchoolLoadingView());
    }

    return SchoolScaffold(
      title: 'school.attendance.title'.tr(),
      body: RefreshIndicator(
        color: _blue,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
          children: [
            _StudentHeader(studentId: widget.studentId, fallback: attendance),
            const SizedBox(height: 10),
            _MonthSwitcher(
              title: schoolMonthTitle(_month),
              onPrevious: _canGoBack ? () => _shift(-1) : null,
              onNext: _canGoForward ? () => _shift(1) : null,
            ),
            const SizedBox(height: 10),
            content,
          ],
        ),
      ),
    );
  }
}

/// O'quvchi: avatar, ism, sinf · maktab. Ma'lumot bog'lanishlar
/// ro'yxatidan (darhol), bo'lmasa davomat javobidan.
class _StudentHeader extends ConsumerWidget {
  const _StudentHeader({required this.studentId, required this.fallback});

  final String studentId;
  final MonthAttendance? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(
      schoolLinksProvider.select((async) {
        final links = async.valueOrNull;
        return (
          student: links?.students.firstWhereOrNull((s) => s.id == studentId),
          school: links?.linkOfStudent(studentId)?.school.displayName,
        );
      }),
    );
    final student = info.student;
    final childId = student?.childId;
    final child = childId == null
        ? null
        : ref.watch(childByIdProvider(childId));
    final name = student?.fullName ?? fallback?.student.name ?? '';
    final className = student?.className ?? fallback?.student.className ?? '';
    final school = info.school ?? fallback?.student.schoolName ?? '';
    final details = [
      if (className.isNotEmpty)
        'school.classLabel'.tr(namedArgs: {'name': className}),
      if (school.isNotEmpty) school,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          if (child != null)
            ChildAvatar(child: child, size: 44, showBorder: false)
          else
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _chipBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SolarIconsBold.backpack,
                size: 22,
                color: Colors.white,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isEmpty ? 'school.attendance.title'.tr() : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _pop(16, w: FontWeight.w600),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(13, c: _dim),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "‹  Oktyabr 2026  ›" — `null` tugma o'chiq.
class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.title,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ArrowButton(
          icon: SolarIconsOutline.altArrowLeft,
          label: 'school.attendance.previousMonth'.tr(),
          onTap: onPrevious,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _unb(17),
          ),
        ),
        _ArrowButton(
          icon: SolarIconsOutline.altArrowRight,
          label: 'school.attendance.nextMonth'.tr(),
          onTap: onNext,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Yuklangan oy: jami, kalendar va kunlar ro'yxati.
class _MonthContent extends StatelessWidget {
  const _MonthContent({required this.attendance, required this.today});

  final MonthAttendance attendance;
  final String today;

  @override
  Widget build(BuildContext context) {
    final days = attendanceListDays(attendance, today: today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AttendanceSummaryCard(
          summary: attendance.summary,
          rate: attendance.rate,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
          ),
          child: AttendanceCalendar(attendance: attendance, today: today),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('school.attendance.days'.tr(), style: _unb(15)),
        ),
        const SizedBox(height: 10),
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'school.attendance.noDays'.tr(),
              style: _pop(13.5, c: _dim),
            ),
          ),
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          AttendanceDayRow(day: day, today: today),
        ],
      ],
    );
  }
}

// Maktab ekranlari uchun umumiy ko'rinish qoidalari: muddat yorlig'i,
// topshiriq holati, belgi va davomat qatori.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/design/design.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/features/school/presentation/assignment_display.dart';
import 'package:farzandim_child/growth/common/subject_look.dart';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// «Bugun» / «Ertaga» / «7-noyabr».
String dueLabel(DateTime? due, DateTime now) {
  if (due == null) return '';
  if (sameDay(due, now)) return 'g5.school.due.today'.tr();
  if (sameDay(due, now.add(const Duration(days: 1)))) {
    return 'g5.school.due.tomorrow'.tr();
  }
  return localizedDayMonth(due);
}

/// Topshiriq nomi (test — fan nomi bilan, boshqasi — server nomi).
String taskTitle(SchoolAssignment a) => schoolAssignmentTitle(a);

/// Fan yoki material turi bo'yicha plita.
GTile taskTile(SchoolAssignment a, {double size = 40}) {
  final subject = a.subject;
  if (a.kind == SchoolAssignmentKind.test && subject != null) {
    return GTile(icon: subject.gIcon, hue: subject.gHue, size: size);
  }
  return switch (a.kind) {
    SchoolAssignmentKind.audiobook => GTile(
      icon: GIcons.bookOpen,
      hue: GHue.green,
      size: size,
    ),
    SchoolAssignmentKind.video => GTile(
      icon: GIcons.filmStrip,
      hue: GHue.blue,
      size: size,
    ),
    SchoolAssignmentKind.written => GTile(
      icon: GIcons.pencilSimpleLine,
      hue: GHue.gold,
      size: size,
    ),
    SchoolAssignmentKind.lesson => GTile(
      icon: GIcons.bookOpenText,
      hue: GHue.sky,
      size: size,
    ),
    _ => GTile(icon: GIcons.clipboardText, hue: GHue.slate, size: size),
  };
}

/// Fan / tur qatori («Matematika · Test»).
String taskKindLine(SchoolAssignment a) {
  final kind =
      'g5.school.kind.${a.kind == SchoolAssignmentKind.unknown ? 'test' : a.kind.name}'
          .tr();
  final subject = a.subject;
  return subject == null ? kind : '${subject.label} · $kind';
}

/// Holat yorlig'i va chip turi.
({String label, GChipKind kind}) taskStatus(SchoolAssignment a) {
  final submission = a.submission;
  if (submission != null) {
    return switch (submission.status) {
      HomeworkStatus.accepted => (
        label: 'g5.school.status.accepted'.tr(),
        kind: GChipKind.ok,
      ),
      HomeworkStatus.returned => (
        label: 'g5.school.status.returned'.tr(),
        kind: GChipKind.warn,
      ),
      _ => (label: 'g5.school.status.submitted'.tr(), kind: GChipKind.info),
    };
  }
  if (a.isDone == true) {
    return a.kind == SchoolAssignmentKind.lesson
        ? (label: 'g5.school.status.read'.tr(), kind: GChipKind.ok)
        : (label: 'g5.school.status.done'.tr(), kind: GChipKind.ok);
  }
  if (a.isOverdue) {
    return (label: 'g5.school.due.overdue'.tr(), kind: GChipKind.sos);
  }
  return (label: 'g5.school.status.notStarted'.tr(), kind: GChipKind.neutral);
}

/// Bajarilgan hisoblanadimi (ro'yxat guruhi uchun).
bool taskFinished(SchoolAssignment a) =>
    a.isDone == true ||
    a.submission?.status == HomeworkStatus.submitted ||
    a.submission?.status == HomeworkStatus.accepted;

/// Jadvaldagi fan: ma'lum kalit bo'lsa tarjima, aks holda o'zi.
String lessonSubjectLabel(String subject) =>
    Subject.fromName(subject)?.label ?? subject;

GIconData lessonSubjectIcon(String subject) =>
    Subject.fromName(subject)?.gIcon ?? GIcons.bookOpen;

GHue lessonSubjectHue(String subject) =>
    Subject.fromName(subject)?.gHue ?? GHue.slate;

/// Bugungi davomat qatori: kirish/chiqish yoki holat.
String attendanceLine(SchoolToday today) {
  final record = today.record;
  if (!today.isSchoolDay) return 'g5.school.noSchoolDay'.tr();
  if (record?.outAt != null) {
    return 'g5.school.left'.tr(namedArgs: {'time': record!.outAt!});
  }
  if (record?.inAt != null) {
    return 'g5.school.arrived'.tr(namedArgs: {'time': record!.inAt!});
  }
  return 'g5.school.notMarked'.tr();
}

String attendanceSourceLine(AttendanceSource source) => switch (source) {
  AttendanceSource.kiosk => 'g5.school.viaKiosk'.tr(),
  AttendanceSource.qr => 'g5.school.viaQr'.tr(),
  AttendanceSource.manual => 'g5.school.viaManual'.tr(),
  _ => '',
};

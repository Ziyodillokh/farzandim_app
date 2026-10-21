// Maktab topshiriqlarini ko'rsatish qoidalari: material turi nomi va
// belgisi, ilovada tarjima qilingan nom (server nomi faqat o'zbekcha),
// muddat holati ("bugun", "muddati o'tgan" …), ro'yxat tartibi va topshiriq
// bosilganda nima ochilishi. Sof funksiyalar — widget'siz testlanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/core/utils/localized_date.dart';
import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:flutter/widgets.dart';
import 'package:solar_icons/solar_icons.dart';

/// Server material topilmaganda nom o'rniga shu belgini yuboradi.
const _missingTitle = '—';

/// Material turi nomi — `school.assignments.kinds.<name>`.
String assignmentKindLabelKey(SchoolAssignmentKind kind) =>
    'school.assignments.kinds.${kind.name}';

/// Material turi belgisi.
IconData assignmentKindIcon(SchoolAssignmentKind kind) => switch (kind) {
  SchoolAssignmentKind.test => SolarIconsOutline.checklistMinimalistic,
  SchoolAssignmentKind.audiobook => SolarIconsOutline.headphonesRound,
  SchoolAssignmentKind.video => SolarIconsOutline.videoFramePlayHorizontal,
  SchoolAssignmentKind.unknown => SolarIconsOutline.notebookBookmark,
};

/// Topshiriq nomi joriy tilda: test — "Kunlik test: Matematika" (fan nomi
/// tarjima qilinadi), kitob / video — server nomi (asar nomi va muallif),
/// nom bo'lmasa — material turi.
String schoolAssignmentTitle(SchoolAssignment assignment) {
  final subject = assignment.subject;
  if (assignment.kind == SchoolAssignmentKind.test && subject != null) {
    return 'school.assignments.testTitle'.tr(
      namedArgs: {'subject': subject.labelKey.tr()},
    );
  }
  final title = assignment.title.trim();
  return title.isEmpty || title == _missingTitle
      ? assignmentKindLabelKey(assignment.kind).tr()
      : title;
}

/// Muddat holati.
enum AssignmentDueState { done, overdue, today, tomorrow, upcoming, noDate }

/// [today] — Toshkent kalendar kuni (`tashkentNow()`); faqat yil, oy va kun
/// ishlatiladi. Server "muddati o'tgan" desa — o'tgan; ilova uzoq ochiq
/// qolib sana o'tib ketsa ham shunday ko'rinadi.
AssignmentDueState assignmentDueState(
  SchoolAssignment assignment,
  DateTime today,
) {
  if (assignment.isDone == true) return AssignmentDueState.done;
  if (assignment.isOverdue) return AssignmentDueState.overdue;
  final due = assignment.dueDate;
  if (due == null) return AssignmentDueState.noDate;
  final days = DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days < 0) return AssignmentDueState.overdue;
  if (days == 0) return AssignmentDueState.today;
  if (days == 1) return AssignmentDueState.tomorrow;
  return AssignmentDueState.upcoming;
}

/// Muddat qatori: "Muddati: ertaga", "Muddati o'tgan · 18-oktabr",
/// "Bajarildi" (sana yo'q bo'lsa — bo'sh).
String assignmentDueText(SchoolAssignment assignment, DateTime today) {
  final due = assignment.dueDate;
  final date = due == null ? null : localizedDayMonth(due);
  return switch (assignmentDueState(assignment, today)) {
    AssignmentDueState.done => 'school.assignments.done'.tr(),
    AssignmentDueState.overdue => [
      'school.assignments.due.overdue'.tr(),
      ?date,
    ].join(' · '),
    AssignmentDueState.today => 'school.assignments.due.today'.tr(),
    AssignmentDueState.tomorrow => 'school.assignments.due.tomorrow'.tr(),
    AssignmentDueState.upcoming => 'school.assignments.due.date'.tr(
      namedArgs: {'date': date ?? ''},
    ),
    AssignmentDueState.noDate => '',
  };
}

/// Hali bajarilmaganlar birinchi (server tartibi — muddat bo'yicha —
/// saqlanadi), bajarilganlar oxirida.
List<SchoolAssignment> assignmentsForDisplay(
  List<SchoolAssignment> assignments,
) => [
  ...assignments.where((a) => a.isPending),
  ...assignments.where((a) => !a.isPending),
];

/// Bajarilmagan topshiriqlar soni.
int pendingAssignmentCount(List<SchoolAssignment> assignments) =>
    assignments.where((a) => a.isPending).length;

/// Topshiriq bosilganda ochiladigan joy.
sealed class AssignmentTarget {
  const AssignmentTarget();
}

/// Fan bo'yicha kunlik test.
final class AssignmentOpensQuiz extends AssignmentTarget {
  const AssignmentOpensQuiz(this.subject);

  final Subject subject;
}

/// Audiokitob sahifasi; id o'qilmasa (`null`) — audiokitoblar ro'yxati.
final class AssignmentOpensAudiobook extends AssignmentTarget {
  const AssignmentOpensAudiobook(this.audiobookId);

  final String? audiobookId;
}

/// Videolar ro'yxati (video materiallar hali fan bilan bog'lanmagan).
final class AssignmentOpensVideos extends AssignmentTarget {
  const AssignmentOpensVideos();
}

/// Ochiladigan joy yo'q (noma'lum material yoki fan).
final class AssignmentOpensNothing extends AssignmentTarget {
  const AssignmentOpensNothing();
}

AssignmentTarget assignmentTargetOf(SchoolAssignment assignment) {
  final subject = assignment.subject;
  return switch (assignment.kind) {
    SchoolAssignmentKind.test when subject != null => AssignmentOpensQuiz(
      subject,
    ),
    SchoolAssignmentKind.audiobook => AssignmentOpensAudiobook(
      assignment.audiobookId,
    ),
    SchoolAssignmentKind.video => const AssignmentOpensVideos(),
    _ => const AssignmentOpensNothing(),
  };
}

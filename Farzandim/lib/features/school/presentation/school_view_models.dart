// ─────────────────────────────────────────────────────────────────────
// school_view_models — maktab UI'sining sof (widget'siz) mantig'i
// ─────────────────────────────────────────────────────────────────────
//
// Kunlik davomat belgisi, dashboard kartasining holati, moslash varag'i
// yordamchilari va so'rov holatlarining tarjima kalitlari. Widget va
// provider'siz — unit testlar bilan tekshiriladi.

import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_links.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:flutter/foundation.dart';

/// Erta ketish holati yorlig'i kaliti (`school.earlyExit.status.*`).
String earlyExitStatusKey(EarlyExitStatus status) =>
    'school.earlyExit.status.${status.name}';

/// To'lov tekshiruvi holati yorlig'i kaliti
/// (`school.verifications.status.*`).
String verificationStatusKey(VerificationStatus status) =>
    'school.verifications.status.${status.name}';

/// Bir kunlik davomat belgisi (bugungi holat va kalendar uchun).
enum SchoolDayStatus {
  present,
  late,
  absent,
  leftEarly,
  excused,

  /// O'quv kuni, lekin hali belgilanmagan.
  pending,

  /// Dam olish yoki bayram kuni.
  holiday,

  /// Ma'lumot yo'q: kun oyda topilmadi yoki holat noma'lum.
  unknown;

  /// Yozuv bo'lsa — uning holati (dam olish kunida ham); yozuvsiz o'quv
  /// kuni — [pending]; yozuvsiz dam olish kuni — [holiday].
  static SchoolDayStatus of(AttendanceDay? day) {
    if (day == null) return unknown;
    final record = day.record;
    if (record == null) return day.schoolDay ? pending : holiday;
    return switch (record.status) {
      AttendanceStatus.present => present,
      AttendanceStatus.late => late,
      AttendanceStatus.absent => absent,
      AttendanceStatus.leftEarly => leftEarly,
      AttendanceStatus.excused => excused,
      AttendanceStatus.unknown => unknown,
    };
  }

  /// Tarjima kaliti (`school.attendance.status.*`).
  String get labelKey => 'school.attendance.status.$name';
}

/// Dashboard maktab kartasi nimani ko'rsatadi.
@immutable
sealed class SchoolCardMode {
  const SchoolCardMode();

  /// [links] — `schoolLinksProvider` qiymati (birinchi yuklanish yoki
  /// xatoda `null`); [childId] — dashboard'da tanlangan farzand.
  factory SchoolCardMode.of(SchoolLinks? links, String childId) {
    if (links == null || !links.available) return const SchoolCardHidden();
    if (!links.hasLinks) return const SchoolCardInvite();
    final student = links.studentForChild(childId);
    if (student != null) {
      return SchoolCardStudent(
        student: student,
        school: links.linkOfStudent(student.id)?.school,
      );
    }
    final unmatched = links.unmatchedStudents;
    // Moslaydigan o'quvchi yo'q (hammasi boshqa farzandlarga) — bu farzand
    // sahifasida karta kerak emas.
    if (unmatched.isEmpty) return const SchoolCardHidden();
    return SchoolCardMatch(links: links, students: unmatched);
  }
}

/// Karta ko'rinmaydi (yuklanmoqda, xato, bo'lim yo'q yoki aloqasi yo'q).
final class SchoolCardHidden extends SchoolCardMode {
  const SchoolCardHidden();
}

/// Bog'lanish yo'q — "Maktab taklif kodi bormi?".
final class SchoolCardInvite extends SchoolCardMode {
  const SchoolCardInvite();
}

/// Farzandga moslangan o'quvchi — bugungi holat va e'lonlar.
final class SchoolCardStudent extends SchoolCardMode {
  const SchoolCardStudent({required this.student, this.school});

  final LinkedStudent student;
  final SchoolInfo? school;
}

/// Hech kimga moslanmagan o'quvchilar bor — "Bog'lash".
final class SchoolCardMatch extends SchoolCardMode {
  const SchoolCardMatch({required this.links, required this.students});

  final SchoolLinks links;
  final List<LinkedStudent> students;
}

/// Moslash varag'i: farzand id → unga hozir moslangan BOSHQA o'quvchi.
/// Shu farzand tanlansa backend uni o'sha o'quvchidan ajratadi — varaq
/// buni oldindan ko'rsatadi.
Map<String, LinkedStudent> studentsByOtherChild(
  SchoolLinks links,
  String studentId,
) {
  return {
    for (final student in links.students)
      if (student.childId case final childId? when student.id != studentId)
        childId: student,
  };
}

/// Moslash varag'idagi farzandlar: ilovadagi ro'yxat (yangi qo'shilgani
/// ham) + maktab javobidagilar; id bo'yicha bir marta, tartib saqlanadi.
List<ChildRef> mergeMatchChildren(
  List<ChildRef> fromApp,
  List<ChildRef> fromLinks,
) {
  final seen = <String>{};
  return List.unmodifiable([
    for (final child in [...fromApp, ...fromLinks])
      if (child.id.isNotEmpty && seen.add(child.id)) child,
  ]);
}

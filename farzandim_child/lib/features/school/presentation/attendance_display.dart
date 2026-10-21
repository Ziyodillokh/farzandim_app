// Bugungi davomatni ko'rsatish qoidalari (bosh sahifa kartasi, "Maktabim",
// QR natijasi): holat belgisi, bolaga yo'l-yo'riq va QR tugmasi matni.
// Sof funksiyalar — widget'siz testlanadi.

import 'package:farzandim_child/features/school/domain/attendance_models.dart';

/// Holat belgisi ("chip") turi.
enum AttendanceChipKind {
  /// O'quv kuni, hali qayd etilmagan.
  notMarked,

  /// Dam olish yoki bayram kuni (yozuv yo'q).
  dayOff,
  present,
  late,
  absent,
  leftEarly,
  excused,

  /// Server yangi (ilova bilmaydigan) holat yubordi.
  marked;

  /// Tarjima kaliti — `school.status.<name>`.
  String get labelKey => 'school.status.$name';
}

/// Bugungi holat belgisi: yozuv bo'lsa — server holati, aks holda dam olish
/// kuni yoki hali belgilanmagan.
AttendanceChipKind attendanceChipOf(SchoolToday today) {
  final record = today.record;
  if (record == null) {
    return today.isSchoolDay
        ? AttendanceChipKind.notMarked
        : AttendanceChipKind.dayOff;
  }
  return switch (record.status) {
    AttendanceStatus.present => AttendanceChipKind.present,
    AttendanceStatus.late => AttendanceChipKind.late,
    AttendanceStatus.absent => AttendanceChipKind.absent,
    AttendanceStatus.leftEarly => AttendanceChipKind.leftEarly,
    AttendanceStatus.excused => AttendanceChipKind.excused,
    AttendanceStatus.unknown => AttendanceChipKind.marked,
  };
}

const _hints = 'school.today.hints';

/// Kirish vaqtisiz yozuvni xodim qo'ygan (kelmadi, sababli): bolaning QR'i
/// uni o'zgartirmaydi (server `NONE` qaytaradi). Tizim avtomatik qo'ygan
/// "kelmadi" (`SYSTEM`) bundan mustasno — QR uni kelish bilan tuzatadi.
bool isStaffDecision(AttendanceRecord? record) =>
    record != null &&
    record.inAt == null &&
    record.source != AttendanceSource.system;

/// Bolaga yo'l-yo'riq — tarjima kaliti (`school.today.hints.*`).
String attendanceHintKey(SchoolToday today) {
  final record = today.record;
  if (today.className == null) return '$_hints.noClass';
  if (record?.outAt != null) return '$_hints.checkedOut';
  if (record?.inAt != null) return '$_hints.inSchool';
  if (!today.isSchoolDay) return '$_hints.dayOff';
  if (isStaffDecision(record)) return '$_hints.staffMarked';
  return '$_hints.notMarked';
}

/// QR tugmasi matni: hali kelmagan — kirish, kelgan — chiqish (server
/// chiqishni dars tugagach qayd etadi).
String scanLabelKey(SchoolToday today) =>
    today.record?.inAt == null ? 'school.today.scanIn' : 'school.today.scanOut';

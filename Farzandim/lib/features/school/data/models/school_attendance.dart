// ─────────────────────────────────────────────────────────────────────
// SchoolAttendance — oylik davomat va erta ketish so'rovlari
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /api/parent/school/attendance?studentId=&month=YYYY-MM,
// GET|POST /early-exits. Sanalar Toshkent kun-kalitlari ("YYYY-MM-DD"),
// vaqtlar "HH:MM". Ota-ona uchun alohida "bugun" endpoint'i yo'q — bugungi
// kun oylik javobdan `tashkentTodayStr()` bilan olinadi.

import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:flutter/foundation.dart';

/// Erta ketish sababi uchun eng katta uzunlik (backend).
const int kEarlyExitReasonMax = 160;

/// "Kim olib ketadi" maydoni uchun eng katta uzunlik (backend).
const int kEarlyExitPickupMax = 80;

/// Kunlik davomat holati.
enum AttendanceStatus {
  present,
  late,
  absent,
  leftEarly,
  excused,
  unknown;

  static AttendanceStatus fromApi(Object? raw) => switch (raw) {
    'PRESENT' => present,
    'LATE' => late,
    'ABSENT' => absent,
    'LEFT_EARLY' => leftEarly,
    'EXCUSED' => excused,
    _ => unknown,
  };

  /// Maktabga kelgan hisoblanadi (backend `rate` formulasi bilan bir xil).
  bool get attended => this == present || this == late || this == leftEarly;
}

/// Kunlik davomat yozuvi.
@immutable
class AttendanceRecord {
  const AttendanceRecord({required this.status, this.inAt, this.outAt});

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        status: AttendanceStatus.fromApi(json['status']),
        inAt: json.readStringOrNull('inAt'),
        outAt: json.readStringOrNull('outAt'),
      );

  final AttendanceStatus status;

  /// Kirish / chiqish vaqti, "HH:MM".
  final String? inAt;
  final String? outAt;
}

/// Kalendarning bitta kuni.
@immutable
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.schoolDay,
    this.record,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) {
    final record = json.readMapOrNull('record');
    return AttendanceDay(
      date: json.readString('date'),
      schoolDay: json.readBool('schoolDay'),
      record: record == null ? null : AttendanceRecord.fromJson(record),
    );
  }

  /// "YYYY-MM-DD".
  final String date;

  /// O'quv kuni (dam olish va bayram emas).
  final bool schoolDay;
  final AttendanceRecord? record;

  /// O'quv kuni, lekin hali belgilanmagan.
  bool get isPending => schoolDay && record == null;

  /// [date] sana sifatida (buzuq → `null`).
  DateTime? get day => DateTime.tryParse(date);
}

/// Oy bo'yicha jami (o'quv kunlari, bugungacha).
@immutable
class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.leftEarly,
    required this.excused,
    required this.pending,
    required this.total,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) =>
      AttendanceSummary(
        present: json.readInt('present'),
        late: json.readInt('late'),
        absent: json.readInt('absent'),
        leftEarly: json.readInt('leftEarly'),
        excused: json.readInt('excused'),
        pending: json.readInt('pending'),
        total: json.readInt('total'),
      );

  static const empty = AttendanceSummary(
    present: 0,
    late: 0,
    absent: 0,
    leftEarly: 0,
    excused: 0,
    pending: 0,
    total: 0,
  );

  final int present;
  final int late;
  final int absent;
  final int leftEarly;
  final int excused;

  /// Hali belgilanmagan o'quv kunlari.
  final int pending;
  final int total;
}

/// Davomati ko'rsatilayotgan o'quvchi.
@immutable
class AttendanceStudent {
  const AttendanceStudent({
    required this.id,
    required this.name,
    required this.className,
    required this.schoolName,
  });

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) =>
      AttendanceStudent(
        id: json.readString('id'),
        name: json.readString('name'),
        className: json.readString('className'),
        schoolName: json.readString('schoolName'),
      );

  final String id;
  final String name;
  final String className;
  final String schoolName;
}

/// Bir oylik davomat: kalendar, jami va kelish foizi.
@immutable
class MonthAttendance {
  const MonthAttendance({
    required this.student,
    required this.month,
    required this.days,
    required this.summary,
    required this.rate,
  });

  factory MonthAttendance.fromJson(Map<String, dynamic> json) =>
      MonthAttendance(
        student: AttendanceStudent.fromJson(
          json.readMapOrNull('student') ?? const {},
        ),
        month: json.readString('month'),
        days: List.unmodifiable(
          parseListSafely(
            json.readList('days'),
            AttendanceDay.fromJson,
            tag: 'AttendanceDay',
          ).where((d) => d.date.isNotEmpty),
        ),
        summary: AttendanceSummary.fromJson(
          json.readMapOrNull('summary') ?? const {},
        ),
        rate: json.readInt('rate').clamp(0, 100),
      );

  final AttendanceStudent student;

  /// "YYYY-MM".
  final String month;
  final List<AttendanceDay> days;
  final AttendanceSummary summary;

  /// Kelish foizi 0–100: (kelgan + kechikkan + erta ketgan) / belgilangan.
  final int rate;

  /// Shu kun (masalan `tashkentTodayStr()`); oyda yo'q → `null`.
  AttendanceDay? dayOf(String date) =>
      days.firstWhereOrNull((d) => d.date == date);
}

/// Erta ketish so'rovi holati.
enum EarlyExitStatus {
  pending,
  approved,
  rejected,
  unknown;

  static EarlyExitStatus fromApi(Object? raw) => switch (raw) {
    'PENDING' => pending,
    'APPROVED' => approved,
    'REJECTED' => rejected,
    _ => unknown,
  };
}

/// Erta ketish so'rovi (ota-ona yoki xodim yaratgan).
@immutable
class EarlyExitRequest {
  const EarlyExitRequest({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    required this.time,
    required this.reason,
    required this.pickupBy,
    required this.status,
    required this.studentName,
    required this.className,
    required this.requestedByMe,
    this.requestedAt,
    this.decidedAt,
    this.decidedByStaffId,
  });

  factory EarlyExitRequest.fromJson(Map<String, dynamic> json) =>
      EarlyExitRequest(
        id: json.readString('id'),
        studentId: json.readString('studentId'),
        classId: json.readString('classId'),
        date: json.readString('date'),
        time: json.readString('time'),
        reason: json.readString('reason'),
        pickupBy: json.readString('pickupBy'),
        status: EarlyExitStatus.fromApi(json['status']),
        studentName: json.readString('studentName'),
        className: json.readString('className'),
        requestedByMe: json.readBool('requestedByMe'),
        requestedAt: json.readDateTime('requestedAt'),
        decidedAt: json.readDateTime('decidedAt'),
        decidedByStaffId: json.readStringOrNull('decidedByStaffId'),
      );

  final String id;
  final String studentId;
  final String classId;

  /// So'rov kuni ("YYYY-MM-DD", har doim yaratilgan kun — server belgilaydi).
  final String date;

  /// Ketish vaqti, "HH:MM".
  final String time;
  final String reason;
  final String pickupBy;
  final EarlyExitStatus status;
  final String studentName;
  final String className;

  /// `false` — so'rovni maktab xodimi kiritgan.
  final bool requestedByMe;
  final DateTime? requestedAt;
  final DateTime? decidedAt;
  final String? decidedByStaffId;

  bool get isPending => status == EarlyExitStatus.pending;
}

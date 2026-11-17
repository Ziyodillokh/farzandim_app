// ─────────────────────────────────────────────────────────────────────
// StudentOverview — "Farzandim maktabda" statistikasi
// ─────────────────────────────────────────────────────────────────────
//
// Backend: GET /parent/school/students/:id/overview. Joriy chorak (yoki
// o'quv yili) davomati, o'rtacha kelish vaqti, o'z vaqtida kelish seriyasi,
// 8 haftalik dinamika, sinf o'rtachasi (kamida 5 o'quvchi bo'lsa) va
// yozma vazifalar. Reyting va boshqa bolalar bilan solishtirish yo'q.

import 'package:farzandim/core/utils/safe_parse.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:flutter/foundation.dart';

/// Hisob davri.
@immutable
class OverviewPeriod {
  const OverviewPeriod({
    required this.isQuarter,
    required this.from,
    required this.to,
    this.number,
  });

  factory OverviewPeriod.fromJson(Map<String, dynamic> json) => OverviewPeriod(
    isQuarter: json['kind'] == 'QUARTER',
    number: json.readIntOrNull('no'),
    from: json.readString('from'),
    to: json.readString('to'),
  );

  final bool isQuarter;
  final int? number;

  /// "YYYY-MM-DD".
  final String from;
  final String to;
}

/// Haftalik kelish foizi (`rate` — belgilangan kun bo'lmasa `null`).
@immutable
class WeekRate {
  const WeekRate({required this.weekStart, this.rate});

  factory WeekRate.fromJson(Map<String, dynamic> json) => WeekRate(
    weekStart: json.readString('weekStart'),
    rate: json.readIntOrNull('rate'),
  );

  final String weekStart;
  final int? rate;
}

@immutable
class OverviewAttendance {
  const OverviewAttendance({
    required this.present,
    required this.late,
    required this.absent,
    required this.leftEarly,
    required this.excused,
    required this.pending,
    required this.total,
    required this.rate,
    required this.onTimeStreak,
    required this.weeks,
    this.averageArrival,
    this.classRate,
  });

  factory OverviewAttendance.fromJson(Map<String, dynamic> json) =>
      OverviewAttendance(
        present: json.readInt('present'),
        late: json.readInt('late'),
        absent: json.readInt('absent'),
        leftEarly: json.readInt('leftEarly'),
        excused: json.readInt('excused'),
        pending: json.readInt('pending'),
        total: json.readInt('total'),
        rate: json.readInt('rate'),
        onTimeStreak: json.readInt('onTimeStreak'),
        averageArrival: json.readStringOrNull('averageArrival'),
        classRate: json.readIntOrNull('classRate'),
        weeks: List.unmodifiable(
          parseListSafely(
            json.readList('weeks'),
            WeekRate.fromJson,
            tag: 'WeekRate',
          ),
        ),
      );

  final int present;
  final int late;
  final int absent;
  final int leftEarly;
  final int excused;
  final int pending;
  final int total;

  /// Kelganlar ulushi, % (belgilangan kunlar bo'yicha).
  final int rate;

  /// Ketma-ket o'z vaqtida kelgan o'quv kunlari.
  final int onTimeStreak;

  /// O'rtacha kirish vaqti ("08:09").
  final String? averageArrival;

  /// Sinf o'rtachasi, % (kichik sinfda — `null`).
  final int? classRate;
  final List<WeekRate> weeks;

  /// Belgilangan (hisobga kirgan) o'quv kunlari.
  int get marked => total - pending;
  int get attended => present + late + leftEarly;
}

/// Yozma vazifa holati.
enum TaskState {
  todo,
  overdue,
  submitted,
  returned,
  accepted;

  static TaskState fromApi(Object? raw) => switch (raw) {
    'OVERDUE' => overdue,
    'SUBMITTED' => submitted,
    'RETURNED' => returned,
    'ACCEPTED' => accepted,
    _ => todo,
  };
}

@immutable
class OverviewTask {
  const OverviewTask({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.state,
    this.teacher,
  });

  factory OverviewTask.fromJson(Map<String, dynamic> json) => OverviewTask(
    id: json.readString('id'),
    title: json.readString('title'),
    dueDate: json.readString('dueDate'),
    state: TaskState.fromApi(json['state']),
    teacher: json.readStringOrNull('teacher'),
  );

  final String id;
  final String title;

  /// "YYYY-MM-DD".
  final String dueDate;
  final TaskState state;

  /// O'qituvchi lavozimi yoki ismi.
  final String? teacher;
}

@immutable
class OverviewTasks {
  const OverviewTasks({
    required this.total,
    required this.submitted,
    required this.accepted,
    required this.returned,
    required this.pending,
    required this.overdue,
    required this.items,
    this.classSubmitRate,
  });

  factory OverviewTasks.fromJson(Map<String, dynamic> json) => OverviewTasks(
    total: json.readInt('total'),
    submitted: json.readInt('submitted'),
    accepted: json.readInt('accepted'),
    returned: json.readInt('returned'),
    pending: json.readInt('pending'),
    overdue: json.readInt('overdue'),
    classSubmitRate: json.readIntOrNull('classSubmitRate'),
    items: List.unmodifiable(
      parseListSafely(
        json.readList('items'),
        OverviewTask.fromJson,
        tag: 'OverviewTask',
      ),
    ),
  );

  static const empty = OverviewTasks(
    total: 0,
    submitted: 0,
    accepted: 0,
    returned: 0,
    pending: 0,
    overdue: 0,
    items: [],
  );

  final int total;
  final int submitted;
  final int accepted;
  final int returned;

  /// Topshirilgan, hali tekshirilmagan.
  final int pending;
  final int overdue;

  /// Sinfdagi topshirish ulushi, % (kichik sinfda — `null`).
  final int? classSubmitRate;

  /// Yaqin / muddati o'tgan / qaytarilgan vazifalar (5 tagacha).
  final List<OverviewTask> items;

  int get submitRate => total == 0 ? 0 : (submitted * 100 / total).round();
}

@immutable
class StudentOverview {
  const StudentOverview({
    required this.student,
    required this.period,
    required this.attendance,
    required this.tasks,
  });

  factory StudentOverview.fromJson(
    Map<String, dynamic> json,
  ) => StudentOverview(
    student: ConnectStudent.fromJson(json.readMapOrNull('student') ?? const {}),
    period: OverviewPeriod.fromJson(json.readMapOrNull('period') ?? const {}),
    attendance: OverviewAttendance.fromJson(
      json.readMapOrNull('attendance') ?? const {},
    ),
    tasks: json.readMapOrNull('tasks') == null
        ? OverviewTasks.empty
        : OverviewTasks.fromJson(json.readMapOrNull('tasks')!),
  );

  final ConnectStudent student;
  final OverviewPeriod period;
  final OverviewAttendance attendance;
  final OverviewTasks tasks;
}

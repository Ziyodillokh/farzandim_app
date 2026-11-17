// Maktab (v5) testlari va skrinshotlari uchun soxta ma'lumot: e'lonlar,
// davomat oyi, dars jadvali va yozma vazifa yuborish.

import 'package:farzandim_child/features/learning/domain/subject.dart';
import 'package:farzandim_child/features/school/domain/attendance_models.dart';
import 'package:farzandim_child/features/school/domain/school_assignment.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_models.dart';
import 'package:farzandim_child/growth/maktab/data/school_v5_repository.dart';

import 'g5_overrides.dart';

class FakeSchoolV5Repository implements SchoolV5Repository {
  FakeSchoolV5Repository({this.notices, this.month, this.day});

  SchoolNoticePage? notices;
  AttendanceMonth? month;
  TimetableDay? day;

  final readIds = <String>[];
  final lessonReads = <String>[];
  final submitted =
      <({String id, int photos, String comment, String requestId})>[];

  @override
  Future<SchoolNoticePage> loadNotices() async =>
      notices ?? SchoolNoticePage.empty;

  @override
  Future<void> markNoticeRead(String id) async => readIds.add(id);

  @override
  Future<void> markLessonRead(String assignmentId) async =>
      lessonReads.add(assignmentId);

  @override
  Future<AttendanceMonth> loadAttendance(DateTime month) async =>
      this.month ?? AttendanceMonth(month: month, days: const []);

  @override
  Future<TimetableDay> loadTimetable(DateTime date) async =>
      day ??
      TimetableDay(
        date: date,
        weekday: date.weekday,
        published: false,
        lessons: const [],
      );

  @override
  Future<HomeworkSubmission> submitHomework({
    required String assignmentId,
    required List<String> photoPaths,
    required String comment,
    required String requestId,
  }) async {
    submitted.add((
      id: assignmentId,
      photos: photoPaths.length,
      comment: comment,
      requestId: requestId,
    ));
    return HomeworkSubmission(
      status: HomeworkStatus.submitted,
      photoCount: photoPaths.length,
      submittedAt: DateTime(2026, 11, 5, 15, 20),
    );
  }
}

const kSchoolToday = SchoolToday(
  schoolName: '24-maktab',
  className: '6-B',
  record: AttendanceRecord(
    status: AttendanceStatus.present,
    source: AttendanceSource.kiosk,
    inAt: '08:12',
  ),
);

final kSchoolTasks = [
  SchoolAssignment(
    id: 't1',
    kind: SchoolAssignmentKind.test,
    materialId: 'test:MATH',
    title: '',
    note: 'Har bir misolga bitta urinish. Kalkulyator ishlatma.',
    isOverdue: false,
    subject: Subject.math,
    dueDate: DateTime(2026, 11, 5),
    isDone: false,
    teacherName: 'Nigora Rahimova',
    estimatedMinutes: 15,
  ),
  SchoolAssignment(
    id: 'w1',
    kind: SchoolAssignmentKind.written,
    materialId: 'written',
    title: 'Insho: «Kuz»',
    note: 'Kamida bir sahifa yozing.',
    isOverdue: false,
    subject: Subject.native,
    dueDate: DateTime(2026, 11, 6),
    isDone: false,
    teacherName: 'Malika Tosheva',
  ),
  SchoolAssignment(
    id: 'a1',
    kind: SchoolAssignmentKind.audiobook,
    materialId: 'audiobook:b1',
    title: 'Oʻrmon sirlari',
    note: '',
    isOverdue: false,
    dueDate: DateTime(2026, 11, 3),
    isDone: true,
  ),
];

SchoolNoticePage kSchoolNotices() => SchoolNoticePage(
  unreadCount: 1,
  items: [
    SchoolNotice(
      id: 'n1',
      title: 'Ertaga kutubxonaga boramiz',
      body:
          'Ertaga 3-darsdan keyin maktab kutubxonasiga boramiz. Kitob kartangizni olib keling.',
      important: false,
      sentAt: DateTime(2026, 11, 5, 7, 55),
      authorName: 'Malika Tosheva',
      authorRole: 'HOMEROOM',
      forClass: true,
      className: '6-B',
      read: false,
    ),
    SchoolNotice(
      id: 'n2',
      title: 'Sport bayrami',
      body: 'Shanba kuni maktab hovlisida sport bayrami.',
      important: true,
      sentAt: DateTime(2026, 11, 1, 9),
      authorName: 'Ra’no Qodirova',
      authorRole: 'ADMIN',
      forClass: false,
      read: true,
    ),
  ],
);

AttendanceMonth kSchoolMonth() => AttendanceMonth(
  month: DateTime(2026, 11),
  days: [
    AttendanceDay(
      date: DateTime(2026, 11, 3),
      status: DayStatus.present,
      confirmed: true,
      inAt: '08:05',
      outAt: '13:40',
      kioskIn: '08:05',
      kioskOut: '13:40',
    ),
    AttendanceDay(
      date: DateTime(2026, 11, 4),
      status: DayStatus.unknown,
      confirmed: false,
    ),
    AttendanceDay(
      date: DateTime(2026, 11, 5),
      status: DayStatus.present,
      confirmed: false,
      inAt: '08:12',
      kioskIn: '08:12',
    ),
  ],
);

TimetableDay kSchoolDay() => TimetableDay(
  date: DateTime(kG5Now.year, kG5Now.month, kG5Now.day),
  weekday: kG5Now.weekday,
  className: '6-B',
  shiftName: '1-smena',
  published: true,
  lessons: const [
    TimetableLesson(
      periodNo: 1,
      start: '08:30',
      end: '09:15',
      subject: 'math',
      room: '204',
      teacherName: 'Nigora Rahimova',
    ),
    TimetableLesson(
      periodNo: 2,
      start: '09:25',
      end: '10:10',
      subject: 'native',
      room: '204',
    ),
    TimetableLesson(
      periodNo: 3,
      start: '10:20',
      end: '11:05',
      subject: 'english',
    ),
    TimetableLesson(
      periodNo: 4,
      start: '11:15',
      end: '12:00',
      subject: 'Jismoniy tarbiya',
    ),
  ],
);

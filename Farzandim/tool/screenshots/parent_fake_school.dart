// Skrinshot harness uchun soxta maktab ma'lumotlari (tarmoqsiz).
// Demo hikoya: Aziza Karimova (6-B) va Jasur Karimov (2-A), 24-maktab,
// bugun 9-noyabr 2026, dushanba.

// ignore_for_file: depend_on_referenced_packages

import 'package:dio/dio.dart';
import 'package:farzandim/features/growth/data/models/learning_subject.dart';
import 'package:farzandim/features/growth/data/models/learning_summary.dart';
import 'package:farzandim/features/iq/data/iq_summary.dart';
import 'package:farzandim/features/kelajak/data/models/kelajak_summary.dart';
import 'package:farzandim/features/school/data/models/school_announcement.dart';
import 'package:farzandim/features/school/data/models/school_attendance.dart';
import 'package:farzandim/features/school/data/models/school_connect.dart';
import 'package:farzandim/features/school/data/models/school_payment.dart';
import 'package:farzandim/features/school/data/models/student_overview.dart';
import 'package:farzandim/features/school/data/school_connect_repository.dart';
import 'package:farzandim/features/school/data/school_repository.dart';

class FakeSchoolRepository extends SchoolRepository {
  FakeSchoolRepository() : super(dio: Dio());

  @override
  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int limit = kAnnouncementsPageSize,
  }) async => AnnouncementPage(
    items: _announcements,
    page: 1,
    limit: limit,
    total: _announcements.length,
    totalPages: 1,
    unread: _announcements.where((a) => a.readAt == null).length,
  );

  @override
  Future<DateTime> markAnnouncementRead(String announcementId) async =>
      DateTime(2026, 11, 9, 9);

  @override
  Future<List<SchoolPaymentReminder>> fetchPayments() async => [
    SchoolPaymentReminder(
      id: 'pay-1',
      schoolId: 'sc-1',
      schoolName: '24-maktab',
      nextDate: '2026-11-15',
      prepaidMonths: 0,
      paused: false,
      children: const [
        PaymentChild(id: 'st-1', name: 'Aziza Karimova', className: '6-B'),
        PaymentChild(id: 'st-2', name: 'Jasur Karimov', className: '2-A'),
      ],
      openVerification: false,
      history: [
        PaymentHistoryEntry(
          action: PaymentAction.verified,
          at: DateTime(2026, 10, 14, 11, 20),
        ),
        PaymentHistoryEntry(
          action: PaymentAction.created,
          at: DateTime(2026, 9, 2, 9),
        ),
      ],
    ),
  ];

  @override
  Future<List<PaymentVerification>> fetchVerifications() async => [
    PaymentVerification(
      id: 'v-1',
      paymentReminderId: 'pay-1',
      schoolId: 'sc-1',
      schoolName: '24-maktab',
      nextDate: '2026-10-15',
      message: "Oktabr uchun Click orqali to'ladim, chek raqami 48213.",
      status: VerificationStatus.answered,
      answer: "Rahmat, to'lov qabul qilindi. Keyingi sana — 15-noyabr.",
      answeredAt: DateTime(2026, 10, 14, 11, 20),
      createdAt: DateTime(2026, 10, 13, 19, 5),
    ),
  ];

  @override
  Future<List<EarlyExitRequest>> fetchEarlyExits() async => [
    EarlyExitRequest(
      id: 'ee-1',
      studentId: 'st-1',
      classId: 'c-6b',
      date: '2026-11-09',
      time: '12:30',
      reason: 'Shifokor qabuli',
      pickupBy: 'Onasi — Nilufar',
      status: EarlyExitStatus.pending,
      studentName: 'Aziza Karimova',
      className: '6-B',
      requestedByMe: true,
      requestedAt: DateTime(2026, 11, 9, 7, 40),
    ),
    EarlyExitRequest(
      id: 'ee-2',
      studentId: 'st-2',
      classId: 'c-2a',
      date: '2026-11-03',
      time: '11:00',
      reason: 'Oilaviy tadbir',
      pickupBy: 'Otasi — Bobur',
      status: EarlyExitStatus.approved,
      studentName: 'Jasur Karimov',
      className: '2-A',
      requestedByMe: true,
      requestedAt: DateTime(2026, 11, 2, 20, 10),
      decidedAt: DateTime(2026, 11, 3, 8, 5),
    ),
  ];

  @override
  Future<MonthAttendance> fetchAttendance({
    required String studentId,
    String? month,
  }) async => demoMonth(studentId);
}

final _announcements = [
  SchoolAnnouncement(
    id: 'a-1',
    schoolId: 'sc-1',
    schoolName: '24-maktab',
    title: 'Ota-onalar majlisi — 14-noyabr, 18:00',
    body:
        "Hurmatli ota-onalar! 1-chorak yakunlari va qishki ta'til rejasi "
        "bo'yicha umumiy majlis 14-noyabr, shanba kuni soat 18:00 da "
        "maktab faollar zalida bo'lib o'tadi. Qatnashishingizni so'raymiz.",
    priority: AnnouncementPriority.important,
    sentAt: DateTime(2026, 11, 9, 8, 30),
    author: const AnnouncementAuthor(
      role: 'DIRECTOR',
      name: 'Karimov Akmal',
      position: 'Direktor',
    ),
    audience: const AnnouncementAudience(kind: AnnouncementAudienceKind.school),
  ),
  SchoolAnnouncement(
    id: 'a-2',
    schoolId: 'sc-1',
    schoolName: '24-maktab',
    title: 'Ertaga sport kiyimi bilan keling',
    body:
        "6-sinflar uchun ertaga 2-darsda «Sog'lom avlod» sport musobaqasi. "
        "Sport kiyimi va suv olib kelish so'raladi.",
    priority: AnnouncementPriority.normal,
    sentAt: DateTime(2026, 11, 8, 16, 10),
    author: const AnnouncementAuthor(
      role: 'HOMEROOM',
      name: 'Rasulova Malika',
      position: '',
    ),
    audience: const AnnouncementAudience(
      kind: AnnouncementAudienceKind.classes,
      classNames: ['6-A', '6-B'],
    ),
  ),
  SchoolAnnouncement(
    id: 'a-3',
    schoolId: 'sc-1',
    schoolName: '24-maktab',
    title: "Kuzgi ta'til jadvali",
    body:
        "Kuzgi ta'til 2-noyabrdan 8-noyabrgacha. Darslar 9-noyabr, "
        "dushanba kuni odatdagi jadval bo'yicha boshlanadi.",
    priority: AnnouncementPriority.normal,
    sentAt: DateTime(2026, 10, 30, 12),
    readAt: DateTime(2026, 10, 30, 19),
    author: const AnnouncementAuthor(
      role: 'ADMIN',
      name: 'Yusupova Dilnoza',
      position: "Direktor o'rinbosari",
    ),
    audience: const AnnouncementAudience(kind: AnnouncementAudienceKind.school),
  ),
];

/// Noyabr oyi (bugun — 9-noyabr): turli holatlar, yakshanba — dam olish.
MonthAttendance demoMonth(String studentId) {
  const marks = <int, (AttendanceStatus, String?, String?)>{
    2: (AttendanceStatus.present, '08:05', '13:30'),
    3: (AttendanceStatus.late, '08:41', '13:30'),
    4: (AttendanceStatus.present, '08:10', '13:30'),
    5: (AttendanceStatus.absent, null, null),
    6: (AttendanceStatus.present, '08:02', '12:15'),
    7: (AttendanceStatus.leftEarly, '08:07', '11:20'),
    9: (AttendanceStatus.present, '08:12', null),
  };
  final days = <AttendanceDay>[];
  for (var d = 1; d <= 30; d++) {
    final date = '2026-11-${d.toString().padLeft(2, '0')}';
    final weekend = DateTime(2026, 11, d).weekday == DateTime.sunday;
    final mark = marks[d];
    days.add(
      AttendanceDay(
        date: date,
        schoolDay: !weekend,
        record: mark == null
            ? null
            : AttendanceRecord(status: mark.$1, inAt: mark.$2, outAt: mark.$3),
      ),
    );
  }
  return MonthAttendance(
    student: AttendanceStudent(
      id: studentId,
      name: studentId == 'st-1' ? 'Karimova Aziza' : 'Karimov Jasur',
      className: studentId == 'st-1' ? '6-B' : '2-A',
      schoolName: '24-maktab',
    ),
    month: '2026-11',
    days: days,
    summary: const AttendanceSummary(
      present: 4,
      late: 1,
      absent: 1,
      leftEarly: 1,
      excused: 0,
      pending: 0,
      total: 7,
    ),
    rate: 86,
  );
}

// ── Maktab bilan bog'lanish ───────────────────────────────────────────

const _aziza = ConnectStudent(
  id: 'st-1',
  name: 'Karimova Aziza',
  className: '6-B',
  schoolName: '24-maktab',
);

const demoContacts = SchoolContacts(
  student: _aziza,
  contacts: [
    SchoolContact(
      staffId: 'stf-h',
      fullName: 'Rasulova Malika',
      role: StaffRole.homeroom,
      position: "Ona tili va adabiyot o'qituvchisi",
      group: ContactGroup.classTeacher,
      threadId: 'th-1',
      unread: 1,
    ),
    SchoolContact(
      staffId: 'stf-d',
      fullName: 'Karimov Akmal',
      role: StaffRole.director,
      position: 'Direktor',
      group: ContactGroup.leadership,
    ),
    SchoolContact(
      staffId: 'stf-a',
      fullName: 'Yusupova Dilnoza',
      role: StaffRole.admin,
      position: "Direktor o'rinbosari",
      group: ContactGroup.leadership,
    ),
    SchoolContact(
      staffId: 'stf-p',
      fullName: 'Ergasheva Nodira',
      role: StaffRole.psychologist,
      position: 'Maktab psixologi',
      group: ContactGroup.support,
    ),
    SchoolContact(
      staffId: 'stf-t1',
      fullName: 'Tursunov Bekzod',
      role: StaffRole.teacher,
      position: "Matematika o'qituvchisi",
      group: ContactGroup.subject,
    ),
    SchoolContact(
      staffId: 'stf-t2',
      fullName: 'Aliyeva Shahlo',
      role: StaffRole.teacher,
      position: "Ingliz tili o'qituvchisi",
      group: ContactGroup.subject,
    ),
  ],
);

final demoThread = SchoolThread(
  id: 'th-1',
  resolved: false,
  schoolName: '24-maktab',
  staff: demoContacts.contacts.first,
  student: _aziza,
  lastFromStaff: true,
  available: true,
  unread: 1,
  lastMessageAt: DateTime(2026, 11, 9, 8, 14),
  preview:
      'Rahmat, xabar uchun. Tuzalib keting, Aziza! '
      "Uy vazifasini Telegram guruhga tashlab qo'yaman.",
  messages: [
    ThreadMessage(
      id: 'm-1',
      author: MessageAuthor.parent,
      topic: ContactTopic.absence,
      body:
          'Assalomu alaykum, ustoz. Farzandim Aziza bugun darsga kela olmaydi. '
          'Sababi: isitmasi chiqib qoldi, shifokorga boryapmiz.',
      createdAt: DateTime(2026, 11, 9, 7, 32),
      seen: true,
    ),
    ThreadMessage(
      id: 'm-2',
      author: MessageAuthor.staff,
      body:
          'Vaalaykum assalom! Rahmat, xabar uchun. Tuzalib keting, Aziza! '
          "Uy vazifasini Telegram guruhga tashlab qo'yaman.",
      createdAt: DateTime(2026, 11, 9, 8, 14),
    ),
    ThreadMessage(
      id: 'm-3',
      author: MessageAuthor.parent,
      body: "Katta rahmat! Ertaga ma'lumotnoma olib boradi.",
      createdAt: DateTime(2026, 11, 9, 8, 20),
    ),
  ],
);

class FakeSchoolConnectRepository extends SchoolConnectRepository {
  FakeSchoolConnectRepository() : super(dio: Dio());

  @override
  Future<SchoolContacts> fetchContacts(String studentId) async => demoContacts;

  @override
  Future<SchoolThreads> fetchThreads() async =>
      SchoolThreads(items: [demoThread], unread: 1);

  @override
  Future<SchoolThread> fetchThread(String threadId) async => demoThread;

  @override
  Future<void> markThreadRead(String threadId) async {}

  @override
  Future<StudentOverview> fetchOverview(String studentId) async => demoOverview;
}

const demoOverview = StudentOverview(
  student: _aziza,
  period: OverviewPeriod(
    isQuarter: true,
    number: 2,
    from: '2026-11-09',
    to: '2026-11-20',
  ),
  attendance: OverviewAttendance(
    present: 36,
    late: 3,
    absent: 1,
    leftEarly: 1,
    excused: 1,
    pending: 0,
    total: 42,
    rate: 95,
    onTimeStreak: 12,
    averageArrival: '08:09',
    classRate: 92,
    weeks: [
      WeekRate(weekStart: '2026-09-28', rate: 100),
      WeekRate(weekStart: '2026-10-05', rate: 83),
      WeekRate(weekStart: '2026-10-12', rate: 100),
      WeekRate(weekStart: '2026-10-19', rate: 100),
      WeekRate(weekStart: '2026-10-26', rate: 67),
      WeekRate(weekStart: '2026-11-02'),
      WeekRate(weekStart: '2026-11-09', rate: 100),
      WeekRate(weekStart: '2026-11-16', rate: 100),
    ],
  ),
  tasks: OverviewTasks(
    total: 8,
    submitted: 6,
    accepted: 5,
    returned: 1,
    pending: 0,
    overdue: 1,
    classSubmitRate: 74,
    items: [
      OverviewTask(
        id: 't-1',
        title: 'Tarix: Amir Temur haqida qisqa referat',
        dueDate: '2026-11-18',
        state: TaskState.overdue,
        teacher: "Tarix o'qituvchisi",
      ),
      OverviewTask(
        id: 't-2',
        title: 'Ona tili: «Mening Vatanim» mavzusida insho',
        dueDate: '2026-11-21',
        state: TaskState.todo,
        teacher: 'Sinf rahbari',
      ),
      OverviewTask(
        id: 't-3',
        title: "Matematika: 34-mashq (kasrlarni qo'shish)",
        dueDate: '2026-11-17',
        state: TaskState.returned,
        teacher: "Matematika o'qituvchisi",
      ),
    ],
  ),
);

const demoGrowth = LearningSummary(
  from: '2026-10-21',
  to: '2026-11-19',
  periodDays: 30,
  testsCount: 24,
  correctAnswers: 196,
  totalAnswers: 240,
  activeDays: 19,
  streakDays: 6,
  overallPercent: 82,
  subjects: [
    SubjectStat(subject: LearningSubject.math, percent: 88, tests: 7),
    SubjectStat(subject: LearningSubject.english, percent: 79, tests: 5),
    SubjectStat(subject: LearningSubject.native, percent: 91, tests: 5),
    SubjectStat(subject: LearningSubject.history, percent: 64, tests: 4),
    SubjectStat(subject: LearningSubject.biology, percent: 73, tests: 3),
  ],
);

final demoIq = IqSummary.fromJson(const {
  'age': {'status': 'OK'},
  'last': {
    'correct': 21,
    'total': 30,
    'status': 'PROVISIONAL',
    'percentile': 72,
    'band': 'ABOVE_AVERAGE',
    'completedAt': '2026-11-02T10:00:00.000Z',
    'domains': <Object>[],
  },
  'history': <Object>[],
  'nextAvailableAt': '2027-02-02T00:00:00.000Z',
});

final demoKelajak = KelajakSummary.fromJson(const {
  'age': {'status': 'OK'},
  'sessionsCompleted': 3,
});

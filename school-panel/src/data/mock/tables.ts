import type {
  Announcement,
  AttendanceEvent,
  AttendanceRecord,
  AuditLog,
  CareQuestion,
  CareRequest,
  CareResponse,
  CareSurvey,
  ClassActivity,
  DeviceState,
  EarlyExitRequest,
  EmergencyState,
  Guardian,
  Holiday,
  LearningAssignment,
  LearningMaterial,
  ParentNotification,
  PaymentReminder,
  Reminder,
  School,
  SchoolClass,
  SchoolModeException,
  SchoolModePolicy,
  Shift,
  Staff,
  StaffNotification,
  Student,
  StudentNote,
  TemplateId,
  TemplateState,
  PsychAssignment,
  PsychHistoryConfig,
  PsychResult,
  PsychTest,
  VerificationRequest,
} from '@/data/contracts';

/**
 * Mock bazadagi barcha jadvallar. Yangi jadval qo'shilsa — `db.ts` dagi yumshoq
 * migratsiya (MIGRATIONS) orqali (SCHEMA_VERSION oshirilsa foydalanuvchi ma'lumoti o'chadi).
 */
export type Tables = {
  school: School;
  shifts: Shift[];
  classes: SchoolClass[];
  holidays: Holiday[];
  staff: Staff[];
  students: Student[];
  guardians: Guardian[];
  /** Bugungi yozuvlar va o'tgan kunlardagi TUZATILGAN yozuvlar (qolgani hisoblanadi). */
  attendance: AttendanceRecord[];
  attendanceEvents: AttendanceEvent[];
  earlyExits: EarlyExitRequest[];
  parentNotifications: ParentNotification[];
  policies: SchoolModePolicy[];
  exceptions: SchoolModeException[];
  devices: DeviceState[];
  emergency: EmergencyState;
  announcements: Announcement[];
  reminders: Reminder[];
  payments: PaymentReminder[];
  verifications: VerificationRequest[];
  careQuestions: CareQuestion[];
  careSurveys: CareSurvey[];
  careResponses: CareResponse[];
  careRequests: CareRequest[];
  materials: LearningMaterial[];
  assignments: LearningAssignment[];
  activity: ClassActivity[];
  audit: AuditLog[];
  /** Psixologik testlar: maktabning o'z / import qilingan testlari (shablonlar kodda). */
  psychTests: PsychTest[];
  psychTemplateState: Record<TemplateId, TemplateState>;
  psychAssignments: PsychAssignment[];
  /** Saqlangan natijalar (ilova, import, qo'lda). O'tgan choraklar `psychHistory` dan hisoblanadi. */
  psychResults: PsychResult[];
  psychHistory: PsychHistoryConfig;
  /** Xodim bildirishnomalari (xavfsizlik signali, test yakunlandi) — max 200. */
  notifications: StaffNotification[];
  studentNotes: StudentNote[];
  /** Simulyator holati: qaysi sana va qaysi daqiqagacha qayta ishlangan. */
  sim: { date: string; processedUntilMinute: number };
};

export type DbSnapshot = {
  schemaVersion: number;
  seed: number;
  generatedAt: string;
  /** Seed qaysi "bugun"ga nisbatan yaratilgan (nisbiy sanalar uchun). */
  baseDate: string;
  tables: Tables;
};

import type {
  Announcement,
  CardKind,
  CardStatus,
  CardTapResult,
  AttendanceEvent,
  AttendanceRecord,
  AuditLog,
  CareQuestion,
  CareRequest,
  CareSettings,
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
  SubmissionRecord,
  TemplateId,
  TimetableRecord,
  TemplateState,
  PsychAssignment,
  PsychHistoryConfig,
  PsychResult,
  PsychTest,
  VerificationRequest,
} from '@/data/contracts';
import type { AccessTables } from './access-tables';
import type { MockParentThread } from './seed/parent-threads';

/** NFC karta (mock): kontrakt ko'rinishi o'quvchi nomlarisiz (ro'yxatda qo'shiladi). */
export type MockCard = {
  id: string;
  number: string;
  uid: string;
  kind: CardKind;
  status: CardStatus;
  studentId: string;
  issuedAt: string;
  lastTapAt: string | null;
  blockedAt: string | null;
  blockedReason: string | null;
};

export type MockCardTap = {
  id: string;
  tappedAt: string;
  cardId: string | null;
  studentId: string | null;
  uid: string | null;
  result: CardTapResult;
  suspicious: boolean;
  kioskId: string;
};

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
  /** Bola ovozi sozlamalari; `null` — saqlanmagan (standart qiymatlar). */
  careSettings: CareSettings | null;
  materials: LearningMaterial[];
  assignments: LearningAssignment[];
  /** Yozma vazifalar bo'yicha o'quvchilar topshirgan ishlar. */
  submissions: SubmissionRecord[];
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
  /** Sinflarning haftalik dars jadvali (sinfga bitta yozuv). */
  timetables: TimetableRecord[];
  /** Kirish (5-bosqich): bola profiliga ulanish, kirish ma'lumotlari holati, 6 xonali kodlar, so'rovlar. Parol saqlanmaydi. */
  access: AccessTables;
  /** Ota-onalar xodimga yozgan xabarlar (har xodim faqat o'zinikini ko'radi). */
  parentThreads: MockParentThread[];
  /** NFC kartalar va kiosk tegishlari jurnali (max 500). */
  cards: MockCard[];
  cardTaps: MockCardTap[];
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

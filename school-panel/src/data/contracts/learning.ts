import type { Id, IsoDate, IsoDateTime } from './common';

export type MaterialKind = 'AUDIOBOOK' | 'VIDEO' | 'TEST';
/** Topshiriq turi: katalog materiali yoki o'qituvchi yozgan YOZMA vazifa (`materialId: 'written'`). */
export type AssignmentKind = MaterialKind | 'WRITTEN';
export type Subject =
  | 'MATH'
  | 'ENGLISH'
  | 'HISTORY'
  | 'LITERATURE'
  | 'GEOGRAPHY'
  | 'BIOLOGY'
  | 'IT'
  | 'NATIVE'
  | 'PHYSICS'
  | 'CHEMISTRY'
  | 'RUSSIAN';

export type LearningMaterial = {
  id: Id;
  kind: MaterialKind;
  title: string;
  subject: Subject;
  grades: number[];
  durationMin: number;
  questions: number; // test bo'lsa
};

export type LearningAssignment = {
  id: Id;
  materialId: Id;
  classIds: Id[];
  dueDate: IsoDate;
  /** Yozma vazifada — ko'rsatma (≤ 300), boshqalarda — izoh. */
  note: string;
  createdAt: IsoDateTime;
  byStaffId: Id;
  /** Faqat YOZMA vazifada: sarlavha (majburiy, ≤ 120). */
  title?: string | null;
  /** Taxminiy vaqt, daqiqa (1–240); barcha turlarda ixtiyoriy. */
  estimatedMinutes?: number | null;
};

export type SubmissionStatus = 'SUBMITTED' | 'ACCEPTED' | 'RETURNED';
/** Jadvaldagi holat: topshirmagan o'quvchida yuborilgan ish yo'q. */
export type SubmissionState = 'NOT_SUBMITTED' | SubmissionStatus;

/** Bola yuborgan rasm. `url` — imzolangan mutlaq havola (~1 soat amal qiladi). */
export type SubmissionPhoto = { id: Id; url: string };

export type HomeworkSubmission = {
  id: Id;
  status: SubmissionStatus;
  /** Bolaning izohi. */
  comment: string | null;
  submittedAt: IsoDateTime;
  reviewedAt: IsoDateTime | null;
  /** Qaytarishdagi (yoki qabuldagi) o'qituvchi izohi. */
  reviewNote: string | null;
  photos: SubmissionPhoto[];
};

/** `GET /school/learning/assignments/:id/submissions` qatori: sinf o'quvchisi va uning ishi (yo'q bo'lsa `null`). */
export type StudentSubmissionRow = {
  student: { id: Id; fullName: string };
  classId: Id;
  submission: HomeworkSubmission | null;
};

/** Mock baza yozuvi (rasmlar — faqat identifikator; havola o'qishda yasaladi). */
export type SubmissionRecord = {
  id: Id;
  assignmentId: Id;
  studentId: Id;
  status: SubmissionStatus;
  comment: string;
  submittedAt: IsoDateTime;
  reviewedAt: IsoDateTime | null;
  reviewNote: string | null;
  photoIds: Id[];
};

export type ClassActivity = {
  classId: Id;
  weekStart: IsoDate;
  activeStudents: number;
  completedTasks: number;
  avgScore: number; // 0..100
  donPoints: number;
};

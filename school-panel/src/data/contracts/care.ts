import type { HhMm, Id, IsoDate, IsoDateTime } from './common';
import type { RoleKey } from './people';

export type AgeGroup = 'G1_4' | 'G5_8' | 'G9_11';
export type CareTopic = 'WELLBEING' | 'LEARNING' | 'PEERS' | 'SAFETY' | 'SUPPORT' | 'FEEDBACK';

export type CareQuestion = {
  id: Id;
  topic: CareTopic;
  ageGroups: AgeGroup[];
  text: { uz: string; ru: string };
  /** 1..5 shkala; `reverse` — yuqori javob yomon belgini bildiradi (masalan "ranjitishdimi?"). */
  reverse: boolean;
  active: boolean;
};

export type CareSurveyStatus = 'DRAFT' | 'ACTIVE' | 'CLOSED';
export type CareSurvey = {
  id: Id;
  title: string;
  weekStart: IsoDate;
  ageGroups: AgeGroup[];
  questionIds: Id[];
  status: CareSurveyStatus;
  invited: number;
  /** Faollashtirilgan vaqt (simulyatsiya javoblari shundan boshlanadi). */
  activatedAt?: IsoDateTime | null;
};

/** Xom javob — FAQAT psixolog yo'li o'qiydi; umumlashgan servis bu jadvalga tegmaydi. */
export type CareResponse = {
  id: Id;
  surveyId: Id;
  studentId: Id;
  classId: Id;
  grade: number;
  answers: Record<Id, number>; // questionId → 1..5
  submittedAt: IsoDateTime;
};

export type CareUrgency = 'NORMAL' | 'URGENT';
export type CareRequestStatus = 'NEW' | 'IN_PROGRESS' | 'SCHEDULED' | 'RESOLVED';
export type CareTopicTag = 'LEARNING' | 'PEERS' | 'BULLYING' | 'FAMILY' | 'EMOTIONS' | 'SAFETY' | 'OTHER';

export type CareNote = { at: IsoDateTime; byStaffId: Id; text: string };

/**
 * Bola ↔ psixolog yozishmasi (kontrakt B). Ichki eslatma (`CareNote`) bundan ALOHIDA:
 * bola faqat yozishmani ko'radi, eslatmani hech qachon.
 */
export type CareMessageAuthor = 'CHILD' | 'STAFF';
export type CareMessage = {
  id: Id;
  author: CareMessageAuthor;
  /** Xodim xabarida — xodimning to'liq ismi; bola xabarida null. */
  authorName: string | null;
  text: string;
  createdAt: IsoDateTime;
};
/** Mock jadvalidagi xabar: muallif xodim ID bilan, xodim o'qigan vaqti bilan. */
export type CareStoredMessage = {
  id: Id;
  author: CareMessageAuthor;
  staffId: Id | null;
  text: string;
  createdAt: IsoDateTime;
  readByStaffAt: IsoDateTime | null;
};
export type CareStaffRef = { id: Id; name: string };

/** Saqlangan murojaat (mock jadvali). Kontrakt B ustunlariga mos: ochilgan/javob/yopilgan/o'tkazilgan vaqtlar. */
export type CareRequest = {
  id: Id;
  studentId: Id;
  classId: Id;
  createdAt: IsoDateTime;
  topic: CareTopicTag;
  message: string;
  urgency: CareUrgency;
  status: CareRequestStatus;
  meetingAt: IsoDateTime | null;
  notes: CareNote[];
  /** Shoshilinch protokol ishga tushirilganmi (kim xabardor qilindi — eslatmada). */
  protocolActivated: boolean;
  messages: CareStoredMessage[];
  /** Murojaat uchun javobgar xodim (yaratilganda — mas'ul psixolog, muddat o'tsa — o'rinbosar). */
  assignedStaffId: Id | null;
  /** Xodim birinchi marta ko'rgan vaqt. */
  openedAt: IsoDateTime | null;
  openedByStaffId: Id | null;
  /** Bolaga birinchi javob. */
  repliedAt: IsoDateTime | null;
  resolvedAt: IsoDateTime | null;
  /** Muddat ichida ochilmagani uchun o'rinbosarga o'tkazilgan vaqt. */
  escalatedAt: IsoDateTime | null;
  lastMessageAt: IsoDateTime | null;
};

export type CareNoteView = CareNote & { byName: string };
export type CareNotified = { role: RoleKey; name: string };

/** Murojaatlar qutisidagi qator (panel ko'rinishi): ism, sinf va yozishma holati bilan. */
export type CareRequestRow = Pick<
  CareRequest,
  'id' | 'studentId' | 'classId' | 'createdAt' | 'topic' | 'message' | 'urgency' | 'status' | 'meetingAt' | 'protocolActivated'
> & {
  studentName: string;
  className: string;
  /** Ichki eslatmalar soni; backend ro'yxatda bermasa — null (chip ko'rsatilmaydi). */
  notesCount: number | null;
  openedAt: IsoDateTime | null;
  repliedAt: IsoDateTime | null;
  escalatedAt: IsoDateTime | null;
  /** Bola yozgan, xodim hali o'qimagan xabarlar soni. */
  unreadFromChild: number;
  assignedTo: CareStaffRef | null;
};
export type CareRequestDetail = Omit<CareRequestRow, 'notesCount'> & {
  notesCount: number;
  notes: CareNoteView[];
  notified: CareNotified[];
  /** Xronologik: eski → yangi. */
  messages: CareMessage[];
  openedBy: CareStaffRef | null;
  resolvedAt: IsoDateTime | null;
};
export type CareRequestFilter = { status?: CareRequestStatus; urgency?: CareUrgency; search?: string };
export type CareRequestList = { items: CareRequestRow[]; counts: Record<CareRequestStatus, number> };

/** Umumlashgan natija — shaxsga bog'liq maydon YO'Q. */
export type CareAggregateGroup = {
  key: string;
  label: string;
  respondents: number;
  hidden: boolean;
  /** 0..100 — yaxshi holat ko'rsatkichi (yuqori = yaxshi). null — yashirin. */
  topicScores: Partial<Record<CareTopic, number>> | null;
};

export type CareAggregate = {
  surveyId: Id;
  invited: number;
  respondents: number;
  participationRate: number;
  overall: Partial<Record<CareTopic, number>>;
  groups: CareAggregateGroup[];
  weeklyTrend: Array<{ weekStart: IsoDate; wellbeing: number; respondents: number }>;
  /** Murojaatlar — faqat haftalik umumiy son, kichik bo'lsa "<5". */
  requestsThisWeek: string;
};

/**
 * Bola ovozi sozlamalari: mas'ul psixolog, navbatchi o'rinbosar, bolaga ko'rinadigan ismlar,
 * ish vaqti va javob muddati (SLA, ish vaqti hisobida). Saqlangan yozuv yo'q bo'lsa — standart qiymatlar,
 * `updatedAt: null`.
 */
export type CareSettings = {
  psychologistStaffId: Id | null;
  /** Bola ilovasida ko'rinadigan ism (masalan «Dilnoza opa»); bo'sh bo'lsa — xodimning to'liq ismi. */
  psychologistDisplayName: string | null;
  deputyStaffId: Id | null;
  deputyDisplayName: string | null;
  /** ISO hafta kunlari (1 = dushanba … 7 = yakshanba), takrorlanmaydi. */
  workDays: number[];
  /** "HH:MM" (Toshkent vaqti). */
  workStart: HhMm;
  workEnd: HhMm;
  /** Shoshilinch murojaat: ochilish muddati, ish vaqti daqiqalarida. */
  urgentSlaMinutes: number;
  /** Oddiy murojaat: ochilish muddati, ish vaqti soatlarida. */
  normalSlaHours: number;
  /** Saqlangan yozuv yo'q (standart qiymatlar) bo'lsa — null. */
  updatedAt: IsoDateTime | null;
};

/** Mas'ul va o'rinbosar tanlovi: faqat faol PSIXOLOG xodimlar. */
export type CareStaffOption = { id: Id; fullName: string };
export type CareSettingsView = CareSettings & { staffOptions: CareStaffOption[] };

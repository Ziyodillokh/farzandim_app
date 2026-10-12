import type { Id, IsoDate, IsoDateTime } from './common';

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
};

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

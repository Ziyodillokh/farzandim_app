// Rivojlanish — javob shakllari (panel `school-panel/src/data/contracts/development.ts`
// bilan bir xil). Indeks 0..100: yuqori = kuchliroq / yaxshiroq holat.

import type { AbilityBand, AgeBand, DevDomain, IsoDate, Localized, ScaleScore, ScoreBand } from '../assessments/psych/types';
import type { PsychResultOrigin } from '../assessments/psych/types';

export type DomainValue = { domain: DevDomain; index: number | null; band: ScoreBand | null; takenAt: string | null };

/** Profil natijasi (panel `ScoredResult & { testTitle }`). */
export type ProfileResult = {
  id: string;
  studentId: string;
  classId: string;
  grade: number;
  ageBand: AgeBand;
  testId: string;
  version: number;
  assignmentId: string | null;
  takenAt: string;
  origin: PsychResultOrigin;
  raw: Record<string, number>;
  answers?: string;
  durationSec?: number;
  scales: ScaleScore[];
  topCodes: string | null;
  testTitle: Localized;
};

export type StudentDevProfile = {
  student: { id: string; name: string; className: string; grade: number; ageBand: AgeBand };
  latest: DomainValue[];
  /** Sinfdoshlar o'rtachasi (n ≥ K bo'lsa). */
  classAverage: Partial<Record<DevDomain, number>>;
  timeline: Array<{ termKey: string; date: IsoDate; values: Partial<Record<DevDomain, number>> }>;
  career: { topCodes: string; raw: Record<string, number>; takenAt: string } | null;
  /** Psixolog: javoblar bilan; sinf rahbari: javoblarsiz, xom ballsiz. */
  results: ProfileResult[];
  context: {
    attendance30: { rate: number | null; late: number; absent: number } | null;
    classLearning: { activeRate: number; avgScore: number | null; suppressed: boolean } | null;
  };
  canSeeRaw: boolean;
};

export type DomainIndexValue = { domain: DevDomain; index: number | null };

export type DevelopmentSummary =
  | { mode: 'AGGREGATE'; termKey: string; participation: number; domains: DomainIndexValue[] }
  | { mode: 'CLASS'; classId: string; className: string; assessed: number; total: number; domains: DomainIndexValue[] }
  | { mode: 'PSYCHOLOGIST'; activeAssignments: number; completedThisWeek: number; attention: number; domains: DomainIndexValue[] };

export type SchoolDevOverview = {
  termKey: string;
  /** Psixolog bo'lmaganlar uchun k-anonim yashirish qo'llangan. */
  suppressed: boolean;
  participation: { assessed: number; eligible: number; rate: number };
  domainAverages: Array<{ domain: DevDomain; index: number | null; n: number }>;
  cognitiveByGrade: Array<{ grade: number; n: number; hidden: boolean; meanStandard: number | null; bands: Record<AbilityBand, number> | null }>;
  /** Maktab darajasida qo'pol taqsimot (K dan kichik katak — null). */
  cognitiveCoarse: { below: number | null; within: number | null; above: number | null } | null;
  trend: Array<{ termKey: string; n: number; values: Partial<Record<DevDomain, number>> }>;
  heat: Array<{ classId: string; className: string; grade: number; n: number; hidden: boolean; cells: Partial<Record<DevDomain, number | null>> }>;
  attentionCount: string | null;
};

export type ClassDevRow = {
  studentId: string;
  name: string;
  assessedAt: string | null;
  domains: Partial<Record<DevDomain, { index: number | null; band: ScoreBand | null }>>;
  attention: boolean;
};

export type ClassDevOverview = {
  classId: string;
  className: string;
  termKey: string;
  assessed: number;
  total: number;
  domainAverages: DomainIndexValue[];
  schoolAverages: Partial<Record<DevDomain, number>>;
  rows: ClassDevRow[];
};

export type AttentionReason = 'COG_LOW' | 'ATT_LOW' | 'EMO_SUPPORT' | 'SELF_LOW' | 'DECLINE' | 'MISSED';
export type AttentionRow = { studentId: string; name: string; className: string; classId: string; reasons: AttentionReason[]; lastTakenAt: string | null };

/** Jonli ro'yxat (faqat ko'rsatish, qamrov va kirish huquqi uchun — guruhlash uchun EMAS). */
export type LiveClass = { id: string; name: string; grade: number; letter: string };
export type LiveStudent = {
  id: string;
  classId: string | null;
  lastName: string;
  firstName: string;
  archived: boolean;
  enrolledAt: string;
  birthDate: string;
};
export type Roster = { classes: readonly LiveClass[]; students: readonly LiveStudent[] };

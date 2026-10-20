import type { AbilityBand, AgeBand, DevDomain, Localized, ScoreBand, ScoredResult } from './assessments';
import type { Id, IsoDate, IsoDateTime } from './common';

/** Ko'rinish modellari (servis → UI). Indeks 0..100: yuqori = kuchliroq / yaxshiroq holat. */
export type DomainValue = { domain: DevDomain; index: number | null; band: ScoreBand | null; takenAt: IsoDateTime | null };

export type StudentDevProfile = {
  student: { id: Id; name: string; className: string; grade: number; ageBand: AgeBand };
  latest: DomainValue[];
  /** Sinfdoshlar o'rtachasi (n ≥ K bo'lsa); psixologdan boshqaga EMOTIONAL yo'q. */
  classAverage: Partial<Record<DevDomain, number>>;
  timeline: Array<{ termKey: string; date: IsoDate; values: Partial<Record<DevDomain, number>> }>;
  career: { topCodes: string; raw: Record<string, number>; takenAt: IsoDateTime } | null;
  /** Psixolog: javoblar bilan; sinf rahbari: javoblarsiz, xom ballsiz. */
  results: Array<ScoredResult & { testTitle: Localized }>;
  context: {
    attendance30: { rate: number | null; late: number; absent: number } | null;
    /** Oxirgi YOPIQ (yakunlangan) hafta; 5 nafardan kam faol bo'lsa ball yashiriladi (`suppressed`, avgScore = null). */
    classLearning: { activeRate: number; avgScore: number | null; suppressed: boolean } | null;
  };
  canSeeRaw: boolean;
};

export type DevelopmentSummary =
  | { mode: 'AGGREGATE'; termKey: string; participation: number; domains: Array<{ domain: DevDomain; index: number | null }> }
  | { mode: 'CLASS'; classId: Id; className: string; assessed: number; total: number; domains: Array<{ domain: DevDomain; index: number | null }> }
  | { mode: 'PSYCHOLOGIST'; activeAssignments: number; completedThisWeek: number; attention: number; domains: Array<{ domain: DevDomain; index: number | null }> };

export type SchoolDevOverview = {
  termKey: string;
  /** Psixolog bo'lmaganlar uchun k-anonim yashirish qo'llangan. */
  suppressed: boolean;
  participation: { assessed: number; eligible: number; rate: number };
  domainAverages: Array<{ domain: DevDomain; index: number | null; n: number }>;
  cognitiveByGrade: Array<{
    grade: number;
    n: number;
    hidden: boolean;
    meanStandard: number | null;
    /** Faqat psixologga (yashirilganda null). */
    bands: Record<AbilityBand, number> | null;
  }>;
  /** Maktab darajasida qo'pol taqsimot (K dan kichik katak — null). */
  cognitiveCoarse: { below: number | null; within: number | null; above: number | null } | null;
  trend: Array<{ termKey: string; n: number; values: Partial<Record<DevDomain, number>> }>;
  heat: Array<{ classId: Id; className: string; grade: number; n: number; hidden: boolean; cells: Partial<Record<DevDomain, number | null>> }>;
  attentionCount: string | null;
};

export type ClassDevRow = {
  studentId: Id;
  name: string;
  assessedAt: IsoDateTime | null;
  domains: Partial<Record<DevDomain, { index: number | null; band: ScoreBand | null }>>;
  attention: boolean;
};
export type ClassDevOverview = {
  classId: Id;
  className: string;
  termKey: string;
  assessed: number;
  total: number;
  /** Psixologdan boshqaga EMOTIONAL yo'q (index null yoki umuman qaytmaydi). */
  domainAverages: Array<{ domain: DevDomain; index: number | null }>;
  schoolAverages: Partial<Record<DevDomain, number>>;
  rows: ClassDevRow[];
};

export type AttentionReason = 'COG_LOW' | 'ATT_LOW' | 'EMO_SUPPORT' | 'SELF_LOW' | 'DECLINE' | 'MISSED';
export type AttentionRow = { studentId: Id; name: string; className: string; classId: Id; reasons: AttentionReason[]; lastTakenAt: IsoDateTime | null };

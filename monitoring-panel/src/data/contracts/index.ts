/**
 * UI ↔ ma'lumot kontraktlari. Demo (mock) va kelajakdagi haqiqiy API bir xil
 * shakllarni qaytaradi — sahifalar manbani bilmaydi.
 * Foizlar 0..100, `null` — ma'lumot yetarli emas (K-anonimlik) yoki mavjud emas.
 */
import type { Period } from '@/data/mock/model/calendar';
import type { MetricKey } from '@/data/mock/model/metrics';
import type {
  AppCategory,
  CareerField,
  CareTopic,
  GenderFilter,
  Grade,
  GradeBand,
  Interest,
  IqDisplayBand,
  IqDomain,
  Level,
  Mood,
  Riasec,
  SchoolType,
  Subject,
  WellbeingTopic,
} from '@/data/reference/domains';
import type { RegionId } from '@/data/reference/regions';

export type { MetricKey } from '@/data/mock/model/metrics';
export type { MetricDef, MetricDomain, MetricUnit } from '@/data/mock/model/metrics';
export type { Period } from '@/data/mock/model/calendar';

export type Filters = {
  period: Period;
  grades: GradeBand;
  gender: GenderFilter;
  schoolType: 'ALL' | SchoolType;
};

export type Scope = { kind: 'NATIONAL' } | { kind: 'REGION'; regionId: RegionId };

/** Bitta ko'rsatkich: joriy qiymat, taqqoslash (o'tgan yilning shu davri) va farq. */
export type Stat = {
  value: number | null;
  base: number | null;
  delta: number | null;
  n: number;
};

export type SeriesPoint = { key: string; value: number | null };

export type Kpi = Stat & { key: MetricKey; series: SeriesPoint[]; national?: number | null };

/** Hudud yoki tuman bo'yicha qiymat. */
export type AreaStat = Stat & { id: string; name: string; rank: number | null };

export type ShareItem<K extends string> = { key: K; share: number; delta?: number | null };
/** Ulush yashirilgan bo'lishi mumkin: guruh K-anonimlik chegarasidan kichik — `null` (o'qitilmagan fan — 0). */
export type MaybeShareItem<K extends string> = { key: K; share: number | null };

export type PeriodInfo = {
  period: Period;
  /** "2026/2027" */
  ayLabel: string;
  quarter: 1 | 2 | 3 | 4 | null;
  months: string[];
  baselineMonths: string[];
  asOf: string;
};

export type Counts = {
  official: number;
  covered: number;
  schools: number;
  privateSchools: number;
  schoolsConnected: number;
  districts: number;
};

export type Overview = {
  period: PeriodInfo;
  scope: Scope;
  counts: Counts;
  kpis: Kpi[];
};

export type AreaMetric = {
  metric: MetricKey;
  /** Taqqoslash uchun: respublika qiymati. */
  national: Stat;
  /** Tanlangan doira qiymati (respublika yoki hudud). */
  scopeValue: Stat;
  /** Respublika doirasida — 14 hudud, hudud doirasida — tumanlar. */
  areas: AreaStat[];
  level: 'REGION' | 'DISTRICT';
};

export type SubjectStat = Stat & { subject: Subject; interest: number | null; success: number | null; national: number | null };

export type Mastery = {
  overall: Stat;
  success: Stat;
  tests: Stat;
  national: { overall: number | null };
  bySubject: SubjectStat[];
  byGrade: Array<{ grade: Grade; value: number | null }>;
  byGender: Array<{ gender: 'M' | 'F'; value: number | null }>;
  bySchoolType: Array<{ type: SchoolType; value: number | null }>;
  trend: SeriesPoint[];
  /** Hudud/tuman × fan. */
  heat: Array<{ id: string; name: string; values: Record<Subject, number | null>; overall: number | null }>;
  /** Adaptiv qiyinlik darajalari ulushi (1–3). */
  difficulty: { level1: number; level2: number; level3: number };
};

export type Iq = {
  participation: Stat;
  mean: Stat;
  high: Stat;
  growthZone: Stat;
  /** Hamma natija NORMED (≥300 ta birinchi urinish) bo'lsa — standart ball ko'rsatiladi. */
  normed: boolean;
  participants: number;
  bands: Array<ShareItem<IqDisplayBand>>;
  domains: Array<{ domain: IqDomain; value: number | null; national: number | null }>;
  byArea: Array<{ id: string; name: string; bands: Record<IqDisplayBand, number> | null; mean: number | null; participation: number | null }>;
  byGradeBand: Array<{ band: Exclude<GradeBand, 'ALL'>; mean: number | null; participation: number | null }>;
  byGender: Array<{ gender: 'M' | 'F'; mean: number | null }>;
  trend: SeriesPoint[];
};

export type Interests = {
  subjects: Array<MaybeShareItem<Subject> & { mastery: number | null }>;
  general: Array<MaybeShareItem<Interest>>;
  riasec: Array<{ code: Riasec; score: number | null; national: number | null }>;
  riasecTop: Array<ShareItem<Riasec>>;
  careerFields: Array<ShareItem<CareerField>>;
  careerReadiness: Stat;
  byArea: Array<{ id: string; name: string; topSubject: Subject | null; topSubjectShare: number | null; topCode: Riasec | null; topField: CareerField | null }>;
  byGender: Array<{ gender: 'M' | 'F'; subjects: Array<MaybeShareItem<Subject>> }>;
};

export type Wellbeing = {
  index: Stat;
  level: Level | null;
  topics: Array<{ topic: WellbeingTopic; score: number | null; level: Level | null; national: number | null }>;
  bullying: Stat;
  support: Stat;
  watch: Stat;
  anxiety: Stat;
  sleep: Stat;
  careRequests: Stat;
  urgentShare: number | null;
  careTopics: Array<ShareItem<CareTopic>>;
  sos: number | null;
  safetyGap: Stat;
  schoolQuality: Stat;
  teacherRelation: Stat;
  byGrade: Array<{ grade: Grade; wellbeing: number | null; bullying: number | null; anxiety: number | null }>;
  byGender: Array<{ gender: 'M' | 'F'; wellbeing: number | null; bullying: number | null; anxiety: number | null }>;
  trend: SeriesPoint[];
  bullyingTrend: SeriesPoint[];
  respondents: number;
};

export type Attendance = {
  rate: Stat;
  late: Stat;
  chronic: Stat;
  statuses: { onTime: number; late: number; leftEarly: number; excused: number; absent: number } | null;
  /** Erta ketishlar — 100 o'quvchi-kunga. */
  earlyExits: Stat;
  byMonth: SeriesPoint[];
  byWeekday: Array<{ day: 1 | 2 | 3 | 4 | 5 | 6; value: number | null }>;
  byGrade: Array<{ grade: Grade; value: number | null }>;
  bySchoolType: Array<{ type: SchoolType; value: number | null }>;
};

export type Digital = {
  screenTime: Stat;
  night: Stat;
  schoolMode: Stat;
  steps: Stat;
  sleep: Stat;
  devices: number;
  schoolDay: number | null;
  weekend: number | null;
  categories: Array<ShareItem<AppCategory>>;
  hourly: number[];
  moods: Array<ShareItem<Mood>>;
  byGrade: Array<{ grade: Grade; screenTime: number | null; night: number | null }>;
  byGender: Array<{ gender: 'M' | 'F'; screenTime: number | null; game: number | null }>;
  trend: SeriesPoint[];
};

/** Hudud yoki tuman qatori: bir nechta ko'rsatkich bir vaqtda. */
export type AreaRow = {
  id: string;
  name: string;
  official: number;
  covered: number;
  values: Partial<Record<MetricKey, Stat>>;
};

/** Doira ichidagi bo'linmalar × ko'rsatkichlar matritsasi. */
export type AreaMatrix = {
  level: 'REGION' | 'DISTRICT';
  metrics: MetricKey[];
  /** Doiraning o'zi (respublika yoki hudud) — taqqoslash uchun. */
  scope: Partial<Record<MetricKey, Stat>>;
  rows: AreaRow[];
};

export type RegionRow = {
  id: RegionId;
  name: string;
  official: number;
  covered: number;
  values: Partial<Record<MetricKey, Stat>>;
};

export type SchoolTypeStat = {
  type: SchoolType;
  schools: number;
  pupils: number;
  mastery: number | null;
  attendance: number | null;
  wellbeing: number | null;
  iqMean: number | null;
};

export type SchoolRow = {
  id: string;
  code: string;
  districtId: string;
  districtName: string;
  regionId: RegionId;
  type: SchoolType;
  pupils: number;
  mastery: number | null;
  growth: number | null;
  attendance: number | null;
  wellbeing: number | null;
};

export type Schools = {
  types: SchoolTypeStat[];
  topGrowth: SchoolRow[];
  needSupport: SchoolRow[];
  districts: Array<{ id: string; name: string; schools: number; mastery: number | null; attendance: number | null; wellbeing: number | null }>;
};

export type InsightSeverity = 'positive' | 'watch' | 'attention';
export type Insight = {
  id: string;
  severity: InsightSeverity;
  /** i18n kaliti `insights.<kind>`. */
  kind: string;
  params: Record<string, string | number>;
  metric: MetricKey | null;
  areaId: string | null;
  /** Batafsil sahifa (basePath'siz). */
  href: string;
};

/** Jadval sahifalash va saralash (DataTable). */
export type SortDir = 'asc' | 'desc';
export type Pagination = { page: number; limit: number; total: number; totalPages: number };

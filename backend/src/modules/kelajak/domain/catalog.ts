// Kelajak katalogi: 12 kategoriya (JSON'dagi tartib), javob turlari, RIASEC
// kodlari va test turlari. Savollar soni FAQAT `KELAJAK_TESTS`da turadi
// (docs/KELAJAK-REJA.md §3).

import type { L } from './localized';

export const KELAJAK_CATEGORY_IDS = [
  'career_interest',
  'learning',
  'school_quality',
  'teacher_relation',
  'safety',
  'wellbeing',
  'social_self',
  'career_lab',
  'career_planning',
  'parent_communication',
  'child_voice',
  'personal_traits',
] as const;
export type KelajakCategory = (typeof KELAJAK_CATEGORY_IDS)[number];

/**
 * Kategoriya qanday ishlatiladi: `scored` — o'rtacha ball (kuchli tomon /
 * rivojlanish), `interest` — RIASEC, `support` — qo'llab-quvvatlash signali
 * (ball ko'rsatilmaydi), `career_lab` — faoliyat reytingi, `voice` — ochiq matn.
 */
export type KelajakCategoryKind = 'interest' | 'scored' | 'support' | 'career_lab' | 'voice';

export interface KelajakCategoryDef {
  id: KelajakCategory;
  order: number;
  kind: KelajakCategoryKind;
  name: L;
}

export const KELAJAK_CATEGORIES: readonly KelajakCategoryDef[] = [
  {
    id: 'career_interest',
    order: 1,
    kind: 'interest',
    name: { uz: 'Kasbiy qiziqishlar', ru: 'Профессиональные интересы', en: 'Career interests' },
  },
  {
    id: 'learning',
    order: 2,
    kind: 'scored',
    name: {
      uz: 'Fanlar va o‘rganish tajribasi',
      ru: 'Предметы и опыт обучения',
      en: 'Subjects and learning experience',
    },
  },
  {
    id: 'school_quality',
    order: 3,
    kind: 'scored',
    name: { uz: 'Maktab sifati va darslar', ru: 'Школа и уроки', en: 'School and lessons' },
  },
  {
    id: 'teacher_relation',
    order: 4,
    kind: 'scored',
    name: {
      uz: 'O‘qituvchi bilan munosabat',
      ru: 'Отношения с учителями',
      en: 'Relationship with teachers',
    },
  },
  {
    id: 'safety',
    order: 5,
    kind: 'support',
    name: { uz: 'Xavfsizlik va bullying', ru: 'Безопасность и буллинг', en: 'Safety and bullying' },
  },
  {
    id: 'wellbeing',
    order: 6,
    kind: 'support',
    name: {
      uz: 'Ruhiy farovonlik va stress',
      ru: 'Эмоциональное благополучие и стресс',
      en: 'Wellbeing and stress',
    },
  },
  {
    id: 'social_self',
    order: 7,
    kind: 'scored',
    name: {
      uz: 'Ijtimoiy ko‘nikmalar va o‘zini anglash',
      ru: 'Социальные навыки и самопознание',
      en: 'Social skills and self-awareness',
    },
  },
  {
    id: 'career_lab',
    order: 8,
    kind: 'career_lab',
    name: {
      uz: 'Career Lab — kasbni amalda sinash',
      ru: 'Career Lab — пробуем профессии на практике',
      en: 'Career Lab — trying careers in practice',
    },
  },
  {
    id: 'career_planning',
    order: 9,
    kind: 'scored',
    name: {
      uz: 'Kasbga tayyorgarlik va rejalashtirish',
      ru: 'Подготовка к профессии и планирование',
      en: 'Career readiness and planning',
    },
  },
  {
    id: 'parent_communication',
    order: 10,
    kind: 'scored',
    name: { uz: 'Ota-ona bilan muloqot', ru: 'Общение с родителями', en: 'Communication with parents' },
  },
  {
    id: 'child_voice',
    order: 11,
    kind: 'voice',
    name: {
      uz: 'Bola ovozi — ochiq fikr va murojaat',
      ru: 'Голос ребёнка — открытое мнение',
      en: 'Child’s voice — open feedback',
    },
  },
  {
    id: 'personal_traits',
    order: 12,
    kind: 'scored',
    name: { uz: 'Shaxsiy xususiyatlar', ru: 'Личные качества', en: 'Personal traits' },
  },
];

const CATEGORY_BY_ID: ReadonlyMap<string, KelajakCategoryDef> = new Map(
  KELAJAK_CATEGORIES.map((c) => [c.id, c]),
);

/** Kuchli tomon / rivojlanish hisoblanadigan kategoriyalar (§3). */
export const SCORED_CATEGORY_IDS = [
  'learning',
  'school_quality',
  'teacher_relation',
  'social_self',
  'career_planning',
  'parent_communication',
  'personal_traits',
] as const satisfies readonly KelajakCategory[];
export type ScoredCategory = (typeof SCORED_CATEGORY_IDS)[number];

/** Qo'llab-quvvatlash signali kategoriyalari — raqamlari hech qayerda ko'rsatilmaydi. */
export const SUPPORT_CATEGORY_IDS = ['wellbeing', 'safety'] as const satisfies readonly KelajakCategory[];
export type SupportCategory = (typeof SUPPORT_CATEGORY_IDS)[number];

export function isSupportCategory(id: string): id is SupportCategory {
  return (SUPPORT_CATEGORY_IDS as readonly string[]).includes(id);
}

/**
 * wellbeing / safety savolining signal turi (`scoring.signal`): `distress` —
 * holat (qo'llab-quvvatlash signaliga kiradi, standart), `knowledge` —
 * xavfsizlik bilimi / ko'nikmasi (signalga kirmaydi; past bo'lsa — maslahat).
 */
export const SUPPORT_SIGNAL_KINDS = ['distress', 'knowledge'] as const;
export type SupportSignalKind = (typeof SUPPORT_SIGNAL_KINDS)[number];
export const DEFAULT_SUPPORT_SIGNAL: SupportSignalKind = 'distress';

export function isSupportSignalKind(value: unknown): value is SupportSignalKind {
  return typeof value === 'string' && (SUPPORT_SIGNAL_KINDS as readonly string[]).includes(value);
}

/** Xavfsizlik bilimi bo'yicha rivojlanish kaliti (kategoriya emas — `knowledge` savollari). */
export const SAFETY_RULES_GROWTH = 'safety_rules' as const;
/** Rivojlanish yorliqlari: ballanadigan kategoriyalar + xavfsizlik qoidalari. */
export type GrowthKey = ScoredCategory | typeof SAFETY_RULES_GROWTH;
export const GROWTH_KEYS: readonly GrowthKey[] = [...SCORED_CATEGORY_IDS, SAFETY_RULES_GROWTH];

/**
 * Ota-onaga ko'rsatilmaydigan ballanadigan kategoriyalar: "ota-onadan yordam
 * so'rash xavfsizmi" kabi javoblar aynan ota-onaga qaytmasin (bola halol
 * javob bersin). Bolaning o'ziga ko'rinadi.
 */
export const PARENT_HIDDEN_CATEGORY_IDS = ['parent_communication'] as const satisfies readonly ScoredCategory[];

export function isParentVisibleCategory(id: string): boolean {
  return !(PARENT_HIDDEN_CATEGORY_IDS as readonly string[]).includes(id);
}

/** JSON'dagi `scoring.method` qiymatlari. */
export const KELAJAK_SCORING_METHODS = [
  'simple_sum',
  'dimension_sum',
  'support_signal',
  'reflection_rating',
] as const;

export function isKelajakCategory(value: unknown): value is KelajakCategory {
  return typeof value === 'string' && CATEGORY_BY_ID.has(value);
}

export function categoryDef(id: string): KelajakCategoryDef | null {
  return CATEGORY_BY_ID.get(id) ?? null;
}

/** Kategoriya tartibi (noma'lum — oxirida). */
export function categoryOrder(id: string): number {
  return CATEGORY_BY_ID.get(id)?.order ?? Number.MAX_SAFE_INTEGER;
}

export function categoryKind(id: string): KelajakCategoryKind | null {
  return CATEGORY_BY_ID.get(id)?.kind ?? null;
}

// ─── Javob turlari ───────────────────────────────────────────────────

export const KELAJAK_ANSWER_TYPES = [
  'interest_4',
  'likert_5',
  'career_lab_5',
  'text',
  'frequency_5',
  'yes_no',
  'support_4',
] as const;
export type KelajakAnswerType = (typeof KELAJAK_ANSWER_TYPES)[number];

/** Ixtiyoriy turlar: Career Lab refleksiyasi va ochiq matn (§3 "Majburiylik"). */
const OPTIONAL_ANSWER_TYPES: ReadonlySet<KelajakAnswerType> = new Set(['career_lab_5', 'text']);

/** Ochiq javob — hech qachon majburiy emas (bola matn yozishga majburlanmaydi, §3). */
export const TEXT_ANSWER_TYPE = 'text' satisfies KelajakAnswerType;

/** Ochiq javob matni chegarasi (API `maxLength`). */
export const TEXT_ANSWER_MAX_LENGTH = 1000;

export function isKelajakAnswerType(value: unknown): value is KelajakAnswerType {
  return typeof value === 'string' && (KELAJAK_ANSWER_TYPES as readonly string[]).includes(value);
}

/** `required` qoidasi: shkala turlari majburiy, `career_lab_5` va `text` — yo'q. */
export function defaultRequired(answerType: KelajakAnswerType): boolean {
  return !OPTIONAL_ANSWER_TYPES.has(answerType);
}

// ─── RIASEC ──────────────────────────────────────────────────────────

export const RIASEC_CODES = ['R', 'I', 'A', 'S', 'E', 'C'] as const;
export type RiasecCode = (typeof RIASEC_CODES)[number];

export function isRiasecCode(value: unknown): value is RiasecCode {
  return typeof value === 'string' && (RIASEC_CODES as readonly string[]).includes(value);
}

// ─── Test turlari ────────────────────────────────────────────────────

export const KELAJAK_TEST_TYPES = [
  'daily',
  'career',
  'wellbeing',
  'learning',
  'self',
  'career_lab',
  'voice',
] as const;
export type KelajakTestType = (typeof KELAJAK_TEST_TYPES)[number];

export interface KelajakTestConfig {
  type: KelajakTestType;
  /** Sessiyadagi savollar soni (nomzod kam bo'lsa — boricha). */
  count: number;
  /** "Hammasi" kategoriyalari — birinchi kiritiladi. */
  full: readonly KelajakCategory[];
  /** Aylanma kategoriyalar — qolgan joylarni to'ldiradi. */
  rotating: readonly KelajakCategory[];
  /** Bitta kategoriyadan ko'pi bilan (null — chegara yo'q). */
  perCategoryMax: number | null;
  estimatedMinutes: number;
}

const DAILY_CATEGORIES = KELAJAK_CATEGORY_IDS.filter(
  (c) => c !== 'career_lab' && c !== 'child_voice',
);

export const KELAJAK_TESTS: Readonly<Record<KelajakTestType, KelajakTestConfig>> = {
  daily: {
    type: 'daily',
    count: 10,
    full: [],
    rotating: DAILY_CATEGORIES,
    perCategoryMax: 2,
    estimatedMinutes: 3,
  },
  career: {
    type: 'career',
    count: 20,
    full: ['career_interest'],
    rotating: ['career_planning'],
    perCategoryMax: null,
    estimatedMinutes: 6,
  },
  wellbeing: {
    type: 'wellbeing',
    count: 8,
    full: ['wellbeing'],
    rotating: ['safety'],
    perCategoryMax: null,
    estimatedMinutes: 3,
  },
  learning: {
    type: 'learning',
    count: 10,
    full: [],
    rotating: ['learning', 'school_quality', 'teacher_relation'],
    perCategoryMax: 4,
    estimatedMinutes: 3,
  },
  self: {
    type: 'self',
    count: 10,
    full: [],
    rotating: ['social_self', 'personal_traits', 'parent_communication'],
    perCategoryMax: 4,
    estimatedMinutes: 3,
  },
  career_lab: {
    type: 'career_lab',
    count: 5,
    full: ['career_lab'],
    rotating: [],
    perCategoryMax: null,
    estimatedMinutes: 2,
  },
  voice: {
    type: 'voice',
    count: 3,
    full: ['child_voice'],
    rotating: [],
    perCategoryMax: null,
    estimatedMinutes: 3,
  },
};

export function isKelajakTestType(value: unknown): value is KelajakTestType {
  return typeof value === 'string' && (KELAJAK_TEST_TYPES as readonly string[]).includes(value);
}

/** Test turiga mos barcha kategoriyalar. */
export function testCategories(config: KelajakTestConfig): KelajakCategory[] {
  return [...config.full, ...config.rotating];
}

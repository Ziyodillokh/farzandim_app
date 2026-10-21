/**
 * Parvoz Kelajak savollar banki — admin panel uchun YAGONA ro'yxatlar.
 *
 * Kontrakt: docs/KELAJAK-REJA.md §6. Kategoriya nomlari va shkala
 * yorliqlari `backend/prisma/data/kelajak/parvoz_question_bank_278.json`dan
 * aynan olingan (`categories`, `answer_scales`) — import qilingan savollar
 * bilan bir xil ko'rinsin.
 */

export interface KelajakOptionPreset {
  value: number;
  uz: string;
}

/** 12 kategoriya — JSON'dagi tartibda (bola ilovasi ham shu tartibni oladi). */
export const KELAJAK_CATEGORIES = [
  { value: 'career_interest', label: 'Kasbiy qiziqishlar' },
  { value: 'learning', label: 'Fanlar va o‘rganish tajribasi' },
  { value: 'school_quality', label: 'Maktab sifati va darslar' },
  { value: 'teacher_relation', label: 'O‘qituvchi bilan munosabat' },
  { value: 'safety', label: 'Xavfsizlik va bullying' },
  { value: 'wellbeing', label: 'Ruhiy farovonlik va stress' },
  { value: 'social_self', label: 'Ijtimoiy ko‘nikmalar va o‘zini anglash' },
  { value: 'career_lab', label: 'Career Lab — kasbni amalda sinash' },
  { value: 'career_planning', label: 'Kasbga tayyorgarlik va rejalashtirish' },
  { value: 'parent_communication', label: 'Ota-ona bilan muloqot' },
  { value: 'child_voice', label: 'Bola ovozi — ochiq fikr va murojaat' },
  { value: 'personal_traits', label: 'Shaxsiy xususiyatlar' },
] as const;

export const KELAJAK_AGE_GROUPS = [
  { value: '7-9', label: '7–9 yosh' },
  { value: '10-12', label: '10–12 yosh' },
  { value: '13-15', label: '13–15 yosh' },
  { value: '16-18', label: '16–18 yosh' },
] as const;

export const KELAJAK_ANSWER_TYPES = [
  { value: 'interest_4', label: 'Qiziqish (4 ball)' },
  { value: 'likert_5', label: 'Likert (5 ball)' },
  { value: 'career_lab_5', label: 'Career Lab bahosi (5 ball)' },
  { value: 'frequency_5', label: 'Chastota (5 ball)' },
  { value: 'yes_no', label: 'Ha / Yo‘q' },
  { value: 'support_4', label: 'Qiyin – oson (4 ball)' },
  { value: 'text', label: 'Ochiq javob (matn)' },
] as const;

export const TEXT_ANSWER_TYPE = 'text';

/**
 * Standart variantlar. interest_4 va likert_5 — backend `review-overrides.json`
 * `scaleLabels` bilan bir xil ("-mi?" savolga mos "Ha / Yo'q"); qolganlari JSON
 * `answer_scales` bilan aynan bir xil.
 */
export const ANSWER_TYPE_PRESETS: Record<string, readonly KelajakOptionPreset[]> = {
  interest_4: [
    { value: 1, uz: 'Yo‘q' },
    { value: 2, uz: 'Unchalik emas' },
    { value: 3, uz: 'Ha' },
    { value: 4, uz: 'Ha, juda' },
  ],
  likert_5: [
    { value: 1, uz: 'Yo‘q' },
    { value: 2, uz: 'Ko‘proq yo‘q' },
    { value: 3, uz: 'Ba’zan' },
    { value: 4, uz: 'Ko‘proq ha' },
    { value: 5, uz: 'Ha' },
  ],
  career_lab_5: [
    { value: 1, uz: 'Juda yoqmadi' },
    { value: 2, uz: 'Yoqmadi' },
    { value: 3, uz: 'Betarafman' },
    { value: 4, uz: 'Yoqdi' },
    { value: 5, uz: 'Juda yoqdi' },
  ],
  frequency_5: [
    { value: 1, uz: 'Hech qachon' },
    { value: 2, uz: 'Kamdan-kam' },
    { value: 3, uz: 'Ba’zan' },
    { value: 4, uz: 'Ko‘pincha' },
    { value: 5, uz: 'Deyarli har doim' },
  ],
  yes_no: [
    { value: 1, uz: 'Yo‘q' },
    { value: 2, uz: 'Ha' },
  ],
  support_4: [
    { value: 1, uz: 'Juda qiyin' },
    { value: 2, uz: 'Biroz qiyin' },
    { value: 3, uz: 'Oson' },
    { value: 4, uz: 'Juda oson' },
  ],
  text: [],
};

/**
 * Majburiylik qoidasi (§3): shkalalar majburiy; Career Lab refleksiyasi va
 * ochiq javob ixtiyoriy. Admin shkalani qo'lda o'zgartirishi mumkin, ochiq
 * javob esa hech qachon majburiy bo'lmaydi (backend rad etadi).
 */
export function defaultRequiredFor(answerType: string): boolean {
  return answerType !== 'career_lab_5' && answerType !== TEXT_ANSWER_TYPE;
}

/** Backend validatsiyasi bilan bir xil chegaralar (§6, `bank.ts` TEXT_LIMITS). */
export const KELAJAK_LIMITS = {
  textMax: 500,
  optionLabelMax: 120,
  followUpMax: 500,
  noteMax: 1000,
  optionsMin: 2,
  optionsMax: 10,
} as const;

export const EXTERNAL_ID_PATTERN = /^[A-Z0-9-]{3,40}$/;
/** Bank savollari nomlar fazosi — admin bu prefiks bilan ID bera olmaydi. */
export const RESERVED_EXTERNAL_ID_PREFIX = 'PARVOZ-';

/** Manba turi filtri (bank importi va admin qo'shgan savollar). */
export const KELAJAK_SOURCE_TYPES = [
  { value: 'parvoz_original', label: 'Parvoz banki' },
  { value: 'parvoz_admin', label: 'Admin qo‘shgan' },
] as const;

/** RIASEC yo'nalishlari — backend `texts-riasec.ts` nomlari bilan bir xil. */
export const RIASEC_OPTIONS = [
  { value: 'R', label: 'R — Amaliy' },
  { value: 'I', label: 'I — Tadqiqotchi' },
  { value: 'A', label: 'A — Ijodiy' },
  { value: 'S', label: 'S — Ijtimoiy' },
  { value: 'E', label: 'E — Tashabbuskor' },
  { value: 'C', label: 'C — Tartibli' },
] as const;

/** wellbeing / safety savolining signal turi (`scoring.signal`, standart — distress). */
export const SIGNAL_OPTIONS = [
  { value: 'distress', label: 'Holat — qo‘llab-quvvatlash signaliga kiradi' },
  { value: 'knowledge', label: 'Xavfsizlik bilimi — faqat maslahat' },
] as const;

/** Javob berilgan (yoki bugungi ochiq sessiyadagi) savolda o'zgarmaydigan maydonlar (§6, PATCH). */
export const LOCKED_FIELD_LABELS = [
  'kategoriya',
  'yosh guruhi',
  'javob turi',
  'variantlar',
  'ball o‘lchami',
  'teskari belgisi',
] as const;

const labelMap = (list: ReadonlyArray<{ value: string; label: string }>) =>
  new Map<string, string>(list.map((item) => [item.value, item.label]));

const CATEGORY_LABELS = labelMap(KELAJAK_CATEGORIES);
const AGE_GROUP_LABELS = labelMap(KELAJAK_AGE_GROUPS);
const ANSWER_TYPE_LABELS = labelMap(KELAJAK_ANSWER_TYPES);

export const categoryLabel = (id: string) => CATEGORY_LABELS.get(id) ?? id;
export const ageGroupLabel = (id: string) => AGE_GROUP_LABELS.get(id) ?? id;
export const answerTypeLabel = (id: string) => ANSWER_TYPE_LABELS.get(id) ?? id;

export const isKnownCategory = (id: string) => CATEGORY_LABELS.has(id);
export const isKnownAgeGroup = (id: string) => AGE_GROUP_LABELS.has(id);
export const isKnownAnswerType = (id: string) => ANSWER_TYPE_LABELS.has(id);

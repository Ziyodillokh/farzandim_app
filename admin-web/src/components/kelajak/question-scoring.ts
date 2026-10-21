/**
 * Savolning ball o'lchami — `scoring` obyektidagi kategoriyaga bog'liq teg
 * (docs/KELAJAK-REJA.md §3, §6):
 * - career_interest: RIASEC `dimension` (majburiy — backend busiz 400 qaytaradi);
 * - career_lab: RIASEC `riasec` (ixtiyoriy — umumiy faoliyat kodsiz);
 * - wellbeing / safety: `signal` (`distress` — standart, `knowledge` — xavfsizlik bilimi).
 * Qolgan scoring maydonlari (method, interpretation, note, ...) saqlanadi.
 */
import { RIASEC_OPTIONS, SIGNAL_OPTIONS, TEXT_ANSWER_TYPE } from '@/lib/constants/kelajak';

export type ScoringRecord = Record<string, unknown>;

export interface ScoringTagSpec {
  /** `scoring` ichidagi kalit. */
  key: 'dimension' | 'riasec' | 'signal';
  label: string;
  hint: string;
  options: ReadonlyArray<{ value: string; label: string }>;
  /** Tanlamasdan saqlab bo'lmaydi. */
  required: boolean;
  /** Bo'sh tanlov yorlig'i (ixtiyoriy teg uchun). */
  emptyLabel: string | null;
  /** Teg yo'q bo'lsa shu qiymat ko'rsatiladi. */
  fallback: string;
  /** Yangi scoring uchun `method`. */
  method: string;
}

const SIGNAL_SPEC: ScoringTagSpec = {
  key: 'signal',
  label: 'Signal turi',
  hint: 'Bilim savoli qo‘llab-quvvatlash signaliga kirmaydi — past bo‘lsa faqat maslahat beriladi',
  options: SIGNAL_OPTIONS,
  required: true,
  emptyLabel: null,
  fallback: 'distress',
  method: 'support_signal',
};

const SPECS: Readonly<Record<string, ScoringTagSpec>> = {
  career_interest: {
    key: 'dimension',
    label: 'RIASEC yo‘nalishi',
    hint: 'Qiziqish profili shu yo‘nalish bo‘yicha hisoblanadi',
    options: RIASEC_OPTIONS,
    required: true,
    emptyLabel: null,
    fallback: '',
    method: 'dimension_sum',
  },
  career_lab: {
    key: 'riasec',
    label: 'Faoliyat yo‘nalishi (RIASEC)',
    hint: 'Kod bo‘lsa, faoliyat shu qiziqishdagi bolaga “sinab ko‘r” deb tavsiya qilinadi',
    options: RIASEC_OPTIONS,
    required: false,
    emptyLabel: 'Umumiy faoliyat (kodsiz)',
    fallback: '',
    method: 'reflection_rating',
  },
  wellbeing: SIGNAL_SPEC,
  safety: SIGNAL_SPEC,
};

export function scoringTagSpec(category: string): ScoringTagSpec | null {
  return Object.prototype.hasOwnProperty.call(SPECS, category) ? SPECS[category] : null;
}

/** Bazadagi scoring'dan forma qiymati (noma'lum / yo'q — standart). */
export function scoringTagFrom(category: string, scoring: ScoringRecord | null): string {
  const spec = scoringTagSpec(category);
  if (!spec) return '';
  const value = scoring?.[spec.key];
  return typeof value === 'string' && spec.options.some((o) => o.value === value) ? value : spec.fallback;
}

export interface ScoringInput {
  category: string;
  answerType: string;
  tag: string;
  optionValues: readonly number[];
}

/** Ball variantlar oralig'idan normallashtiriladi — backend min/max'ni shu bilan tekshiradi. */
const bounds = (values: readonly number[]) =>
  values.length > 0 ? { min: Math.min(...values), max: Math.max(...values) } : {};

/** Signal tegida min/max yo'q (bankdagi kabi); RIASEC teglarida — bor. */
const usesBounds = (spec: ScoringTagSpec, base: ScoringRecord) =>
  spec.key !== 'signal' || 'min' in base || 'max' in base;

/** Yangi savol: teg kerak bo'lsa scoring, aks holda yuborilmaydi (backend `null` yozadi). */
export function createScoring(input: ScoringInput): ScoringRecord | undefined {
  const spec = scoringTagSpec(input.category);
  if (!spec || input.answerType === TEXT_ANSWER_TYPE || !input.tag) return undefined;
  if (spec.key === 'signal' && input.tag === spec.fallback) return undefined;
  return {
    method: spec.method,
    [spec.key]: input.tag,
    ...(usesBounds(spec, {}) ? bounds(input.optionValues) : {}),
  };
}

/**
 * Tahrir: kategoriya yoki teg o'zgargandagina yangi scoring (asl maydonlar
 * saqlanadi); aks holda `undefined` — yuborilmaydi, backend variantlarga
 * o'zi moslaydi. Ochiq javobda ham yuborilmaydi (backend `null` qiladi).
 */
export function patchScoring(
  input: ScoringInput,
  original: { category: string; scoring: ScoringRecord | null },
): ScoringRecord | undefined {
  const spec = scoringTagSpec(input.category);
  if (!spec || input.answerType === TEXT_ANSWER_TYPE) return undefined;
  const categoryChanged = input.category !== original.category;
  const tagChanged = input.tag !== scoringTagFrom(original.category, original.scoring);
  if (!categoryChanged && !tagChanged) return undefined;
  const base = original.scoring ?? {};
  const rest = Object.fromEntries(Object.entries(base).filter(([key]) => key !== spec.key));
  const method = !categoryChanged && typeof base.method === 'string' ? base.method : spec.method;
  return {
    ...rest,
    method,
    ...(input.tag ? { [spec.key]: input.tag } : {}),
    ...(usesBounds(spec, base) ? bounds(input.optionValues) : {}),
  };
}

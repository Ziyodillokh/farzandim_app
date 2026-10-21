// Savolning `scoring` obyekti — faqat ma'lum maydonlar (oq ro'yxat), har biri
// tekshiriladi; noma'lum kalit yoki ichma-ich qiymat rad etiladi (admin
// ixtiyoriy JSON saqlay olmasin). Kalitlar tartibi saqlanadi — migratsiya
// generatori baytma-bayt barqaror bo'lsin (docs/KELAJAK-REJA.md §2, §6).

import {
  isRiasecCode,
  isSupportSignalKind,
  KELAJAK_SCORING_METHODS,
  KelajakAnswerType,
  KelajakCategory,
  RiasecCode,
} from './catalog';

export type ScoringRecord = Record<string, unknown>;
export type ScoringResult = { ok: true; value: ScoringRecord | null } | { ok: false; error: string };

/** Qisqa matnli maydonlar chegarasi. */
export const SCORING_TEXT_LIMITS = { dimension: 40, interpretation: 80, direction: 40, note: 200 } as const;

/** Maydon tekshiruvi: muammo matni yoki `null`. */
type FieldRule = (value: unknown) => string | null;

const shortText =
  (max: number): FieldRule =>
  (value) =>
    typeof value === 'string' && value.trim().length > 0 && value.length <= max
      ? null
      : `1..${max} belgili satr kerak`;

const integer: FieldRule = (value) => (Number.isInteger(value) ? null : 'butun son kerak');

const SCORING_FIELDS: Readonly<Record<string, FieldRule>> = {
  method: (value) =>
    (KELAJAK_SCORING_METHODS as readonly unknown[]).includes(value)
      ? null
      : `bittasi kerak: ${KELAJAK_SCORING_METHODS.join(', ')}`,
  dimension: shortText(SCORING_TEXT_LIMITS.dimension),
  min: integer,
  max: integer,
  interpretation: shortText(SCORING_TEXT_LIMITS.interpretation),
  direction: shortText(SCORING_TEXT_LIMITS.direction),
  note: shortText(SCORING_TEXT_LIMITS.note),
  /** wellbeing / safety: `distress` (standart) yoki `knowledge`. */
  signal: (value) => (isSupportSignalKind(value) ? null : 'distress yoki knowledge'),
  /** Career Lab faoliyatining RIASEC kodi. */
  riasec: (value) => (isRiasecCode(value) ? null : 'RIASEC kodi kerak (R, I, A, S, E, C)'),
};

const isPlainObject = (v: unknown): v is ScoringRecord => !!v && typeof v === 'object' && !Array.isArray(v);

const hasOwn = (record: object, key: string) => Object.prototype.hasOwnProperty.call(record, key);

const RIASEC_REQUIRED = 'scoring.dimension: career_interest uchun RIASEC kodi kerak';

/** Oq ro'yxat bo'yicha tekshirib, yangi obyekt (kalitlar tartibi saqlanadi). */
function whitelisted(raw: ScoringRecord): ScoringResult {
  for (const [key, value] of Object.entries(raw)) {
    if (!hasOwn(SCORING_FIELDS, key)) return { ok: false, error: `scoring.${key}: noma'lum maydon` };
    const problem = SCORING_FIELDS[key](value);
    if (problem) return { ok: false, error: `scoring.${key}: ${problem}` };
  }
  return { ok: true, value: { ...raw } };
}

export function parseScoring(
  raw: unknown,
  answerType: KelajakAnswerType,
  category: KelajakCategory,
  optionValues: readonly number[],
): ScoringResult {
  if (raw === undefined || raw === null) {
    return category === 'career_interest' ? { ok: false, error: RIASEC_REQUIRED } : { ok: true, value: null };
  }
  if (!isPlainObject(raw)) return { ok: false, error: 'scoring: obyekt yoki null' };
  if (answerType === 'text') return { ok: false, error: 'scoring: text turida bo\'lmaydi' };
  const parsed = whitelisted(raw);
  if (!parsed.ok || parsed.value === null) return parsed;
  const scoring = parsed.value;
  if (category === 'career_interest' && !isRiasecCode(scoring.dimension)) {
    return { ok: false, error: RIASEC_REQUIRED };
  }
  // Ball variantlar oralig'idan normallashtiriladi — scoring min/max mos bo'lsin.
  const bounds = [['min', Math.min(...optionValues)], ['max', Math.max(...optionValues)]] as const;
  for (const [key, expected] of bounds) {
    if (scoring[key] !== undefined && scoring[key] !== expected) {
      return { ok: false, error: `scoring.${key}: variantlar bilan mos emas (${expected})` };
    }
  }
  return { ok: true, value: scoring };
}

/** Ko'rib chiqish qarorlaridagi teglar (`signal`, `riasec`) — scoring oxiriga qo'shiladi. */
export function withScoringTags(
  scoring: ScoringRecord | null,
  tags: { knowledge: boolean; riasec: RiasecCode | null },
): ScoringRecord | null {
  if (scoring === null) return null;
  return {
    ...scoring,
    ...(tags.knowledge && { signal: 'knowledge' }),
    ...(tags.riasec !== null && { riasec: tags.riasec }),
  };
}

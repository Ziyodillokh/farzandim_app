// Admin savol kiritmasi — sof funksiyalar: DTO → parser kiritmasi, PATCH
// birlashtirish, `scoring`ni yangi variantlarga moslash va javob berilgan
// savolda o'zgarmaydigan maydonlar (docs/KELAJAK-REJA.md §6).

import { randomBytes } from 'node:crypto';
import { KelajakQuestionData } from '../../modules/kelajak/domain/bank';
import {
  LOCKED_WHEN_ANSWERED,
  stableJson,
  UPDATABLE_FIELDS,
  UpdatableField,
} from '../../modules/kelajak/domain/import-plan';

export const ADMIN_EXTERNAL_ID_PREFIX = 'ADMIN-';
const ADMIN_EXTERNAL_ID_BYTES = 4;
/** Bank savollari nomlar fazosi — admin bu prefiks bilan savol yarata olmaydi (keyingi bank versiyasi bilan to'qnashmasin). */
export const RESERVED_EXTERNAL_ID_PREFIX = 'PARVOZ-';

export const isReservedExternalId = (externalId: string) => externalId.startsWith(RESERVED_EXTERNAL_ID_PREFIX);

/**
 * Javob berilgan (yoki bugungi ochiq sessiyadagi) savolda o'zgarmaydigan
 * maydonlar — import bilan bir xil ro'yxat (kategoriya, yosh, javob turi,
 * variantlar, `scoring`, `reverse`). Qolganlari — `text`, `notes`,
 * `reviewNote`, `followUp`, `required`, `active` — tahrirlanadi.
 */
export const ADMIN_LOCKED_WHEN_ANSWERED: readonly UpdatableField[] = LOCKED_WHEN_ANSWERED;

/** Bazadagi savol (JSON ustunlari xom holda). */
export type StoredKelajakQuestion = Readonly<Record<UpdatableField, unknown>> & { externalId: string };

type Raw = Record<string, unknown>;

/** `ADMIN-` + 8 ta katta hex belgi (`EXTERNAL_ID_PATTERN`ga mos). */
export function generateExternalId(): string {
  return `${ADMIN_EXTERNAL_ID_PREFIX}${randomBytes(ADMIN_EXTERNAL_ID_BYTES).toString('hex').toUpperCase()}`;
}

/** Berilmagan (`undefined`) maydonlarsiz nusxa — `null` saqlanadi (tozalash). */
export function definedFields(input: object): Raw {
  return Object.fromEntries(Object.entries(input).filter(([, value]) => value !== undefined));
}

/** Bazadagi savol → parserning admin formati. */
export function inputOfStored(q: StoredKelajakQuestion): Raw {
  return {
    externalId: q.externalId,
    ...Object.fromEntries(UPDATABLE_FIELDS.map((field) => [field, q[field]])),
  };
}

const optionValues = (options: unknown): number[] =>
  Array.isArray(options)
    ? options
        .map((o: unknown) => (o && typeof o === 'object' ? (o as Raw).value : undefined))
        .filter((v): v is number => Number.isInteger(v))
    : [];

/**
 * Javob turi / variantlar o'zgarganda eski `scoring`ni moslash: `text` —
 * `null`; `min`/`max` bo'lsa — yangi variantlar oralig'i; qolgani
 * (`dimension`, `method`) o'zgarmaydi. Noto'g'ri variantlarni parser rad etadi.
 */
export function rebaseScoring(scoring: unknown, answerType: unknown, options: unknown): unknown {
  if (answerType === 'text') return null;
  if (!scoring || typeof scoring !== 'object' || Array.isArray(scoring)) return scoring;
  const values = optionValues(options);
  if (values.length === 0) return scoring;
  const record = scoring as Raw;
  return {
    ...record,
    ...(record.min !== undefined && { min: Math.min(...values) }),
    ...(record.max !== undefined && { max: Math.max(...values) }),
  };
}

/**
 * PATCH kiritmasi: mavjud savol + berilgan maydonlar. `scoring` berilmasa
 * yangi javob turi / variantlarga moslanadi; javob turi o'zgarib `required`
 * berilmasa — tur qoidasidan olinadi (masalan, `text` — ixtiyoriy).
 */
export function mergeQuestionPatch(existing: StoredKelajakQuestion, patch: Raw): Raw {
  const merged: Raw = { ...inputOfStored(existing), ...patch };
  const structural = patch.answerType !== undefined || patch.options !== undefined;
  const typeChanged = patch.answerType !== undefined && patch.answerType !== existing.answerType;
  return {
    ...merged,
    ...(structural &&
      patch.scoring === undefined && {
        scoring: rebaseScoring(existing.scoring, merged.answerType, merged.options),
      }),
    ...(typeChanged && patch.required === undefined && { required: undefined }),
  };
}

/** Haqiqatda o'zgargan maydonlar (JSON ustunlari kalit tartibidan qat'i nazar). */
export function changedFields(existing: StoredKelajakQuestion, next: KelajakQuestionData): UpdatableField[] {
  return UPDATABLE_FIELDS.filter((field) => stableJson(existing[field]) !== stableJson(next[field]));
}

/** O'zgarganlar ichida javob berilgan savolda taqiqlanganlari. */
export function lockedFields(changed: readonly UpdatableField[]): UpdatableField[] {
  return changed.filter((field) => ADMIN_LOCKED_WHEN_ANSWERED.includes(field));
}

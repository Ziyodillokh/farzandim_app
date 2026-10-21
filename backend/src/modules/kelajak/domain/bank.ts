// Kelajak savoli validatsiyasi — ma'lumot migratsiyasi generatori, import CLI
// va admin CRUD bir xil qoidadan foydalanadi (docs/KELAJAK-REJA.md §2, §6).
// Ikki format qabul qilinadi: bank JSON'i (`id`, `category_id`, `age_group`,
// `question_text`, `answer_type`, ...) va admin formati (`externalId`,
// `category`, `ageGroup`, `text`, `answerType`, ...).

import { isKelajakAgeGroup, KelajakAgeGroup } from './age';
import { bankIntegrityWarnings } from './bank-integrity';
import { parseScoring, withScoringTags } from './bank-scoring';
import {
  defaultRequired,
  isKelajakAnswerType,
  isKelajakCategory,
  isRiasecCode,
  KelajakAnswerType,
  KelajakCategory,
  RiasecCode,
  TEXT_ANSWER_TYPE,
} from './catalog';
import { L, parseL } from './localized';

export const EXTERNAL_ID_PATTERN = /^[A-Z0-9-]{3,40}$/;
export const MIN_OPTIONS = 2;
export const MAX_OPTIONS = 10;

export const TEXT_LIMITS = {
  text: 500,
  option: 120,
  followUp: 500,
  note: 1000,
  source: 80,
} as const;

/** Admin yaratgan savol manbasi (bank JSON'ida o'z qiymatlari bor). */
export const ADMIN_SOURCE = {
  sourceType: 'parvoz_admin',
  sourceName: 'Parvoz',
  sourceVersion: 'admin',
} as const;

export interface KelajakOption {
  value: number;
  label: L;
}

/** DB yozuviga tayyor savol (`id`, vaqt va `createdBy`siz). */
export interface KelajakQuestionData {
  externalId: string | null;
  category: KelajakCategory;
  ageGroup: KelajakAgeGroup;
  text: L;
  answerType: KelajakAnswerType;
  options: KelajakOption[];
  scoring: Record<string, unknown> | null;
  reverse: boolean;
  required: boolean;
  followUp: string | null;
  notes: string | null;
  reviewNote: string | null;
  sourceType: string;
  sourceName: string;
  sourceVersion: string;
  active: boolean;
}

/** `review-overrides.json` — import paytidagi ko'rib chiqish qarorlari. */
export interface ReviewOverrides {
  inactive: Readonly<Record<string, string>>;
  reviewNotes: Readonly<Record<string, string>>;
  reverse: readonly string[];
  /** wellbeing / safety: xavfsizlik bilimi savollari — `scoring.signal = 'knowledge'`. */
  knowledge: readonly string[];
  /** Career Lab faoliyati → RIASEC kodi (`scoring.riasec`). */
  careerLab: Readonly<Record<string, RiasecCode>>;
  /**
   * Shkala yorliqlari (javob turi → tartib bo'yicha uz matnlar). Qiymatlar
   * o'zgarmaydi — faqat ko'rinadigan matn ("-mi?" savolga mos "Ha / Yo'q").
   */
  scaleLabels: Readonly<Record<string, readonly string[]>>;
}

export const NO_OVERRIDES: ReviewOverrides = {
  inactive: {},
  reviewNotes: {},
  reverse: [],
  knowledge: [],
  careerLab: {},
  scaleLabels: {},
};

export type ParseResult<T> = { ok: true; value: T } | { ok: false; error: string };

const isFailure = <T>(r: ParseResult<T>): r is { ok: false; error: string } => !r.ok;

type Raw = Record<string, unknown>;

const isPlainObject = (v: unknown): v is Raw =>
  !!v && typeof v === 'object' && !Array.isArray(v);

const has = (record: Readonly<Record<string, unknown>>, key: string) =>
  Object.prototype.hasOwnProperty.call(record, key);

/** Birinchi aniqlangan maydon (bank nomi, keyin admin nomi). */
const pick = (q: Raw, ...keys: string[]): unknown => {
  for (const key of keys) if (q[key] !== undefined) return q[key];
  return undefined;
};

function optionalText(value: unknown, field: string, max: number): ParseResult<string | null> {
  if (value === undefined || value === null) return { ok: true, value: null };
  if (typeof value !== 'string') return { ok: false, error: `${field}: satr bo'lishi kerak` };
  const text = value.trim();
  if (text.length > max) return { ok: false, error: `${field}: ${max} belgidan uzun` };
  return { ok: true, value: text.length > 0 ? text : null };
}

function requiredText(value: unknown, field: string, fallback: string): ParseResult<string> {
  const parsed = optionalText(value ?? fallback, field, TEXT_LIMITS.source);
  if (!parsed.ok) return parsed;
  return parsed.value ? { ok: true, value: parsed.value } : { ok: false, error: `${field}: bo'sh` };
}

function optionalBoolean(value: unknown, field: string, fallback: boolean): ParseResult<boolean> {
  if (value === undefined || value === null) return { ok: true, value: fallback };
  return typeof value === 'boolean'
    ? { ok: true, value }
    : { ok: false, error: `${field}: true/false bo'lishi kerak` };
}

function parseOption(option: unknown, i: number): ParseResult<KelajakOption> {
  if (!isPlainObject(option)) return { ok: false, error: `options[${i}]: {value, label} kerak` };
  if (!Number.isInteger(option.value)) return { ok: false, error: `options[${i}].value: butun son kerak` };
  const label = parseL(option.label, `options[${i}].label`, TEXT_LIMITS.option);
  return label.ok ? { ok: true, value: { value: option.value as number, label: label.value } } : label;
}

function parseOptions(raw: unknown, answerType: KelajakAnswerType): ParseResult<KelajakOption[]> {
  const list = raw ?? [];
  if (!Array.isArray(list)) return { ok: false, error: 'options: massiv kerak' };
  if (answerType === 'text') {
    return list.length === 0
      ? { ok: true, value: [] }
      : { ok: false, error: 'options: text turida variant bo\'lmaydi' };
  }
  if (list.length < MIN_OPTIONS || list.length > MAX_OPTIONS) {
    return { ok: false, error: `options: ${MIN_OPTIONS}..${MAX_OPTIONS} ta variant` };
  }
  const parsed = list.map((option, i) => parseOption(option, i));
  const failed = parsed.find(isFailure);
  if (failed) return failed;
  const options = parsed.flatMap((p) => (p.ok ? [p.value] : []));
  if (new Set(options.map((o) => o.value)).size !== options.length) {
    return { ok: false, error: 'options: qiymatlar takrorlanmasligi kerak' };
  }
  return { ok: true, value: options };
}

/**
 * Bitta savol. `overrides` — `review-overrides.json` qarorlari (`active`,
 * `reverse`, `reviewNote` va scoring teglari `signal` / `riasec`ni
 * belgilaydi); `required` berilmasa javob turi qoidasidan olinadi.
 */
export function parseKelajakQuestion(
  raw: unknown,
  overrides: ReviewOverrides = NO_OVERRIDES,
): ParseResult<KelajakQuestionData> {
  if (!isPlainObject(raw)) return { ok: false, error: 'savol obyekt bo\'lishi kerak' };
  const q = raw;

  const externalId = pick(q, 'id', 'externalId') ?? null;
  if (externalId !== null && (typeof externalId !== 'string' || !EXTERNAL_ID_PATTERN.test(externalId))) {
    return { ok: false, error: 'externalId: A-Z, 0-9 va "-", 3..40 belgi' };
  }

  const category = pick(q, 'category_id', 'category');
  if (!isKelajakCategory(category)) return { ok: false, error: `category: noma'lum (${String(category)})` };
  const ageGroup = pick(q, 'age_group', 'ageGroup');
  if (!isKelajakAgeGroup(ageGroup)) return { ok: false, error: `ageGroup: noma'lum (${String(ageGroup)})` };
  const answerType = pick(q, 'answer_type', 'answerType');
  if (!isKelajakAnswerType(answerType)) {
    return { ok: false, error: `answerType: noma'lum (${String(answerType)})` };
  }

  const text = parseL(pick(q, 'question_text', 'text'), 'text', TEXT_LIMITS.text);
  if (!text.ok) return text;
  const options = parseOptions(q.options, answerType);
  if (!options.ok) return options;
  const scoring = parseScoring(q.scoring, answerType, category, options.value.map((o) => o.value));
  if (!scoring.ok) return scoring;

  const followUp = optionalText(pick(q, 'follow_up', 'followUp'), 'followUp', TEXT_LIMITS.followUp);
  if (!followUp.ok) return followUp;
  const notes = optionalText(q.notes, 'notes', TEXT_LIMITS.note);
  if (!notes.ok) return notes;
  const reviewNote = optionalText(pick(q, 'review_note', 'reviewNote'), 'reviewNote', TEXT_LIMITS.note);
  if (!reviewNote.ok) return reviewNote;
  const sourceType = requiredText(pick(q, 'source_type', 'sourceType'), 'sourceType', ADMIN_SOURCE.sourceType);
  if (!sourceType.ok) return sourceType;
  const sourceName = requiredText(pick(q, 'source_name', 'sourceName'), 'sourceName', ADMIN_SOURCE.sourceName);
  if (!sourceName.ok) return sourceName;
  const sourceVersion = requiredText(
    pick(q, 'source_version', 'sourceVersion'),
    'sourceVersion',
    ADMIN_SOURCE.sourceVersion,
  );
  if (!sourceVersion.ok) return sourceVersion;

  const active = optionalBoolean(q.active, 'active', true);
  if (!active.ok) return active;
  const reverse = optionalBoolean(q.reverse, 'reverse', false);
  if (!reverse.ok) return reverse;
  const required = optionalBoolean(q.required, 'required', defaultRequired(answerType));
  if (!required.ok) return required;
  // Ochiq javob hech qachon majburiy emas — bola matn yozishga majburlanmaydi (§3).
  if (answerType === TEXT_ANSWER_TYPE && required.value) {
    return { ok: false, error: 'required: ochiq javobli (text) savol majburiy bo\'lmaydi' };
  }

  const id = externalId as string | null;
  const labels = has(overrides.scaleLabels, answerType) ? overrides.scaleLabels[answerType] : null;
  const shownOptions =
    labels && labels.length === options.value.length
      ? options.value.map((o, i) => ({ value: o.value, label: { uz: labels[i] } }))
      : options.value;
  const inactiveReason = id !== null && has(overrides.inactive, id) ? overrides.inactive[id] : null;
  const overrideNote = id !== null && has(overrides.reviewNotes, id) ? overrides.reviewNotes[id] : null;

  return {
    ok: true,
    value: {
      externalId: id,
      category,
      ageGroup,
      text: text.value,
      answerType,
      options: shownOptions,
      scoring: withScoringTags(scoring.value, {
        knowledge: id !== null && overrides.knowledge.includes(id),
        riasec: id !== null && has(overrides.careerLab, id) ? overrides.careerLab[id] : null,
      }),
      reverse: (id !== null && overrides.reverse.includes(id)) || reverse.value,
      required: required.value,
      followUp: followUp.value,
      notes: notes.value,
      reviewNote: inactiveReason ?? overrideNote ?? reviewNote.value,
      sourceType: sourceType.value,
      sourceName: sourceName.value,
      sourceVersion: sourceVersion.value,
      active: inactiveReason === null && active.value,
    },
  };
}

function stringRecord(value: unknown, field: string): ParseResult<Record<string, string>> {
  if (value === undefined) return { ok: true, value: {} };
  if (!isPlainObject(value)) return { ok: false, error: `${field}: obyekt kerak` };
  for (const [key, text] of Object.entries(value)) {
    if (typeof text !== 'string' || text.trim().length === 0) {
      return { ok: false, error: `${field}.${key}: bo'sh` };
    }
  }
  return { ok: true, value: value as Record<string, string> };
}

function idList(value: unknown, field: string): ParseResult<string[]> {
  const list = value ?? [];
  return Array.isArray(list) && list.every((id) => typeof id === 'string')
    ? { ok: true, value: list as string[] }
    : { ok: false, error: `${field}: satrlar massivi kerak` };
}

function labelRecord(value: unknown): ParseResult<Record<string, string[]>> {
  if (value === undefined) return { ok: true, value: {} };
  if (!isPlainObject(value)) return { ok: false, error: 'scaleLabels: obyekt kerak' };
  for (const [type, list] of Object.entries(value)) {
    if (!isKelajakAnswerType(type) || type === TEXT_ANSWER_TYPE) {
      return { ok: false, error: `scaleLabels.${type}: shkala turi kerak` };
    }
    const ok = Array.isArray(list) && list.every((t) => typeof t === 'string' && t.trim().length > 0 && t.length <= TEXT_LIMITS.option);
    if (!ok) return { ok: false, error: `scaleLabels.${type}: bo'sh bo'lmagan matnlar massivi kerak` };
  }
  return { ok: true, value: value as Record<string, string[]> };
}

function riasecRecord(value: unknown): ParseResult<Record<string, RiasecCode>> {
  if (value === undefined) return { ok: true, value: {} };
  if (!isPlainObject(value)) return { ok: false, error: 'careerLab: obyekt kerak' };
  const wrong = Object.entries(value).find(([, code]) => !isRiasecCode(code));
  return wrong
    ? { ok: false, error: `careerLab.${wrong[0]}: RIASEC kodi kerak (R, I, A, S, E, C)` }
    : { ok: true, value: value as Record<string, RiasecCode> };
}

/** `review-overrides.json` tuzilmasini tekshirish. */
export function parseReviewOverrides(raw: unknown): ParseResult<ReviewOverrides> {
  if (!isPlainObject(raw)) return { ok: false, error: 'overrides: obyekt kerak' };
  const inactive = stringRecord(raw.inactive, 'inactive');
  if (!inactive.ok) return inactive;
  const reviewNotes = stringRecord(raw.reviewNotes, 'reviewNotes');
  if (!reviewNotes.ok) return reviewNotes;
  const reverse = idList(raw.reverse, 'reverse');
  if (!reverse.ok) return reverse;
  const knowledge = idList(raw.knowledge, 'knowledge');
  if (!knowledge.ok) return knowledge;
  const careerLab = riasecRecord(raw.careerLab);
  if (!careerLab.ok) return careerLab;
  const scaleLabels = labelRecord(raw.scaleLabels);
  if (!scaleLabels.ok) return scaleLabels;
  return {
    ok: true,
    value: {
      inactive: inactive.value,
      reviewNotes: reviewNotes.value,
      reverse: reverse.value,
      knowledge: knowledge.value,
      careerLab: careerLab.value,
      scaleLabels: scaleLabels.value,
    },
  };
}

export interface ParsedBank {
  read: number;
  valid: KelajakQuestionData[];
  invalid: Array<{ index: number; externalId: string | null; error: string }>;
  /** Fayl ichida takrorlangan `externalId` — birinchisi olinadi. */
  duplicates: Array<{ externalId: string; indexes: number[] }>;
  warnings: string[];
}

const rawId = (raw: unknown): string | null => {
  if (!isPlainObject(raw)) return null;
  const id = pick(raw, 'id', 'externalId');
  return typeof id === 'string' ? id : null;
};

/** Fayl ichidagi `externalId` dublikatlari (indekslari bilan). */
function findDuplicates(ids: ReadonlyArray<string | null>): ParsedBank['duplicates'] {
  const unique = [...new Set(ids.filter((id): id is string => id !== null))];
  return unique
    .map((externalId) => ({
      externalId,
      indexes: ids.flatMap((id, index) => (id === externalId ? [index] : [])),
    }))
    .filter((d) => d.indexes.length > 1);
}

/** Bir yosh guruhida matni bir xil savollar (ogohlantirish). */
function duplicateTextWarnings(valid: readonly KelajakQuestionData[]): string[] {
  const keyOf = (q: KelajakQuestionData) => `${q.ageGroup}|${q.text.uz.toLowerCase()}`;
  return valid.flatMap((q, i) => {
    const first = valid.findIndex((other) => keyOf(other) === keyOf(q));
    return first < i ? [`${q.externalId ?? '?'}: matni ${valid[first].externalId ?? '?'} bilan bir xil`] : [];
  });
}

/** Qarorlar shu bank uchun yozilgan bo'lsa (kamida bittasi mos), yo'qolganlarini aytamiz. */
function missingOverrideWarnings(overrides: ReviewOverrides, known: ReadonlySet<string>): string[] {
  const ids = [
    ...new Set([
      ...Object.keys(overrides.inactive),
      ...Object.keys(overrides.reviewNotes),
      ...overrides.reverse,
      ...overrides.knowledge,
      ...Object.keys(overrides.careerLab),
    ]),
  ];
  const missing = ids.filter((id) => !known.has(id));
  return missing.length < ids.length ? missing.map((id) => `overrides: ${id} faylda yo'q`) : [];
}

/**
 * Butun bank: `{questions: [...]}` (bank JSON'i) yoki savollar massivi.
 * Tuzilma noto'g'ri bo'lsa — `Error`.
 */
export function parseKelajakBank(raw: unknown, overrides: ReviewOverrides = NO_OVERRIDES): ParsedBank {
  const list = Array.isArray(raw) ? raw : isPlainObject(raw) ? raw.questions : undefined;
  if (!Array.isArray(list)) throw new Error('bank: `questions` massivi kerak');

  const ids = list.map(rawId);
  const duplicates = findDuplicates(ids);
  const repeated = new Set(duplicates.flatMap((d) => d.indexes.slice(1)));
  const results = list
    .map((item, index) => ({ index, parsed: parseKelajakQuestion(item, overrides) }))
    .filter(({ index }) => !repeated.has(index));
  const valid = results.flatMap(({ parsed }) => (parsed.ok ? [parsed.value] : []));
  const invalid = results.flatMap(({ index, parsed }) =>
    parsed.ok ? [] : [{ index, externalId: ids[index], error: parsed.error }],
  );

  const total = isPlainObject(raw) ? raw.total_questions : undefined;
  const warnings = [
    ...(total !== undefined && total !== list.length
      ? [`total_questions (${String(total)}) savollar soniga (${list.length}) teng emas`]
      : []),
    ...duplicateTextWarnings(valid),
    ...missingOverrideWarnings(overrides, new Set(ids.filter((id): id is string => id !== null))),
    ...(isPlainObject(raw) ? bankIntegrityWarnings(raw, list.filter((_, index) => !repeated.has(index))) : []),
  ];

  return { read: list.length, valid, invalid, duplicates, warnings };
}

/**
 * Savol formasi holati, mijoz validatsiyasi va API payload'lari.
 *
 * Validatsiya backend qoidalarini takrorlaydi (docs/KELAJAK-REJA.md §6) —
 * "Saqlash" behuda 400 qaytarmasin. Yakuniy tekshiruv baribir backendda.
 */
import type { KelajakQuestionCreatePayload, KelajakQuestionPatch } from '@/lib/api/admin.api';
import {
  ANSWER_TYPE_PRESETS,
  EXTERNAL_ID_PATTERN,
  KELAJAK_LIMITS,
  RESERVED_EXTERNAL_ID_PREFIX,
  TEXT_ANSWER_TYPE,
  defaultRequiredFor,
  isKnownAgeGroup,
  isKnownAnswerType,
  isKnownCategory,
} from '@/lib/constants/kelajak';
import type { KelajakOption, KelajakQuestion, KelajakText } from '@/types/api.types';
import { createScoring, patchScoring, scoringTagFrom, scoringTagSpec } from './question-scoring';

export interface TextDraft {
  uz: string;
  ru: string;
  en: string;
}

export interface OptionDraft {
  /** Faqat React kaliti (qo'shish/o'chirishda qatorlar aralashmasin). */
  key: string;
  /** Input qiymati — yozish paytida bo'sh bo'lishi mumkin, validatsiyada songa aylanadi. */
  value: string;
  label: TextDraft;
}

export interface QuestionForm {
  externalId: string;
  category: string;
  ageGroup: string;
  answerType: string;
  text: TextDraft;
  options: OptionDraft[];
  /** Ball o'lchami tegi (RIASEC / signal turi) — `question-scoring.ts`. */
  scoringTag: string;
  required: boolean;
  reverse: boolean;
  active: boolean;
  followUp: string;
  notes: string;
  reviewNote: string;
}

export type FormMode = 'create' | 'edit';
export type FormField =
  | 'externalId'
  | 'category'
  | 'ageGroup'
  | 'answerType'
  | 'scoringTag'
  | 'text'
  | 'options'
  | 'followUp'
  | 'notes'
  | 'reviewNote';
export type FormErrors = Partial<Record<FormField, string>>;

const DEFAULT_ANSWER_TYPE = 'likert_5';
const EMPTY_TEXT: TextDraft = { uz: '', ru: '', en: '' };

let optionSeq = 0;
const nextOptionKey = () => `opt-${++optionSeq}`;

const toTextDraft = (t?: KelajakText | null): TextDraft => ({
  uz: t?.uz ?? '',
  ru: t?.ru ?? '',
  en: t?.en ?? '',
});

/** Javob turining standart variantlari (JSON `answer_scales`). */
export function presetOptions(answerType: string): OptionDraft[] {
  return (ANSWER_TYPE_PRESETS[answerType] ?? []).map((p) => ({
    key: nextOptionKey(),
    value: String(p.value),
    label: { ...EMPTY_TEXT, uz: p.uz },
  }));
}

export function emptyForm(defaults: { category?: string; ageGroup?: string } = {}): QuestionForm {
  const category = defaults.category ?? '';
  return {
    externalId: '',
    category,
    ageGroup: defaults.ageGroup ?? '',
    answerType: DEFAULT_ANSWER_TYPE,
    text: EMPTY_TEXT,
    options: presetOptions(DEFAULT_ANSWER_TYPE),
    scoringTag: scoringTagFrom(category, null),
    required: defaultRequiredFor(DEFAULT_ANSWER_TYPE),
    reverse: false,
    active: true,
    followUp: '',
    notes: '',
    reviewNote: '',
  };
}

export function formFromQuestion(q: KelajakQuestion): QuestionForm {
  return {
    externalId: q.externalId,
    category: q.category,
    ageGroup: q.ageGroup,
    answerType: q.answerType,
    text: toTextDraft(q.text),
    options: q.options.map((o) => ({
      key: nextOptionKey(),
      value: String(o.value),
      label: toTextDraft(o.label),
    })),
    scoringTag: scoringTagFrom(q.category, q.scoring),
    required: q.required,
    reverse: q.reverse,
    active: q.active,
    followUp: q.followUp ?? '',
    notes: q.notes ?? '',
    reviewNote: q.reviewNote ?? '',
  };
}

/**
 * Bloklangan savolda bloklanadigan maydonlar serverdagi qiymatga qaytariladi
 * (dialog ochiq turganda savolga javob kelib qolsa).
 */
export function withLockedFrom(form: QuestionForm, q: KelajakQuestion): QuestionForm {
  const server = formFromQuestion(q);
  return {
    ...form,
    category: server.category,
    ageGroup: server.ageGroup,
    answerType: server.answerType,
    options: server.options,
    scoringTag: server.scoringTag,
    reverse: server.reverse,
  };
}

/** Kategoriyani almashtirish: ball o'lchami tegi yangi kategoriya standartiga qaytadi. */
export function withCategory(form: QuestionForm, category: string): QuestionForm {
  return { ...form, category, scoringTag: scoringTagFrom(category, null) };
}

/** Javob turini almashtirish: standart variantlar va majburiylik qoidasi (§3) qo'llanadi. */
export function withAnswerType(form: QuestionForm, answerType: string): QuestionForm {
  return {
    ...form,
    answerType,
    options: presetOptions(answerType),
    required: defaultRequiredFor(answerType),
    // Ochiq javobda shkala yo'q — teskari ball ma'nosiz.
    reverse: answerType === TEXT_ANSWER_TYPE ? false : form.reverse,
  };
}

/** Yangi bo'sh variant: qiymati mavjudlarning eng kattasidan bitta ko'p. */
export function newOption(options: OptionDraft[]): OptionDraft {
  const values = options.map((o) => Number(o.value)).filter(Number.isInteger);
  const next = values.length > 0 ? Math.max(...values) + 1 : 1;
  return { key: nextOptionKey(), value: String(next), label: EMPTY_TEXT };
}

/* ─── Validatsiya ─── */

const tooLong = (texts: readonly string[], max: number) => texts.some((t) => t.trim().length > max);
const langs = (t: TextDraft) => [t.uz, t.ru, t.en];

function externalIdError(raw: string): string | null {
  const value = raw.trim();
  if (!value) return null;
  if (!EXTERNAL_ID_PATTERN.test(value)) return "ID: faqat katta lotin harflari, raqam va '-' (3–40 belgi).";
  if (value.startsWith(RESERVED_EXTERNAL_ID_PREFIX)) {
    return `${RESERVED_EXTERNAL_ID_PREFIX} prefiksi bank savollari uchun band — ADMIN-… yoki boshqa ID bering.`;
  }
  return null;
}

function textError(text: TextDraft): string | null {
  if (!text.uz.trim()) return "Savol matni (o'zbekcha) majburiy.";
  return tooLong(langs(text), KELAJAK_LIMITS.textMax) ? `Matn ${KELAJAK_LIMITS.textMax} belgidan oshmasin.` : null;
}

function optionsError(answerType: string, options: OptionDraft[]): string | null {
  if (answerType === TEXT_ANSWER_TYPE) {
    return options.length > 0 ? "Ochiq javobli savolda variant bo'lmaydi." : null;
  }
  const { optionsMin, optionsMax, optionLabelMax } = KELAJAK_LIMITS;
  if (options.length < optionsMin || options.length > optionsMax) {
    return `Variantlar soni ${optionsMin} tadan ${optionsMax} tagacha bo'lishi kerak.`;
  }
  const values = options.map((o) => (o.value.trim() === '' ? NaN : Number(o.value)));
  if (!values.every(Number.isInteger)) return "Variant qiymatlari butun son bo'lishi kerak.";
  if (new Set(values).size !== values.length) return 'Variant qiymatlari takrorlanmasin.';
  if (options.some((o) => !o.label.uz.trim())) {
    return "Har bir variantning o'zbekcha yorlig'i majburiy.";
  }
  if (options.some((o) => tooLong(langs(o.label), optionLabelMax))) {
    return `Variant yorlig'i ${optionLabelMax} belgidan oshmasin.`;
  }
  return null;
}

function answerTypeError(form: QuestionForm): string | null {
  if (!isKnownAnswerType(form.answerType)) return 'Javob turini tanlang.';
  if (form.category === 'career_interest' && form.answerType === TEXT_ANSWER_TYPE) {
    return "Kasbiy qiziqish savoli ochiq javobli bo'lmaydi (RIASEC bali hisoblanadi).";
  }
  return null;
}

function scoringTagError(form: QuestionForm): string | null {
  const spec = scoringTagSpec(form.category);
  if (!spec || form.answerType === TEXT_ANSWER_TYPE) return null;
  return spec.required && !form.scoringTag ? `${spec.label}ni tanlang.` : null;
}

const lengthError = (value: string, max: number, label: string) =>
  value.trim().length > max ? `${label} ${max} belgidan oshmasin.` : null;

export function validateForm(form: QuestionForm, mode: FormMode): FormErrors {
  const checks: Array<[FormField, string | null]> = [
    ['externalId', mode === 'create' ? externalIdError(form.externalId) : null],
    ['category', isKnownCategory(form.category) ? null : 'Kategoriyani tanlang.'],
    ['ageGroup', isKnownAgeGroup(form.ageGroup) ? null : 'Yosh guruhini tanlang.'],
    ['answerType', answerTypeError(form)],
    ['scoringTag', scoringTagError(form)],
    ['text', textError(form.text)],
    ['options', optionsError(form.answerType, form.options)],
    ['followUp', lengthError(form.followUp, KELAJAK_LIMITS.followUpMax, 'Keyingi qadam')],
    ['notes', lengthError(form.notes, KELAJAK_LIMITS.noteMax, 'Izoh')],
    ['reviewNote', lengthError(form.reviewNote, KELAJAK_LIMITS.noteMax, "Ko'rib chiqish izohi")],
  ];
  return Object.fromEntries(checks.filter(([, message]) => message !== null)) as FormErrors;
}

/* ─── Payload ─── */

type Normalized = Required<Omit<KelajakQuestionCreatePayload, 'externalId' | 'scoring'>>;

const cleanText = (t: TextDraft): KelajakText => {
  const ru = t.ru.trim();
  const en = t.en.trim();
  return { uz: t.uz.trim(), ...(ru ? { ru } : {}), ...(en ? { en } : {}) };
};

const nullable = (s: string) => s.trim() || null;

function normalizeForm(form: QuestionForm): Normalized {
  const isText = form.answerType === TEXT_ANSWER_TYPE;
  const options: KelajakOption[] = isText
    ? []
    : form.options.map((o) => ({ value: Number(o.value), label: cleanText(o.label) }));
  return {
    category: form.category,
    ageGroup: form.ageGroup,
    text: cleanText(form.text),
    answerType: form.answerType,
    options,
    reverse: isText ? false : form.reverse,
    // Ochiq javob hech qachon majburiy emas (backend rad etadi).
    required: isText ? false : form.required,
    followUp: nullable(form.followUp),
    notes: nullable(form.notes),
    reviewNote: nullable(form.reviewNote),
    active: form.active,
  };
}

const scoringInput = (form: QuestionForm, normalized: Normalized) => ({
  category: normalized.category,
  answerType: normalized.answerType,
  tag: form.scoringTag,
  optionValues: normalized.options.map((o) => o.value),
});

export function toCreatePayload(form: QuestionForm): KelajakQuestionCreatePayload {
  const normalized = normalizeForm(form);
  const { followUp, notes, reviewNote, ...rest } = normalized;
  const externalId = form.externalId.trim();
  const scoring = createScoring(scoringInput(form, normalized));
  // Bo'sh ixtiyoriy maydonlar yuborilmaydi.
  return {
    ...rest,
    ...(externalId ? { externalId } : {}),
    ...(scoring ? { scoring } : {}),
    ...(followUp ? { followUp } : {}),
    ...(notes ? { notes } : {}),
    ...(reviewNote ? { reviewNote } : {}),
  };
}

/** Javob berilgan savolda ham o'zgaradigan maydonlar (§6). */
const ALWAYS_EDITABLE = ['text', 'required', 'active', 'followUp', 'notes', 'reviewNote'] as const;
/** `answerCount > 0` (yoki bugungi ochiq sessiya) bo'lsa bloklanadigan maydonlar. */
const LOCKABLE = ['category', 'ageGroup', 'answerType', 'options', 'reverse'] as const;

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

/**
 * Faqat o'zgargan maydonlar — `original` forma to'ldirilgan holat (boshqa
 * admin o'zgartirgan maydonlar qayta yozilmasin). Bloklangan savolda
 * bloklanadigan maydonlar (scoring ham) umuman yuborilmaydi.
 */
export function toPatchPayload(
  form: QuestionForm,
  original: KelajakQuestion,
  locked: boolean,
): KelajakQuestionPatch {
  const next = normalizeForm(form);
  const prev = normalizeForm(formFromQuestion(original));
  const keys = locked ? [...ALWAYS_EDITABLE] : [...ALWAYS_EDITABLE, ...LOCKABLE];
  const patch = keys.reduce<KelajakQuestionPatch>(
    (acc, key) => (same(next[key], prev[key]) ? acc : { ...acc, [key]: next[key] }),
    {},
  );
  const scoring = locked ? undefined : patchScoring(scoringInput(form, next), original);
  return scoring ? { ...patch, scoring } : patch;
}

export const hasErrors = (errors: FormErrors) => Object.keys(errors).length > 0;

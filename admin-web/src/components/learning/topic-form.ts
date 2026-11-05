/**
 * Mavzu formasi holati, mijoz validatsiyasi va API payload'lari.
 *
 * Validatsiya backend qoidalarini takrorlaydi (sinflar 1–11, minGrade ≤
 * maxGrade, kalit `^[a-z0-9]+(-[a-z0-9]+)*$` ≤ 80, title.uz majburiy) —
 * "Saqlash" behuda 400 qaytarmasin. Yakuniy tekshiruv baribir backendda.
 */
import type { LearningTopicCreatePayload, LearningTopicPatch } from '@/lib/api/admin.api';
import {
  MAX_GRADE,
  MIN_GRADE,
  TOPIC_KEY_MAX,
  TOPIC_KEY_PATTERN,
  isLearningSubject,
} from '@/lib/constants/learning';
import type {
  LearningSubject,
  LearningText,
  LearningTopic,
  LearningTopicStatus,
  LearningTopicTitle,
} from '@/types/api.types';

export interface TextDraft {
  uz: string;
  ru: string;
  en: string;
}

export interface TopicForm {
  /** Yaratishda bo'sh bo'lishi mumkin (hali tanlanmagan). */
  subject: LearningSubject | '';
  key: string;
  /** Admin kalitni qo'lda yozgan — sarlavhadan avtomatik taklif to'xtaydi. */
  keyTouched: boolean;
  title: TextDraft;
  goal: TextDraft;
  /** Select qiymati ("1".."11"); tanlanmagan bo'lsa bo'sh. */
  minGrade: string;
  maxGrade: string;
  status: LearningTopicStatus;
}

export type TopicFormMode = 'create' | 'edit';
export type TopicFormField = 'subject' | 'key' | 'title' | 'minGrade' | 'maxGrade';
export type TopicFormErrors = Partial<Record<TopicFormField, string>>;

const EMPTY_TEXT: TextDraft = { uz: '', ru: '', en: '' };

const toTextDraft = (t?: LearningText | null): TextDraft => ({
  uz: t?.uz ?? '',
  ru: t?.ru ?? '',
  en: t?.en ?? '',
});

export function emptyTopicForm(subject: LearningSubject | '' = ''): TopicForm {
  return {
    subject,
    key: '',
    keyTouched: false,
    title: EMPTY_TEXT,
    goal: EMPTY_TEXT,
    minGrade: '',
    maxGrade: '',
    status: 'ACTIVE',
  };
}

export function formFromTopic(topic: LearningTopic): TopicForm {
  return {
    subject: topic.subject,
    key: topic.key,
    // Mavjud kalit sarlavha o'zgarganda o'zgarib ketmasin.
    keyTouched: true,
    title: toTextDraft(topic.title),
    goal: toTextDraft(topic.goal),
    minGrade: String(topic.minGrade),
    maxGrade: String(topic.maxGrade),
    status: topic.status,
  };
}

/* ─── Kalit (slug) ─── */

/** O'zbekcha kirill → lotin (kalit faqat lotin bo'lishi shart). */
const CYRILLIC_TO_LATIN: Readonly<Record<string, string>> = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'yo', ж: 'j', з: 'z', и: 'i', й: 'y',
  к: 'k', л: 'l', м: 'm', н: 'n', о: 'o', п: 'p', р: 'r', с: 's', т: 't', у: 'u', ф: 'f',
  х: 'x', ц: 'ts', ч: 'ch', ш: 'sh', щ: 'sh', ъ: '', ы: 'i', ь: '', э: 'e', ю: 'yu', я: 'ya',
  ў: 'o', қ: 'q', ғ: 'g', ҳ: 'h',
};

/** oʻ / gʻ / ' belgilari: kalitda harfning o'zi qoladi, tutuq belgisi tushadi. */
const APOSTROPHES = /[ʻʼ‘’`´'`]/g;
const COMBINING_MARKS = /[̀-ͯ]/g;

/**
 * Sarlavhadan kalit taklif qiladi: "Oʻzbekiston tarixi" → "ozbekiston-tarixi".
 * Natija har doim `TOPIC_KEY_PATTERN`ga mos (yoki bo'sh) va ≤ `TOPIC_KEY_MAX`.
 */
export function slugify(text: string): string {
  const latin = Array.from(text.toLowerCase())
    .map((ch) => CYRILLIC_TO_LATIN[ch] ?? ch)
    .join('');
  const slug = latin
    .normalize('NFKD')
    .replace(COMBINING_MARKS, '')
    .replace(APOSTROPHES, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug.slice(0, TOPIC_KEY_MAX).replace(/-+$/, '');
}

/** Kalit maydoniga yozilganda: kichik harf, bo'shliq → `-`. */
export const normalizeKeyInput = (value: string): string =>
  value.toLowerCase().replace(/\s+/g, '-');

/** O'zbekcha sarlavha o'zgarganda: kalit qo'lda yozilmagan bo'lsa, yangidan taklif qilinadi. */
export function withTitleUz(form: TopicForm, uz: string): TopicForm {
  const title = { ...form.title, uz };
  return form.keyTouched ? { ...form, title } : { ...form, title, key: slugify(uz) };
}

/**
 * Kalit qo'lda o'zgartirilganda avtomatik taklif to'xtaydi. Yaratishda maydon
 * tozalansa taklif qayta yoqiladi; TAHRIRLASHDA esa kalit bo'sh qoladi
 * ("Kalit majburiy" xatosi chiqadi) — mavjud kalitni jimgina almashtirmaymiz.
 */
export function withKey(form: TopicForm, value: string, mode: TopicFormMode): TopicForm {
  const key = normalizeKeyInput(value);
  if (key === '' && mode === 'create') {
    return { ...form, key: slugify(form.title.uz), keyTouched: false };
  }
  return { ...form, key, keyTouched: true };
}

/** Backend "kalit band" (409) deb rad etgan kalit — shu FAN ichida. */
export interface RejectedKey {
  subject: LearningSubject | '';
  key: string;
}

/** Forma hali ham aynan shu fan va kalitni yuboryaptimi (xato ko'rinib turishi kerak). */
export const isKeyRejected = (rejected: RejectedKey | null, form: TopicForm): boolean =>
  rejected !== null && rejected.subject === form.subject && rejected.key === form.key.trim();

/* ─── Validatsiya ─── */

/** "1".."11" → son, aks holda `null`. */
export function parseGrade(raw: string): number | null {
  if (!/^\d+$/.test(raw.trim())) return null;
  const value = Number(raw);
  return value >= MIN_GRADE && value <= MAX_GRADE ? value : null;
}

const KEY_FORMAT_MESSAGE =
  "Kalit: kichik lotin harflari, raqamlar va so'zlar orasida bitta '-' (masalan, oddiy-kasrlar).";

function keyError(key: string): string | null {
  const value = key.trim();
  if (!value) return 'Kalit majburiy.';
  if (value.length > TOPIC_KEY_MAX) return `Kalit ${TOPIC_KEY_MAX} belgidan oshmasin.`;
  return TOPIC_KEY_PATTERN.test(value) ? null : KEY_FORMAT_MESSAGE;
}

function gradeErrors(form: TopicForm): Pick<TopicFormErrors, 'minGrade' | 'maxGrade'> {
  const min = parseGrade(form.minGrade);
  const max = parseGrade(form.maxGrade);
  return {
    ...(min === null ? { minGrade: `Boshlang'ich sinfni tanlang (${MIN_GRADE}–${MAX_GRADE}).` } : {}),
    ...(max === null ? { maxGrade: `Yuqori sinfni tanlang (${MIN_GRADE}–${MAX_GRADE}).` } : {}),
    ...(min !== null && max !== null && min > max
      ? { maxGrade: "Yuqori sinf boshlang'ich sinfdan kichik bo'lmasin." }
      : {}),
  };
}

export function validateTopicForm(form: TopicForm, mode: TopicFormMode): TopicFormErrors {
  const checks: Array<[TopicFormField, string | null]> = [
    ['subject', mode === 'create' && !isLearningSubject(form.subject) ? 'Fanni tanlang.' : null],
    ['key', keyError(form.key)],
    ['title', form.title.uz.trim() ? null : "Mavzu nomi (o'zbekcha) majburiy."],
  ];
  const fieldErrors = Object.fromEntries(checks.filter(([, message]) => message !== null));
  return { ...fieldErrors, ...gradeErrors(form) } as TopicFormErrors;
}

export const hasTopicFormErrors = (errors: TopicFormErrors) => Object.keys(errors).length > 0;

/* ─── Payload ─── */

const nonEmpty = (value: string) => value.trim() || undefined;

const cleanTitle = (t: TextDraft): LearningTopicTitle => {
  const ru = nonEmpty(t.ru);
  const en = nonEmpty(t.en);
  return { uz: t.uz.trim(), ...(ru ? { ru } : {}), ...(en ? { en } : {}) };
};

/** Hech bir til to'ldirilmagan bo'lsa `null` (maqsad yo'q). */
const cleanGoal = (t: TextDraft): LearningText | null => {
  const uz = nonEmpty(t.uz);
  const ru = nonEmpty(t.ru);
  const en = nonEmpty(t.en);
  if (!uz && !ru && !en) return null;
  return { ...(uz ? { uz } : {}), ...(ru ? { ru } : {}), ...(en ? { en } : {}) };
};

interface NormalizedTopic {
  key: string;
  title: LearningTopicTitle;
  goal: LearningText | null;
  minGrade: number;
  maxGrade: number;
  status: LearningTopicStatus;
}

/** Faqat validatsiyadan o'tgan forma uchun (sinflar to'g'ri son). */
function normalizeTopicForm(form: TopicForm): NormalizedTopic {
  const minGrade = parseGrade(form.minGrade);
  const maxGrade = parseGrade(form.maxGrade);
  if (minGrade === null || maxGrade === null) {
    throw new Error("Sinflar tanlanmagan — avval validateTopicForm() chaqiring");
  }
  return {
    key: form.key.trim(),
    title: cleanTitle(form.title),
    goal: cleanGoal(form.goal),
    minGrade,
    maxGrade,
    status: form.status,
  };
}

export function toTopicCreatePayload(form: TopicForm): LearningTopicCreatePayload {
  if (!isLearningSubject(form.subject)) {
    throw new Error('Fan tanlanmagan — avval validateTopicForm() chaqiring');
  }
  const { goal, ...rest } = normalizeTopicForm(form);
  // Bo'sh maqsad yuborilmaydi.
  return { subject: form.subject, ...rest, ...(goal ? { goal } : {}) };
}

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

const PATCHABLE_KEYS = ['key', 'title', 'minGrade', 'maxGrade', 'status'] as const;

/**
 * Faqat o'zgargan maydonlar (`original` — forma shundan to'ldirilgan).
 * Maqsad butunlay tozalansa `goal: null` yuboriladi. Hech narsa o'zgarmagan
 * bo'lsa `{}`.
 */
export function toTopicPatchPayload(form: TopicForm, original: LearningTopic): LearningTopicPatch {
  const next = normalizeTopicForm(form);
  const prev = normalizeTopicForm(formFromTopic(original));
  const patch = PATCHABLE_KEYS.reduce<LearningTopicPatch>(
    (acc, key) => (same(next[key], prev[key]) ? acc : { ...acc, [key]: next[key] }),
    {},
  );
  return same(next.goal, prev.goal) ? patch : { ...patch, goal: next.goal };
}

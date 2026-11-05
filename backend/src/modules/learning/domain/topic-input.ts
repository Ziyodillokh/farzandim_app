// Mavzu katalogi kiritmasi validatsiyasi — admin API va backfill skripti
// umumiy qoidadan foydalanadi (sof funksiyalar).

import { LEARNING_LANGS, LearningLang, LocalizedText } from './localized';
import { MAX_GRADE, MIN_GRADE } from './subjects';

/** Mavzu kaliti: lotin kichik harf / raqam, defis bilan ajratilgan slug. */
export const TOPIC_KEY_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;
export const TOPIC_KEY_MAX = 80;
export const TOPIC_TITLE_MAX = 80;
export const TOPIC_GOAL_MAX = 300;

/** `{uz, ru?, en?}` — uz majburiy. */
export type TopicText = { uz: string } & Partial<Record<Exclude<LearningLang, 'uz'>, string>>;

export type TopicTextResult =
  | { ok: true; value: TopicText }
  | { ok: false; error: string };

export function isValidTopicKey(key: unknown): key is string {
  return typeof key === 'string' && key.length <= TOPIC_KEY_MAX && TOPIC_KEY_PATTERN.test(key);
}

/**
 * Uch tilli matn: `uz` bo'sh bo'lmasligi shart, `ru` / `en` ixtiyoriy (bo'sh
 * satr — berilmagan). Noma'lum til kaliti xato (imlo xatosini yashirmaslik uchun).
 */
export function parseTopicText(value: unknown, field: string, maxLength: number): TopicTextResult {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { ok: false, error: `${field}: {uz, ru?, en?} obyekt kerak` };
  }
  const record = value as Record<string, unknown>;
  const unknown = Object.keys(record).filter((k) => !(LEARNING_LANGS as readonly string[]).includes(k));
  if (unknown.length > 0) {
    return { ok: false, error: `${field}: noma'lum til (${unknown.join(', ')})` };
  }
  const result: Partial<Record<LearningLang, string>> = {};
  for (const lang of LEARNING_LANGS) {
    const raw = record[lang];
    if (raw === undefined || raw === null) continue;
    if (typeof raw !== 'string') return { ok: false, error: `${field}.${lang}: matn kerak` };
    const text = raw.trim();
    if (text.length > maxLength) {
      return { ok: false, error: `${field}.${lang}: ${maxLength} belgidan uzun` };
    }
    if (text.length > 0) result[lang] = text;
  }
  if (!result.uz) return { ok: false, error: `${field}.uz: bo'sh bo'lmasligi kerak` };
  return { ok: true, value: result as TopicText };
}

/** Yetishmayotgan tillar `uz` bilan to'ldiriladi (eski ilovalar uch tilni kutadi). */
export function fillTopicText(text: TopicText): LocalizedText {
  return { uz: text.uz, ru: text.ru ?? text.uz, en: text.en ?? text.uz };
}

/** Xato matni yoki `null`. */
export function gradeRangeError(minGrade: number, maxGrade: number): string | null {
  const valid = (g: number) => Number.isInteger(g) && g >= MIN_GRADE && g <= MAX_GRADE;
  if (!valid(minGrade) || !valid(maxGrade)) {
    return `minGrade / maxGrade ${MIN_GRADE}..${MAX_GRADE} oralig'ida butun son bo'lishi kerak`;
  }
  return minGrade > maxGrade ? 'minGrade maxGrade dan katta bo\'lmasligi kerak' : null;
}

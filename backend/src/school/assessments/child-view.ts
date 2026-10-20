// Bola ilovasi uchun test ko'rinishi va javoblarni tekshirish (sof funksiyalar).
// Bolaga FAQAT savol matni va variantlar boradi: to'g'ri javob (`correct`),
// shkala, teskari belgisi va variant shkalalari YUBORILMAYDI.

import { invalid } from '../common/school-errors';
import type { ChildAnswer } from './assessments-inputs.schemas';
import type { AnswerVector } from './psych/scoring';
import type { Localized, PsychItem, PsychTest } from './psych/types';

export type ChildLang = 'uz' | 'ru';
export type ChildOption = { key: string; text: string };
export type ChildItem =
  | { id: string; type: 'SINGLE'; text: string; options: ChildOption[]; stimulus?: { text: string; showSec: number } }
  | { id: string; type: 'LIKERT'; text: string }
  | { id: string; type: 'MULTI'; text: string; options: ChildOption[] };

export const childLang = (language: string | null | undefined): ChildLang => (language === 'ru' ? 'ru' : 'uz');

/** Bola tilidagi matn (bo'sh bo'lsa — ikkinchi til). */
export function pick(text: Localized, lang: ChildLang): string {
  return lang === 'ru' ? text.ru || text.uz : text.uz || text.ru;
}

function toChildItem(item: PsychItem, lang: ChildLang): ChildItem {
  const options = (opts: ReadonlyArray<{ key: string; text: Localized }>) => opts.map((o) => ({ key: o.key, text: pick(o.text, lang) }));
  if (item.type === 'LIKERT') return { id: item.id, type: 'LIKERT', text: pick(item.text, lang) };
  if (item.type === 'MULTI') return { id: item.id, type: 'MULTI', text: pick(item.text, lang), options: options(item.options) };
  return {
    id: item.id,
    type: 'SINGLE',
    text: pick(item.text, lang),
    options: options(item.options),
    ...(item.stimulus ? { stimulus: { text: pick(item.stimulus.text, lang), showSec: item.stimulus.showSec } } : {}),
  };
}

export function toChildTest(test: PsychTest, lang: ChildLang) {
  return {
    testId: test.id,
    kind: test.kind,
    title: pick(test.title, lang),
    description: pick(test.description, lang),
    instructions: pick(test.instructions, lang),
    timeLimitMin: test.timeLimitMin,
    /** LIKERT javoblari: 1 (hech qachon) … 5 (doim). */
    likert: { min: 1, max: 5 },
    items: test.items.map((item) => toChildItem(item, lang)),
  };
}

const bad = (itemId: string) => invalid(`answers.${itemId}: assessments.validation.answer`);

function itemAnswer(item: PsychItem, a: ChildAnswer): string | number | number[] {
  if (item.type === 'SINGLE') {
    if (typeof a !== 'string' || !item.options.some((o) => o.key === a)) throw bad(item.id);
    return a;
  }
  if (item.type === 'LIKERT') {
    if (typeof a !== 'number' || !Number.isInteger(a) || a < 1 || a > 5) throw bad(item.id);
    return a;
  }
  if (!Array.isArray(a) || new Set(a).size !== a.length) throw bad(item.id);
  const indexes = a.map((key) => item.options.findIndex((o) => o.key === key));
  if (indexes.some((i) => i < 0)) throw bad(item.id);
  return [...indexes].sort((x, y) => x - y);
}

/**
 * `{ itemId: javob }` → hisoblash vektori (savollar tartibida). Noma'lum savol yoki
 * turga mos kelmaydigan javob — VALIDATION; yo'q / null — o'tkazib yuborilgan.
 */
export function toAnswerVector(test: Pick<PsychTest, 'items'>, answers: Readonly<Record<string, ChildAnswer>>): AnswerVector {
  const known = new Set(test.items.map((i) => i.id));
  const unknown = Object.keys(answers).find((id) => !known.has(id));
  if (unknown !== undefined) throw bad(unknown);
  const vector = test.items.map((item) => {
    const a = Object.prototype.hasOwnProperty.call(answers, item.id) ? answers[item.id] : null;
    return a === null || a === undefined ? null : itemAnswer(item, a);
  });
  if (vector.every((v) => v === null)) throw invalid('answers: errors.form.selectAtLeastOne');
  return vector;
}

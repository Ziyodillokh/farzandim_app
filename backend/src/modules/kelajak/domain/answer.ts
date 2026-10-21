// Javobni tekshirish (PUT /kelajak/sessions/:id/answers/:questionId):
// shkala savoliga faqat variantdagi `value`, ochiq savolga faqat `text`
// (bo'sh matn — javobni o'chirish). Aynan bittasi beriladi.

import { TEXT_ANSWER_MAX_LENGTH } from './catalog';

export interface AnswerInput {
  value?: number | null;
  text?: string | null;
}

export type AnswerDecision =
  | { ok: true; kind: 'value'; value: number }
  | { ok: true; kind: 'text'; text: string }
  | { ok: true; kind: 'clear' }
  | { ok: false; error: string };

export function decideAnswer(
  question: { answerType: string; options: ReadonlyArray<{ value: number }> },
  input: AnswerInput,
): AnswerDecision {
  const hasValue = input.value !== undefined && input.value !== null;
  const hasText = input.text !== undefined && input.text !== null;

  if (question.answerType === 'text') {
    if (hasValue) return { ok: false, error: 'Open question takes text, not value' };
    if (!hasText) return { ok: false, error: 'text is required' };
    const text = (input.text as string).trim();
    if (text.length > TEXT_ANSWER_MAX_LENGTH) {
      return { ok: false, error: `text must be at most ${TEXT_ANSWER_MAX_LENGTH} characters` };
    }
    return text.length === 0 ? { ok: true, kind: 'clear' } : { ok: true, kind: 'text', text };
  }

  if (hasText) return { ok: false, error: 'Scale question takes value, not text' };
  if (!hasValue) return { ok: false, error: 'value is required' };
  const value = input.value as number;
  if (!Number.isInteger(value) || !question.options.some((o) => o.value === value)) {
    return { ok: false, error: 'value is not one of the options' };
  }
  return { ok: true, kind: 'value', value };
}

import type { DevDomain, Localized, PsychItem, PsychTest, PsychTestKind } from '@/data/contracts';
import type { PsychItemInput, PsychScaleInput, PsychTestInput } from '@/data/schemas/assessments';

/** Test konstruktori yordamchilari (forma qiymatlari ↔ test). */
const KIND_DEFAULTS: Record<PsychTestKind, Pick<PsychScaleInput, 'domain' | 'polarity' | 'display'>> = {
  COGNITIVE: { domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' },
  ATTENTION: { domain: 'ATTENTION', polarity: 'HIGHER_BETTER', display: 'STANDARD' },
  EMOTIONAL: { domain: 'EMOTIONAL', polarity: 'HIGHER_BETTER', display: 'LEVEL' },
  SELF_ESTEEM: { domain: 'SELF_ESTEEM', polarity: 'HIGHER_BETTER', display: 'PERCENTILE' },
  CAREER: { domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
  SOCIAL: { domain: 'SOCIAL', polarity: 'HIGHER_BETTER', display: 'PERCENTILE' },
  CUSTOM: { domain: 'REASONING' satisfies DevDomain, polarity: 'HIGHER_BETTER', display: 'STANDARD' },
};

export function defaultScale(kind: PsychTestKind, label: Localized, key = 'total'): PsychScaleInput {
  return { key, label, ...KIND_DEFAULTS[kind] };
}

const OPTION_KEYS = 'abcdefgh'.split('');

/** Hali ishlatilmagan birinchi harf (a, b, c…). */
export function nextOptionKey(used: readonly string[]): string {
  return OPTION_KEYS.find((k) => !used.includes(k)) ?? `o${used.length + 1}`;
}

/** q1, q2… — mavjudlaridan keyingi raqam. */
export function nextItemId(items: ReadonlyArray<{ id: string }>): string {
  const max = items.reduce((m, it) => Math.max(m, Number(/^q(\d+)$/.exec(it.id)?.[1] ?? 0)), 0);
  return `q${max + 1}`;
}

const blank = (): Localized => ({ uz: '', ru: '' });

export function newItem(type: PsychItem['type'], id: string, scale: string): PsychItemInput {
  if (type === 'LIKERT') return { id, type, scale, text: blank(), reverse: false };
  if (type === 'MULTI') {
    return { id, type, text: blank(), options: ['a', 'b', 'c'].map((key) => ({ key, text: blank(), scale })) };
  }
  return { id, type, scale, text: blank(), options: ['a', 'b', 'c', 'd'].map((key) => ({ key, text: blank() })), correct: 'a' };
}

/** Savol turini almashtirish: matn saqlanadi, variantlar moslashtiriladi. */
export function changeItemType(item: PsychItemInput, type: PsychItem['type'], fallbackScale: string): PsychItemInput {
  if (item.type === type) return item;
  const scale = item.type === 'MULTI' ? (item.options[0]?.scale ?? fallbackScale) : item.scale;
  const next = newItem(type, item.id, scale);
  const texts = item.type === 'LIKERT' ? [] : item.options.map((o) => o.text);
  if (next.type === 'SINGLE') return { ...next, text: item.text, options: next.options.map((o, i) => ({ ...o, text: texts[i] ?? o.text })) };
  if (next.type === 'MULTI') return { ...next, text: item.text, options: next.options.map((o, i) => ({ ...o, text: texts[i] ?? o.text })) };
  return { ...next, text: item.text };
}

export function toInput(test: PsychTest): PsychTestInput {
  return {
    title: test.title,
    description: test.description,
    instructions: test.instructions,
    kind: test.kind,
    grades: test.grades,
    timeLimitMin: test.timeLimitMin,
    scales: test.scales,
    items: test.items,
    scoring: test.scoring,
    norms: test.norms,
  };
}

/** O'chirilgan shkalalarning me'yorlari tashlanadi (aks holda tekshiruvdan o'tmaydi). */
export function normsForScales(norms: PsychTestInput['norms'], scales: ReadonlyArray<{ key: string }>): PsychTestInput['norms'] {
  const keys = new Set(scales.map((s) => s.key));
  return Object.fromEntries(Object.entries(norms).filter(([k]) => keys.has(k)));
}

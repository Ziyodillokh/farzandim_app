import type { ChoiceOption, Localized, PsychItem, Stimulus } from '@/data/contracts';

/**
 * Shablon savollarini ixcham yozish uchun yordamchilar.
 * Original demo content written for Parvoz. Not derived from any published instrument.
 */
export type TemplateContent = { description: Localized; instructions: Localized; items: PsychItem[] };
export type Pair = [uz: string, ru: string];

const OPTION_KEYS = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'] as const;

export const L = (uz: string, ru: string): Localized => ({ uz, ru });

function optionKey(i: number): string {
  const key = OPTION_KEYS[i];
  if (!key) throw new RangeError(`option ${i}`);
  return key;
}

/** Variantlar (uz, ru) juftliklari → a, b, c, d… */
export function options(pairs: readonly Pair[]): ChoiceOption[] {
  return pairs.map(([uz, ru], i) => ({ key: optionKey(i), text: L(uz, ru) }));
}

/** Ikkala tilda bir xil yoziladigan variantlar (sonlar, belgilar). */
export function same(values: ReadonlyArray<string | number>): ChoiceOption[] {
  return values.map((v, i) => ({ key: optionKey(i), text: L(String(v), String(v)) }));
}

export function single(
  id: string,
  scale: string,
  text: Pair,
  opts: ChoiceOption[],
  correct: string,
  stimulus?: { text: Pair; showSec: number },
): PsychItem {
  const base = { id, type: 'SINGLE' as const, scale, text: L(...text), options: opts, correct };
  if (!stimulus) return base;
  const s: Stimulus = { text: L(...stimulus.text), showSec: stimulus.showSec };
  return { ...base, stimulus: s };
}

export function likert(id: string, scale: string, text: Pair, reverse = false): PsychItem {
  return { id, type: 'LIKERT', scale, text: L(...text), reverse };
}

/** Ko'p tanlovli savol: har variant o'z shkalasiga (masalan, R/I/A/S/E/C) bog'langan. */
export function multi(id: string, text: Pair, opts: ReadonlyArray<[scale: string, uz: string, ru: string]>): PsychItem {
  return {
    id,
    type: 'MULTI',
    text: L(...text),
    options: opts.map(([scale, uz, ru], i) => ({ key: optionKey(i), text: L(uz, ru), scale })),
  };
}

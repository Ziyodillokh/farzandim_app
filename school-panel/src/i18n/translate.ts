import { ru } from './ru';
import type { PluralForms, PluralKey, TextKey, Vars } from './types';
import { uz, type Dict } from './uz';

export type Locale = 'uz' | 'ru';
export const LOCALES: readonly Locale[] = ['uz', 'ru'];
export const DEFAULT_LOCALE: Locale = 'uz';

export type TKey = TextKey<Dict>;
export type TPluralKey = PluralKey<Dict>;

const DICTS: Record<Locale, unknown> = { uz, ru };

function lookup(locale: Locale, key: string): unknown {
  let node: unknown = DICTS[locale];
  for (const part of key.split('.')) {
    if (node && typeof node === 'object' && part in (node as Record<string, unknown>)) {
      node = (node as Record<string, unknown>)[part];
    } else {
      return undefined;
    }
  }
  return node;
}

function interpolate(template: string, vars?: Vars): string {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in vars ? String(vars[name]) : match,
  );
}

/** Matn tarjimasi. Kalit topilmasa — o'zbekcha, u ham bo'lmasa kalitning o'zi. */
export function translate(locale: Locale, key: TKey | string, vars?: Vars): string {
  const value = lookup(locale, key) ?? lookup(DEFAULT_LOCALE, key);
  return typeof value === 'string' ? interpolate(value, vars) : key;
}

/** Kalit lug'atda bormi (masalan, audit amali uchun tarjima mavjudligini tekshirish). */
export function hasKey(locale: Locale, key: string): boolean {
  return typeof (lookup(locale, key) ?? lookup(DEFAULT_LOCALE, key)) === 'string';
}

const pluralRules: Record<Locale, Intl.PluralRules> = {
  uz: new Intl.PluralRules('uz'),
  ru: new Intl.PluralRules('ru'),
};

/** Ko'plik: rus tilida 1 ученик / 2 ученика / 5 учеников. */
export function translatePlural(locale: Locale, key: TPluralKey | string, count: number, vars?: Vars): string {
  const node = (lookup(locale, key) ?? lookup(DEFAULT_LOCALE, key)) as PluralForms | undefined;
  if (!node || typeof node !== 'object') return key;
  const rule = pluralRules[locale].select(count);
  const form = rule === 'one' ? node.one : rule === 'few' ? node.few : node.many;
  return interpolate(form, { count, ...vars });
}

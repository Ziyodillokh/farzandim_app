'use client';

import { format as formatDateFns, formatDistanceStrict } from 'date-fns';
import { ru as ruLocale, uz as uzLocale } from 'date-fns/locale';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

import { readPref, writePref } from '@/lib/prefs';
import {
  DEFAULT_LOCALE,
  type Locale,
  LOCALES,
  type TKey,
  type TPluralKey,
  translate,
  translatePlural,
} from './translate';
import type { Vars } from './types';

export type { Locale, TKey, TPluralKey } from './translate';
export { LOCALES, translate, translatePlural } from './translate';

const DATE_LOCALES = { uz: uzLocale, ru: ruLocale } as const;
// Brauzerlarda uz-UZ raqam formati to'liq emas (6,870,500): o'zbek yozuvi ham
// bo'shliqli guruh va vergulli kasr ishlatadi — ru-RU formati shunga mos ("6 870 500", "67,3").
const INTL_LOCALES: Record<Locale, string> = { uz: 'ru-RU', ru: 'ru-RU' };
const PREF_KEY = 'locale';

type I18nValue = {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: (key: TKey, vars?: Vars) => string;
  tc: (key: TPluralKey, count: number, vars?: Vars) => string;
  /** date-fns format, masalan `formatDate(date, 'd MMMM, EEEE')`. */
  formatDate: (date: Date | string | number, pattern: string) => string;
  formatNumber: (value: number, options?: Intl.NumberFormatOptions) => string;
  formatRelative: (date: Date | string | number) => string;
};

const I18nContext = createContext<I18nValue | null>(null);

function isLocale(value: unknown): value is Locale {
  return typeof value === 'string' && (LOCALES as readonly string[]).includes(value);
}

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(DEFAULT_LOCALE);

  useEffect(() => {
    const saved = readPref<string>(PREF_KEY);
    if (isLocale(saved)) setLocaleState(saved);
  }, []);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    writePref(PREF_KEY, next);
  }, []);

  const value = useMemo<I18nValue>(() => {
    const dateLocale = DATE_LOCALES[locale];
    const toDate = (d: Date | string | number) => (d instanceof Date ? d : new Date(d));
    return {
      locale,
      setLocale,
      t: (key, vars) => translate(locale, key, vars),
      tc: (key, count, vars) => translatePlural(locale, key, count, vars),
      formatDate: (date, pattern) => formatDateFns(toDate(date), pattern, { locale: dateLocale }),
      formatNumber: (n, options) => new Intl.NumberFormat(INTL_LOCALES[locale], options).format(n),
      formatRelative: (date) => {
        const now = new Date();
        const at = toDate(date);
        if (at >= now) return translate(locale, 'common.justNow');
        return formatDistanceStrict(at, now, { addSuffix: true, locale: dateLocale });
      },
    };
  }, [locale, setLocale]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nValue {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n: I18nProvider ichida ishlating');
  return ctx;
}

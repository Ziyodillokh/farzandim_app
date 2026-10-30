/** Sof yordamchilar (hook'siz): farq, foiz o'qi shkalasi va CSV formatlash. */
import { csvNumber as libCsvNumber } from '@/lib/csv';
import { type NiceScale, niceScale } from '@/lib/scale';

/** CSV uchun son (standart — 1 kasr xonasi): umumiy `lib/csv` ustida. */
export function csvNumber(v: number | null | undefined, decimals = 1): string {
  return libCsvNumber(v, decimals);
}

/** Ikki qiymat farqi (bir kasr xonasi bilan), biri yo'q bo'lsa — null. */
export function gap(a: number | null | undefined, b: number | null | undefined): number | null {
  if (a === null || a === undefined || b === null || b === undefined) return null;
  return Math.round((a - b) * 10) / 10;
}

/**
 * Foiz o'qi sozlamasi: yuqori chegara 100%, qadamlar butun (o'qda "67,5%" yo'q),
 * oraliq kamida 4 p.p. — kichik o'zgarish bo'rttirib ko'rsatilmaydi.
 */
export const PCT_AXIS = { ceil: 100, minSpan: 2, integer: true } as const;

/** Foiz ko'rsatkichlari o'qi (umumiy `lib/scale` ustida); qiymat yo'q bo'lsa — null. */
export function pctScale(values: ReadonlyArray<number | null | undefined>): NiceScale | null {
  return niceScale(
    values.map((v) => v ?? null),
    PCT_AXIS,
  );
}

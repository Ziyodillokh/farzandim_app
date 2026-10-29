/** Sof yordamchilar (hook'siz): farq va CSV formatlash. */

/** CSV uchun son: Excel (uz/ru lokali) o'nlik vergulni kutadi. */
export function csvNumber(v: number | null | undefined, decimals = 1): string {
  return v === null || v === undefined ? '' : v.toFixed(decimals).replace('.', ',');
}

/** Ikki qiymat farqi (bir kasr xonasi bilan), biri yo'q bo'lsa — null. */
export function gap(a: number | null | undefined, b: number | null | undefined): number | null {
  if (a === null || a === undefined || b === null || b === undefined) return null;
  return Math.round((a - b) * 10) / 10;
}

const NICE_STEPS = [1, 2, 5, 10, 20, 25, 50] as const;

/**
 * Chiziqli grafik uchun "chiroyli" shkala: qiymatlar (va mos yozuv chizig'i)
 * sig'adigan, bo'linmalari butun qadam (1, 2, 5…) bo'lgan oraliq.
 * `intervals` berilsa — aynan shuncha bo'linma (recharts standart 5 ta belgi uchun 4).
 */
export function niceScale(values: ReadonlyArray<number | null | undefined>, opts: { pad?: number; maxIntervals?: number; intervals?: number } = {}) {
  const { pad = 0.5, maxIntervals = 5, intervals } = opts;
  const finite = values.filter((v): v is number => typeof v === 'number' && Number.isFinite(v));
  if (finite.length === 0) return { domain: [0, 100] as [number, number], ticks: [0, 25, 50, 75, 100] };
  const min = Math.min(...finite) - pad;
  const max = Math.max(...finite) + pad;
  for (const step of NICE_STEPS) {
    const lo = Math.max(0, Math.floor(min / step) * step);
    const n = Math.round((Math.ceil(max / step) * step - lo) / step);
    if (n > (intervals ?? maxIntervals)) continue;
    const count = intervals ?? Math.max(1, n);
    return { domain: [lo, lo + count * step] as [number, number], ticks: Array.from({ length: count + 1 }, (_, i) => lo + i * step) };
  }
  return { domain: [0, 100] as [number, number], ticks: [0, 25, 50, 75, 100] };
}

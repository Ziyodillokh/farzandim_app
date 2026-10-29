/**
 * Hayot yo'nalishlari sahifalari (farovonlik, davomat, raqamli odatlar) uchun
 * sof yordamchilar: ustun o'rtachalari, eng chekka sinflar, ustunli diagramma
 * shkalasi va "har N boladan 1 tasi" ifodasi. UI'siz — testlanadi.
 */

export type GradePoint = { grade: number; value: number | null };
export type GradeExtreme = { from: number; to: number; value: number };

/** Qiymatlar o'rtachasi (null'lar hisobga olinmaydi); bo'sh bo'lsa null. */
export function meanOf(values: ReadonlyArray<number | null | undefined>): number | null {
  const valid = values.filter((v): v is number => typeof v === 'number' && Number.isFinite(v));
  if (!valid.length) return null;
  return valid.reduce((sum, v) => sum + v, 0) / valid.length;
}

/**
 * Eng yuqori (yoki eng past) qiymatli sinflar: birinchi uzluksiz oraliq
 * ("6–8-sinflar"). Ma'lumot bo'lmasa null.
 */
export function extremeGrades(points: readonly GradePoint[], dir: 'max' | 'min', epsilon = 1e-9): GradeExtreme | null {
  const valid = points.filter((p): p is { grade: number; value: number } => p.value !== null && Number.isFinite(p.value));
  if (!valid.length) return null;
  const target = dir === 'max' ? Math.max(...valid.map((p) => p.value)) : Math.min(...valid.map((p) => p.value));
  const sorted = [...valid].sort((a, b) => a.grade - b.grade);
  const startIndex = sorted.findIndex((p) => Math.abs(p.value - target) <= epsilon);
  const start = sorted[startIndex];
  if (!start) return null;
  let to = start.grade;
  for (let i = startIndex + 1; i < sorted.length; i += 1) {
    const p = sorted[i];
    if (!p || p.grade !== to + 1 || Math.abs(p.value - target) > epsilon) break;
    to = p.grade;
  }
  return { from: start.grade, to, value: target };
}

/**
 * Sinflardagi chekka guruh: faqat u hamma qiymatli sinflarni qamramasa (aks
 * holda "eng past" ma'nosiz — masalan, filtrda faqat 10–11-sinflar qolgan).
 */
export function distinctExtremeGrades(points: readonly GradePoint[], dir: 'max' | 'min'): GradeExtreme | null {
  const ext = extremeGrades(points, dir);
  if (!ext) return null;
  const outside = points.some((p) => p.value !== null && Number.isFinite(p.value) && (p.grade < ext.from || p.grade > ext.to));
  return outside ? ext : null;
}

/** Oraliqdagi sinflar kalitlari (diagramma ustunlarini ajratish uchun): {from..to}. */
export function gradeRangeKeys(ext: Pick<GradeExtreme, 'from' | 'to'> | null): Set<string> {
  if (!ext || ext.to < ext.from) return new Set();
  return new Set(Array.from({ length: ext.to - ext.from + 1 }, (_, i) => String(ext.from + i)));
}

/** Eng chekka element (masalan, eng past davomatli hafta kuni). */
export function extremeBy<T>(items: readonly T[], value: (item: T) => number | null, dir: 'max' | 'min'): T | null {
  let best: T | null = null;
  let bestValue = 0;
  for (const item of items) {
    const v = value(item);
    if (v === null || !Number.isFinite(v)) continue;
    if (best === null || (dir === 'max' ? v > bestValue : v < bestValue)) {
      best = item;
      bestValue = v;
    }
  }
  return best;
}

/** Chekka qiymatli barcha elementlar (teng qiymatlar — hammasi), masalan "Davlat, Ixtisoslashgan". */
export function extremeAllBy<T>(items: readonly T[], value: (item: T) => number | null, dir: 'max' | 'min', epsilon = 1e-9): { items: T[]; value: number } | null {
  const best = extremeBy(items, value, dir);
  if (best === null) return null;
  const target = value(best) as number;
  const isExtreme = (item: T) => {
    const v = value(item);
    return v !== null && Math.abs(v - target) <= epsilon;
  };
  return { items: items.filter(isExtreme), value: target };
}

/** "Chiroyli" qadamlar (×10^k) — Recharts o'qi ham shu qadamlarni tanlaydi. */
const NICE_STEPS = [1, 2, 2.5, 5, 10] as const;
/** O'q oraliqlari soni (5 ta belgi). */
const AXIS_INTERVALS = 4;
/** Ma'lumot shkalaning qancha qismini egallashi (qolgani — havo). */
const DATA_SHARE = 2 / 3;

/** `integer` — butun sonli ko'rsatkichlar uchun (indeks, daqiqa): 2,5 kabi qadamlar o'tkazib yuboriladi. */
export function niceStep(rough: number, integer = false): number {
  if (!(rough > 0) || !Number.isFinite(rough)) return 1;
  const base = 10 ** Math.floor(Math.log10(rough));
  const candidates = NICE_STEPS.map((x) => Number((x * base).toPrecision(12))).filter((v) => !integer || Number.isInteger(v));
  const step = candidates.find((v) => v >= rough - 1e-9 * base);
  if (step !== undefined) return integer ? Math.max(1, step) : step;
  return niceStep(base * 10, integer);
}

const roundTick = (v: number) => Number(v.toPrecision(12));

export type NiceScale = { domain: [number, number]; ticks: number[] };

/**
 * O'q shkalasi: 4 ta teng "chiroyli" oraliq. `zero` — 0 dan boshlanadi (ulushlar);
 * aks holda qiymatlar o'rtada, oraliq kamida `minSpan` — kichik o'zgarish
 * bo'rttirib ko'rsatilmaydi (masalan, davomat 95–97% → 92–100%).
 */
export function niceScale(
  values: ReadonlyArray<number | null>,
  opts: { minSpan?: number; zero?: boolean; floor?: number; integer?: boolean } = {},
): NiceScale | null {
  const valid = values.filter((v): v is number => v !== null && Number.isFinite(v));
  if (!valid.length) return null;
  const { minSpan = 0, zero = false, floor = 0, integer = false } = opts;
  const min = Math.min(...valid);
  const max = Math.max(...valid);
  let lo: number;
  let step: number;
  if (zero) {
    lo = Math.min(0, min);
    step = niceStep((max - lo) / AXIS_INTERVALS || 1, integer);
  } else {
    const span = Math.max(max - min, minSpan, Math.abs(max) * 0.01, 1e-6);
    const pad = (span / DATA_SHARE - (max - min)) / 2;
    const rawLo = Math.max(floor, min - pad);
    step = niceStep((max + pad - rawLo) / AXIS_INTERVALS, integer);
    lo = Math.max(floor, Math.floor(rawLo / step) * step);
  }
  while (lo + step * AXIS_INTERVALS < max) {
    step = niceStep(step * 1.0001 + 1e-12, integer);
    if (!zero) lo = Math.max(floor, Math.floor(Math.min(lo, min) / step) * step);
  }
  const ticks = Array.from({ length: AXIS_INTERVALS + 1 }, (_, i) => roundTick(lo + step * i));
  return { domain: [ticks[0] as number, ticks[AXIS_INTERVALS] as number], ticks };
}

/** "Har N boladan 1 tasi": ulush (%) → N. Juda kichik ulushda ma'nosiz — null. */
export function oneIn(sharePercent: number | null, minShare = 2): number | null {
  if (sharePercent === null || !Number.isFinite(sharePercent) || sharePercent < minShare || sharePercent > 100) return null;
  return Math.max(1, Math.round(100 / sharePercent));
}

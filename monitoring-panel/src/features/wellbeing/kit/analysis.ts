/**
 * Hayot yo'nalishlari sahifalari (farovonlik, davomat, raqamli odatlar) uchun
 * sof yordamchilar: ustun o'rtachalari, eng chekka sinflar, ustunli diagramma
 * shkalasi va "har N boladan 1 tasi" ifodasi. UI'siz — testlanadi.
 */
import type { MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { niceScale, type NiceScale } from '@/lib/scale';

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

export { niceScale, niceStep, type NiceScale } from '@/lib/scale';

/** Foiz o'qining yuqori chegarasi: ulush 100% dan oshmaydi. */
export const PERCENT_MAX = 100;

/**
 * Ko'rsatkich o'qi (`niceScale` ustiga): foizda o'q 100% dan oshmaydi, butun
 * sonli ko'rsatkichlarda (indeks, daqiqa) belgilar butun. Ustunli diagrammada
 * `zero: true` — ustun uzunligi qiymatga mutanosib; `minSpan` — chiziqli trend uchun
 * (ustunlarda o'q kesilsa, bu diagramma ustida ko'rinadigan izoh bilan aytiladi).
 */
export function metricScale(metric: MetricKey, values: ReadonlyArray<number | null>, opts: { minSpan?: number; zero?: boolean } = {}): NiceScale | null {
  const def = METRICS[metric];
  return niceScale(values, { ...opts, ceil: def.unit === '%' ? PERCENT_MAX : undefined, integer: def.decimals === 0 });
}

/** "Har N boladan 1 tasi" mazmunli bo'ladigan eng kichik N ("har 1 boladan 1 tasi" — ma'nosiz). */
const MIN_ONE_IN = 2;

/** "Har N boladan 1 tasi": ulush (%) → N. Juda kichik yoki juda katta ulushda (N < 2) — null. */
export function oneIn(sharePercent: number | null, minShare = 2): number | null {
  if (sharePercent === null || !Number.isFinite(sharePercent) || sharePercent < minShare || sharePercent > 100) return null;
  const n = Math.round(100 / sharePercent);
  return n >= MIN_ONE_IN ? n : null;
}

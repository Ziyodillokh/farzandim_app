/**
 * Diagramma o'qlari uchun "chiroyli" shkala va qadamlar — barcha sahifalar uchun
 * umumiy (avval sahifa to'plamlarida takrorlangan edi).
 */

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
 * bo'rttirib ko'rsatilmaydi (masalan, davomat 95–97% → 92–100%). `ceil` — yuqori
 * chegara (foizlar uchun 100): o'q undan oshmaydi.
 */
export function niceScale(
  values: ReadonlyArray<number | null>,
  opts: { minSpan?: number; zero?: boolean; floor?: number; ceil?: number; integer?: boolean } = {},
): NiceScale | null {
  const valid = values.filter((v): v is number => v !== null && Number.isFinite(v));
  if (!valid.length) return null;
  const { minSpan = 0, zero = false, floor = 0, ceil, integer = false } = opts;
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
  // Yuqori chegara (masalan, foiz — 100): oraliq pastga suriladi, ma'lumot ichida qoladi.
  if (ceil !== undefined && max <= ceil && lo + step * AXIS_INTERVALS > ceil) lo = Math.max(floor, ceil - step * AXIS_INTERVALS);
  const ticks = Array.from({ length: AXIS_INTERVALS + 1 }, (_, i) => roundTick(lo + step * i));
  return { domain: [ticks[0] as number, ticks[AXIS_INTERVALS] as number], ticks };
}

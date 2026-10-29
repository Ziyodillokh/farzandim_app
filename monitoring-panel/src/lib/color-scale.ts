/**
 * Xarita va heatmap ranglari. Faqat ko'k / havorang / moviy va ehtiyot uchun
 * amber (binafsha va qizil yo'q — "yomon" emas, "e'tibor"):
 *  - diverging: respublika o'rtachasiga nisbatan — yaxshiroq → moviy, yomonroq → amber;
 *  - sequential: neytral ko'rsatkichlar (IQ o'rtachasi, murojaatlar) — ko'k tuslari.
 */

export const DIVERGING = [
  'hsl(32 94% 54%)', // ancha yomonroq
  'hsl(40 88% 62%)', // yomonroq
  'hsl(218 30% 52%)', // o'rtachaga yaqin
  'hsl(199 88% 55%)', // yaxshiroq
  'hsl(184 92% 47%)', // ancha yaxshiroq
] as const;

export const SEQUENTIAL = [
  'hsl(222 40% 34%)',
  'hsl(219 55% 44%)',
  'hsl(214 72% 52%)',
  'hsl(204 86% 56%)',
  'hsl(190 92% 52%)',
] as const;

export const NO_DATA_COLOR = 'hsl(220 18% 50% / 0.25)';

export type ScaleSpec = {
  mode: 'diverging' | 'sequential' | 'quantile';
  better: 'up' | 'down' | 'neutral';
  center: number | null;
  min: number;
  max: number;
  /** Quantile rejimi: tartiblangan qiymatlar (reyting bo'yicha 5 guruh). */
  sorted?: number[];
};

/**
 * Qiymatlar to'plamidan shkala. Standart — `quantile`: hududlar reyting bo'yicha
 * 5 teng guruhga (xarita doim muvozanatli: bitta keskin hudud qolganlarini
 * "bir rang" qilib qo'ymaydi). `diverging` — markaz (respublika) atrofida simmetrik.
 */
export function buildScale(
  values: Array<number | null>,
  better: 'up' | 'down' | 'neutral',
  center: number | null,
  mode: ScaleSpec['mode'] = 'quantile',
): ScaleSpec {
  const v = values.filter((x): x is number => x !== null && Number.isFinite(x));
  const min = v.length ? Math.min(...v) : 0;
  const max = v.length ? Math.max(...v) : 1;
  if (mode === 'quantile') return { mode, better, center, min, max, sorted: [...v].sort((a, b) => a - b) };
  const resolved = better === 'neutral' || center === null ? 'sequential' : mode;
  return { mode: resolved, better, center, min, max };
}

/** Rang indeksi 0..4 (0 — eng yomon / eng past guruh, 4 — eng yaxshi / eng yuqori). */
export function scaleIndex(value: number | null, s: ScaleSpec): number | null {
  if (value === null || !Number.isFinite(value)) return null;
  if (s.mode === 'quantile') {
    const sorted = s.sorted ?? [];
    if (sorted.length <= 1 || s.max === s.min) return 2;
    // Teng qiymatlar bir guruhda: qiymatdan kichiklar ulushi.
    const below = sorted.filter((x) => x < value).length;
    const equal = sorted.filter((x) => x === value).length;
    const pos = (below + (equal - 1) / 2) / (sorted.length - 1);
    let i = Math.min(4, Math.max(0, Math.round(pos * 4)));
    if (s.better === 'down') i = 4 - i;
    return i;
  }
  if (s.mode === 'sequential') {
    const span = s.max - s.min || 1;
    return Math.min(4, Math.max(0, Math.floor(((value - s.min) / span) * 4.999)));
  }
  const center = s.center as number;
  const spread = Math.max(Math.abs(s.max - center), Math.abs(center - s.min)) || 1;
  let t = (value - center) / spread; // -1..1
  if (s.better === 'down') t = -t;
  if (t <= -0.55) return 0;
  if (t <= -0.18) return 1;
  if (t < 0.18) return 2;
  if (t < 0.55) return 3;
  return 4;
}

export function scaleColor(value: number | null, s: ScaleSpec): string {
  const i = scaleIndex(value, s);
  if (i === null) return NO_DATA_COLOR;
  const palette = s.mode === 'sequential' || (s.mode === 'quantile' && s.better === 'neutral') ? SEQUENTIAL : DIVERGING;
  return palette[i] as string;
}

/** Heatmap katagi: ustun o'rtachasiga nisbatan (fon rangi + matn rangi). */
export function heatStyle(value: number | null, mean: number, spread: number, better: 'up' | 'down' = 'up'): { background: string; color?: string } {
  if (value === null) return { background: 'transparent' };
  let t = spread > 0 ? (value - mean) / spread : 0;
  if (better === 'down') t = -t;
  const k = Math.min(1, Math.abs(t));
  if (t >= 0) return { background: `hsl(192 90% 48% / ${0.08 + k * 0.42})` };
  return { background: `hsl(36 92% 56% / ${0.08 + k * 0.42})` };
}

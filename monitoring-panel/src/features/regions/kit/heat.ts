import type { CSSProperties } from 'react';

import { heatStyle } from '@/lib/color-scale';

export type ColumnStats = { mean: number; spread: number; min: number; max: number };

export const isNum = (v: number | null | undefined): v is number => typeof v === 'number' && Number.isFinite(v);

/** Ustun statistikasi (bo'sh qiymatlarsiz): o'rtacha, eng katta chetlanish, min va max. */
export function columnStats(values: ReadonlyArray<number | null | undefined>): ColumnStats | null {
  const vals = values.filter(isNum);
  if (!vals.length) return null;
  const mean = vals.reduce((sum, v) => sum + v, 0) / vals.length;
  const spread = Math.max(...vals.map((v) => Math.abs(v - mean)));
  return { mean, spread, min: Math.min(...vals), max: Math.max(...vals) };
}

/** Markaz berilgan statistika (masalan, doira o'rtachasi) — `minSpread` mayda farqlarni bo'rttirmaydi. */
export function centeredStats(values: ReadonlyArray<number | null | undefined>, center: number | null, minSpread: number): ColumnStats | null {
  if (center === null) return columnStats(values);
  const vals = values.filter(isNum);
  const spread = Math.max(minSpread, ...vals.map((v) => Math.abs(v - center)));
  return { mean: center, spread, min: Math.min(center, ...vals), max: Math.max(center, ...vals) };
}

/** Neytral ko'rsatkich (masalan, IQ o'rtachasi) — baholanmaydi, faqat ko'k intensivlik. */
const NEUTRAL_HSL = '214 80% 56%';

/**
 * Katak foni: ustun o'rtachasiga nisbatan — moviy yaxshiroq, amber e'tibor
 * (`better` bo'yicha). Neytral ko'rsatkich — bir tusli ko'k shkala.
 */
export function cellTint(value: number | null | undefined, stats: ColumnStats | null, better: 'up' | 'down' | 'neutral'): CSSProperties | undefined {
  if (!isNum(value) || !stats) return undefined;
  if (better === 'neutral') {
    const span = stats.max - stats.min;
    const k = span > 0 ? (value - stats.min) / span : 0.5;
    return { background: `hsl(${NEUTRAL_HSL} / ${(0.07 + k * 0.3).toFixed(3)})` };
  }
  return heatStyle(value, stats.mean, stats.spread, better);
}

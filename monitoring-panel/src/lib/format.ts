'use client';

import { useCallback, useMemo } from 'react';

import type { MetricKey, MetricUnit } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { useI18n } from '@/i18n';

export type Tone = 'good' | 'bad' | 'neutral';
const MINUS = '−';

/** O'zgarish rangi: ko'rsatkich qaysi yo'nalishda yaxshi ekaniga qarab. */
export function deltaTone(metric: MetricKey, delta: number | null | undefined, threshold = 0.05): Tone {
  if (delta === null || delta === undefined || Math.abs(delta) < threshold) return 'neutral';
  const better = METRICS[metric].better;
  if (better === 'neutral') return 'neutral';
  return (delta > 0) === (better === 'up') ? 'good' : 'bad';
}

/** Ko'rsatkichlarni joriy tilda formatlash. */
export function useMetricFormat() {
  const { formatNumber, t } = useI18n();

  const num = useCallback(
    (value: number, decimals = 1) => formatNumber(value, { minimumFractionDigits: decimals, maximumFractionDigits: decimals }).replace('-', MINUS),
    [formatNumber],
  );

  const unitSuffix = useCallback(
    (unit: MetricUnit): string => {
      switch (unit) {
        case '%':
          return '%';
        case 'min':
          return ` ${t('common.units.min')}`;
        default:
          return '';
      }
    },
    [t],
  );

  const value = useCallback(
    (metric: MetricKey, v: number | null | undefined, opts: { unit?: boolean } = {}) => {
      if (v === null || v === undefined) return '—';
      const def = METRICS[metric];
      return `${num(v, def.decimals)}${opts.unit === false ? '' : unitSuffix(def.unit)}`;
    },
    [num, unitSuffix],
  );

  /** "+1,2 p.p." / "−7 daq" / "+0,4". */
  const delta = useCallback(
    (metric: MetricKey, d: number | null | undefined) => {
      if (d === null || d === undefined) return '—';
      const def = METRICS[metric];
      const sign = d > 0 ? '+' : d < 0 ? MINUS : '±';
      const abs = num(Math.abs(d), def.decimals);
      const unit = def.unit === '%' ? ` ${t('common.units.pp')}` : def.unit === 'min' ? ` ${t('common.units.min')}` : '';
      return `${sign}${abs}${unit}`;
    },
    [num, t],
  );

  /** Ulush yoki foiz (taqsimotlar uchun). */
  const pct = useCallback((v: number | null | undefined, decimals = 1) => (v === null || v === undefined ? '—' : `${num(v, decimals)}%`), [num]);
  const count = useCallback((v: number | null | undefined) => (v === null || v === undefined ? '—' : formatNumber(Math.round(v))), [formatNumber]);
  /** 4 353 200 → "4,35 mln" (qisqa). */
  const compact = useCallback(
    (v: number | null | undefined) => (v === null || v === undefined ? '—' : formatNumber(v, { notation: 'compact', maximumFractionDigits: 2 })),
    [formatNumber],
  );

  return useMemo(() => ({ num, value, delta, pct, count, compact }), [num, value, delta, pct, count, compact]);
}

export const TONE_TEXT: Record<Tone, string> = {
  good: 'text-emerald-600 dark:text-emerald-400',
  bad: 'text-amber-600 dark:text-amber-400',
  neutral: 'text-muted-foreground',
};

export const TONE_CHIP: Record<Tone, string> = {
  good: 'bg-emerald-500/10 text-emerald-700 ring-emerald-500/25 dark:text-emerald-300',
  bad: 'bg-amber-500/10 text-amber-700 ring-amber-500/25 dark:text-amber-300',
  neutral: 'bg-muted text-muted-foreground ring-border',
};

/** "2026-10" → "Okt 26" (joriy tilda). */
export function useMonthLabel() {
  const { t } = useI18n();
  return useCallback(
    (key: string, withYear = false) => {
      const [y, m] = key.split('-');
      const name = t(`common.months.m${Number(m)}` as 'common.months.m1');
      return withYear ? `${name} ${String(y).slice(2)}` : name;
    },
    [t],
  );
}

'use client';

import { ArrowDownRight, ArrowUpRight, Minus } from 'lucide-react';

import type { MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { useI18n } from '@/i18n';
import { deltaTone, TONE_CHIP, useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

const MINUS = '−';
/** Shu chegaradan kichik o'zgarish — "o'zgarmadi" belgisi. */
const FLAT = 0.05;

/**
 * Jadval katagi uchun ixcham o'zgarish belgisi: birliksiz ("+1,3"), to'liq
 * matn ("+1,3 p.p. — o'tgan yilning shu davriga nisbatan") — `title`da.
 */
export function CompactDelta({ metric, delta, className }: { metric: MetricKey; delta: number | null | undefined; className?: string }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  if (delta === null || delta === undefined) return null;
  const tone = deltaTone(metric, delta);
  const Icon = delta > FLAT ? ArrowUpRight : delta < -FLAT ? ArrowDownRight : Minus;
  const sign = delta > 0 ? '+' : delta < 0 ? MINUS : '±';
  const full = `${fmt.delta(metric, delta)} — ${t('common.vsLastYear')}`;
  return (
    <span
      title={full}
      className={cn(
        'inline-flex h-5 shrink-0 items-center gap-px rounded-full px-1 text-[0.66rem] font-semibold tabular-nums ring-1 ring-inset',
        TONE_CHIP[tone],
        className,
      )}
    >
      <Icon aria-hidden className="h-3 w-3" />
      <span aria-hidden>
        {sign}
        {fmt.num(Math.abs(delta), METRICS[metric].decimals)}
      </span>
      <span className="sr-only">{full}</span>
    </span>
  );
}

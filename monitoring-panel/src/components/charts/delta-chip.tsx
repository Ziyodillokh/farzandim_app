'use client';

import { ArrowDownRight, ArrowUpRight, Minus } from 'lucide-react';

import type { MetricKey } from '@/data/contracts';
import { deltaTone, TONE_CHIP, useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

/** O'zgarish belgisi: yaxshi tomonga — yashil, e'tibor — amber (ko'rsatkich yo'nalishiga qarab). */
export function DeltaChip({ metric, delta, className, title }: { metric: MetricKey; delta: number | null | undefined; className?: string; title?: string }) {
  const fmt = useMetricFormat();
  if (delta === null || delta === undefined) return null;
  const tone = deltaTone(metric, delta);
  const Icon = delta > 0.05 ? ArrowUpRight : delta < -0.05 ? ArrowDownRight : Minus;
  return (
    <span title={title} className={cn('inline-flex h-6 items-center gap-0.5 rounded-full px-2 text-[0.72rem] font-semibold tabular-nums ring-1 ring-inset', TONE_CHIP[tone], className)}>
      <Icon className="h-3.5 w-3.5" />
      {fmt.delta(metric, delta)}
    </span>
  );
}

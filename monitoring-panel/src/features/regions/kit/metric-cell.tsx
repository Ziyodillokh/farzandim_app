'use client';

import type { MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { CompactDelta } from './compact-delta';
import { cellTint, type ColumnStats } from './heat';

/**
 * Jadval katagi: qiymat (ustunga nisbatan bo'yalgan) + ixcham o'zgarish belgisi.
 * `delta` berilmasa — faqat qiymat. Ustunlar bir xil enda — qatorlar tekis turadi.
 */
export function MetricCell({
  metric,
  value,
  delta,
  stats,
  tint = true,
  className,
}: {
  metric: MetricKey;
  value: number | null | undefined;
  /** `undefined` — belgi ustuni umuman yo'q; `null` — joy saqlanadi, belgi ko'rsatilmaydi. */
  delta?: number | null;
  stats?: ColumnStats | null;
  tint?: boolean;
  className?: string;
}) {
  const fmt = useMetricFormat();
  const withDelta = delta !== undefined;
  return (
    <span className={cn('inline-grid items-center gap-1 align-middle', withDelta ? 'grid-cols-[3.9rem_3.2rem]' : 'grid-cols-[3.9rem]', className)}>
      <span
        className="rounded-md px-1.5 py-1 text-center text-[0.8rem] font-semibold tabular-nums"
        style={tint ? cellTint(value, stats ?? null, METRICS[metric].better) : undefined}
      >
        {fmt.value(metric, value)}
      </span>
      {withDelta && (
        <span className="justify-self-start">
          <CompactDelta metric={metric} delta={delta} />
        </span>
      )}
    </span>
  );
}

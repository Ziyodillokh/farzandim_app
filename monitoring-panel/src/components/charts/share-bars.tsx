'use client';

import type { ReactNode } from 'react';

import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

export type ShareRow = { key: string; label: string; share: number; hint?: ReactNode; color?: string; secondary?: number | null };

/**
 * Ulushlar ro'yxati: nom, gorizontal ustun va foiz. `secondary` — ustun ustidagi
 * ingichka belgi (masalan, respublika qiymati).
 */
export function ShareBars({
  rows,
  max,
  className,
  barClassName,
  secondaryLabel,
  decimals = 1,
}: {
  rows: ShareRow[];
  max?: number;
  className?: string;
  barClassName?: string;
  secondaryLabel?: string;
  decimals?: number;
}) {
  const fmt = useMetricFormat();
  const top = max ?? Math.max(1, ...rows.map((r) => Math.max(r.share, r.secondary ?? 0)));
  return (
    <ul className={cn('space-y-2.5', className)}>
      {rows.map((r) => (
        <li key={r.key}>
          <div className="mb-1 flex items-baseline justify-between gap-3 text-[0.8rem]">
            <span className="min-w-0 truncate font-medium">{r.label}</span>
            <span className="shrink-0 font-semibold tabular-nums">{fmt.pct(r.share, decimals)}</span>
          </div>
          <div className="relative h-2 rounded-full bg-muted/70">
            <span
              className={cn('absolute inset-y-0 left-0 rounded-full bg-brand-gradient transition-[width] duration-700', barClassName)}
              style={{ width: `${Math.min(100, (r.share / top) * 100)}%`, ...(r.color ? { background: r.color } : {}) }}
            />
            {r.secondary !== undefined && r.secondary !== null && (
              <span
                title={secondaryLabel}
                className="absolute -top-1 h-4 w-0.5 rounded-full bg-foreground/60"
                style={{ left: `${Math.min(100, (r.secondary / top) * 100)}%` }}
              />
            )}
          </div>
          {r.hint && <div className="mt-1 text-[0.7rem] text-muted-foreground">{r.hint}</div>}
        </li>
      ))}
    </ul>
  );
}

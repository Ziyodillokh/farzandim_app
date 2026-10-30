'use client';

import { useMetricFormat } from '@/lib/format';

/** Son + ingichka nisbiy chiziq (ustun ichidagi eng kattasiga nisbatan) — qayerda ko'pligi bir qarashda. */
export function CountBar({ value, max }: { value: number; max: number }) {
  const fmt = useMetricFormat();
  const pct = max > 0 ? Math.max(2, Math.min(100, (value / max) * 100)) : 0;
  return (
    <span className="inline-flex items-center justify-end gap-2.5">
      <span aria-hidden className="hidden h-1.5 w-16 overflow-hidden rounded-full bg-primary/15 sm:block">
        <span className="block h-full rounded-full bg-brand-gradient" style={{ width: `${pct}%` }} />
      </span>
      <span className="min-w-[3.25rem] text-right font-semibold tabular-nums">{fmt.count(value)}</span>
    </span>
  );
}

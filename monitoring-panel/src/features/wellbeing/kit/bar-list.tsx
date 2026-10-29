'use client';

import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

export type BarRow = { key: string; label: string; value: number | null; color?: string; note?: ReactNode };

/** Minimal ko'rinadigan ustun uzunligi (%) — kichik qiymat ham ko'rinsin. */
const MIN_BAR = 3;

/**
 * Gorizontal taqqoslash ustunlari (o'g'il/qiz bolalar, maktab turlari).
 * `domain` — shkala chegaralari: yaqin ulushlar uchun pastki chegara 0 dan
 * yuqori bo'lishi mumkin; `reference` — ingichka belgi (masalan, o'rtacha).
 */
export function BarList({
  rows,
  format,
  domain,
  reference,
  referenceLabel,
  labelWidth = '7.5rem',
  className,
}: {
  rows: readonly BarRow[];
  format: (v: number | null) => string;
  domain?: [number, number];
  reference?: number | null;
  referenceLabel?: string;
  labelWidth?: string;
  className?: string;
}) {
  const values = rows.map((r) => r.value).filter((v): v is number => v !== null);
  const [lo, hi] = domain ?? [0, Math.max(1, ...values, reference ?? 0) * 1.08];
  const pos = (v: number) => Math.min(100, Math.max(0, ((v - lo) / (hi - lo || 1)) * 100));
  return (
    <ul className={cn('space-y-2', className)}>
      {rows.map((r) => (
        <li key={r.key} className="grid items-center gap-2.5 text-[0.8rem]" style={{ gridTemplateColumns: `minmax(0,${labelWidth}) minmax(0,1fr) auto` }}>
          <span className="truncate text-muted-foreground" title={r.label}>
            {r.label}
          </span>
          <span className="relative h-2.5 rounded-full bg-muted/70">
            {r.value !== null && (
              <span
                className="absolute inset-y-0 left-0 rounded-full bg-brand-gradient transition-[width] duration-700"
                style={{ width: `${Math.max(MIN_BAR, pos(r.value))}%`, ...(r.color ? { background: r.color } : {}) }}
              />
            )}
            {reference !== undefined && reference !== null && (
              <span title={referenceLabel} aria-hidden className="absolute -top-1 h-[18px] w-0.5 rounded-full bg-foreground/55" style={{ left: `${pos(reference)}%` }} />
            )}
          </span>
          <span className="flex items-baseline justify-end gap-1.5 whitespace-nowrap">
            <b className="font-semibold tabular-nums">{format(r.value)}</b>
            {r.note}
          </span>
        </li>
      ))}
    </ul>
  );
}

'use client';

import type { ReactNode } from 'react';

import { heatStyle } from '@/lib/color-scale';
import { cn } from '@/lib/utils';

export type HeatColumn = { key: string; label: string; better?: 'up' | 'down' };
export type HeatRow = { id: string; label: string; values: Record<string, number | null>; extra?: ReactNode };

/**
 * Issiqlik jadvali: har ustun o'z o'rtachasiga nisbatan bo'yaladi (moviy —
 * yaxshiroq, amber — e'tibor). Birinchi ustun yopishqoq, mobil — gorizontal aylantirish.
 */
export function HeatTable({
  columns,
  rows,
  format,
  onRowClick,
  selectedId,
  firstHeader,
  minWidth = 720,
  className,
}: {
  columns: HeatColumn[];
  rows: HeatRow[];
  format: (v: number | null) => string;
  onRowClick?: (id: string) => void;
  selectedId?: string | null;
  firstHeader: string;
  /** Jadvalning eng kichik eni (px) — torroq bo'lsa gorizontal aylantiriladi. */
  minWidth?: number;
  className?: string;
}) {
  const stats = Object.fromEntries(
    columns.map((c) => {
      const vals = rows.map((r) => r.values[c.key]).filter((v): v is number => v !== null && v !== undefined);
      const mean = vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : 0;
      const spread = vals.length ? Math.max(...vals.map((v) => Math.abs(v - mean))) : 1;
      return [c.key, { mean, spread }];
    }),
  ) as Record<string, { mean: number; spread: number }>;

  return (
    <div className={cn('overflow-x-auto rounded-xl ring-1 ring-inset ring-border/50', className)}>
      <table className="w-full border-separate border-spacing-0 text-[0.78rem]" style={{ minWidth }}>
        <thead>
          <tr>
            <th className="sticky left-0 z-10 bg-card/95 px-3 py-2 text-left text-[0.68rem] font-semibold uppercase tracking-[0.08em] text-muted-foreground backdrop-blur">{firstHeader}</th>
            {columns.map((c) => (
              <th key={c.key} className="px-2 py-2 text-center text-[0.68rem] font-semibold text-muted-foreground" title={c.label}>
                <span className="line-clamp-2">{c.label}</span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr
              key={r.id}
              onClick={onRowClick ? () => onRowClick(r.id) : undefined}
              className={cn(onRowClick && 'cursor-pointer', 'group')}
            >
              <th
                scope="row"
                className={cn(
                  'sticky left-0 z-10 whitespace-nowrap border-t border-border/40 bg-card/95 px-3 py-1.5 text-left font-medium backdrop-blur group-hover:text-primary',
                  selectedId === r.id && 'text-primary',
                )}
              >
                {onRowClick ? (
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onRowClick(r.id);
                    }}
                    className="rounded text-left font-medium outline-none hover:text-primary focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    {r.label}
                  </button>
                ) : (
                  r.label
                )}
                {r.extra}
              </th>
              {columns.map((c) => {
                const v = r.values[c.key] ?? null;
                const s = stats[c.key]!;
                return (
                  <td key={c.key} className="border-t border-border/40 px-1 py-1 text-center">
                    <span className="block rounded-md px-1.5 py-1 font-semibold tabular-nums" style={heatStyle(v, s.mean, s.spread, c.better)}>
                      {format(v)}
                    </span>
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

'use client';

import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

export type StackedSegment = { key: string; label: string; color: string };
export type StackedRow = { id: string; label: string; values: Record<string, number> | null; onClick?: () => void };

/** 100% yig'ma gorizontal ustunlar (masalan, IQ darajalari hududlar bo'yicha). */
export function StackedBars({ segments, rows, className }: { segments: StackedSegment[]; rows: StackedRow[]; className?: string }) {
  const fmt = useMetricFormat();
  return (
    <div className={cn('space-y-3', className)}>
      <div className="flex flex-wrap gap-x-4 gap-y-1.5 text-[0.72rem] text-muted-foreground">
        {segments.map((s) => (
          <span key={s.key} className="flex items-center gap-1.5">
            <span className="h-2.5 w-2.5 rounded-sm" style={{ background: s.color }} />
            {s.label}
          </span>
        ))}
      </div>
      <ul className="space-y-1.5">
        {rows.map((r) => {
          const total = r.values ? segments.reduce((sum, s) => sum + (r.values![s.key] ?? 0), 0) || 1 : 1;
          const Row = r.onClick ? 'button' : 'div';
          return (
            <li key={r.id}>
              <Row
                {...(r.onClick ? { type: 'button' as const, onClick: r.onClick } : {})}
                className={cn('grid w-full grid-cols-[minmax(0,9rem)_1fr] items-center gap-3 rounded-lg px-1 py-0.5 text-left text-[0.78rem]', r.onClick && 'hover:bg-primary/[0.06]')}
              >
                <span className="truncate font-medium">{r.label}</span>
                {r.values ? (
                  <span className="flex h-4 overflow-hidden rounded-md ring-1 ring-inset ring-black/5">
                    {segments.map((s) => {
                      const v = r.values![s.key] ?? 0;
                      return (
                        <Tooltip key={s.key}>
                          <TooltipTrigger asChild>
                            <span className="h-full transition-[width] duration-700" style={{ width: `${(v / total) * 100}%`, background: s.color }} />
                          </TooltipTrigger>
                          <TooltipContent className="text-xs">
                            {s.label}: <b>{fmt.pct(v)}</b>
                          </TooltipContent>
                        </Tooltip>
                      );
                    })}
                  </span>
                ) : (
                  <span className="text-[0.72rem] text-muted-foreground">—</span>
                )}
              </Row>
            </li>
          );
        })}
      </ul>
    </div>
  );
}

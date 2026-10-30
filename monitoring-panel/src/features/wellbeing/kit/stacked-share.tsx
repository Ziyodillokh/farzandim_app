'use client';

import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { cn } from '@/lib/utils';

export type ShareSegment = { key: string; label: string; value: number; color: string };
/** Bir nechta segmentni birlashtiruvchi qavs (masalan, "Keldi" = o'z vaqtida + kechikdi + erta ketdi). */
export type SegmentGroup = { key: string; label: string; keys: readonly string[] };

/**
 * 100% yig'ma ustun: segmentlar orasida 2px bo'shliq, har segmentda tooltip,
 * ustida ixtiyoriy guruh qavslari, ostida qiymatli legenda (rang yagona kanal emas).
 */
export function StackedShare({
  segments,
  format,
  groups,
  className,
  legendClassName,
}: {
  segments: readonly ShareSegment[];
  format: (v: number) => string;
  groups?: readonly SegmentGroup[];
  className?: string;
  legendClassName?: string;
}) {
  const total = segments.reduce((sum, s) => sum + Math.max(0, s.value), 0) || 1;
  const share = (v: number) => (Math.max(0, v) / total) * 100;
  let cursor = 0;
  const offsets = new Map(
    segments.map((s) => {
      const start = cursor;
      cursor += share(s.value);
      return [s.key, { start, end: cursor }] as const;
    }),
  );

  return (
    <div className={cn('min-w-0', className)}>
      {groups && groups.length > 0 && (
        <div className="relative mb-2 h-9">
          {groups.map((g) => {
            const parts = g.keys.map((k) => offsets.get(k)).filter((o): o is { start: number; end: number } => Boolean(o));
            if (!parts.length) return null;
            const start = Math.min(...parts.map((p) => p.start));
            const end = Math.max(...parts.map((p) => p.end));
            const value = g.keys.reduce((sum, k) => sum + (segments.find((s) => s.key === k)?.value ?? 0), 0);
            const align = start <= 0.5 ? 'left' : end >= 99.5 ? 'right' : 'center';
            return (
              <div key={g.key} className="absolute bottom-0 h-full" style={{ left: `${start}%`, width: `${Math.max(0.5, end - start)}%` }}>
                <span
                  className={cn(
                    'absolute top-0 whitespace-nowrap text-[0.75rem] text-muted-foreground',
                    align === 'left' && 'left-0',
                    align === 'right' && 'right-0',
                    align === 'center' && 'left-1/2 -translate-x-1/2',
                  )}
                >
                  {g.label} <b className="font-semibold tabular-nums text-foreground">{format(value)}</b>
                </span>
                <span aria-hidden className="absolute inset-x-0 bottom-0 h-2 rounded-t-sm border-x border-t border-foreground/30" />
              </div>
            );
          })}
        </div>
      )}
      <div className="flex h-5 w-full gap-[2px] overflow-hidden rounded-lg" role="img" aria-label={segments.map((s) => `${s.label}: ${format(s.value)}`).join(', ')}>
        {segments.map((s) => (
          <Tooltip key={s.key}>
            <TooltipTrigger asChild>
              <span className="h-full min-w-[3px] transition-[flex-grow] duration-700 hover:brightness-110" style={{ flexGrow: Math.max(0, s.value), flexBasis: 0, background: s.color }} />
            </TooltipTrigger>
            <TooltipContent className="text-xs">
              {s.label}: <b>{format(s.value)}</b>
            </TooltipContent>
          </Tooltip>
        ))}
      </div>
      <ul className={cn('mt-3 flex flex-wrap gap-x-5 gap-y-2 text-[0.78rem]', legendClassName)}>
        {segments.map((s) => (
          <li key={s.key} className="inline-flex items-center gap-1.5">
            <span aria-hidden className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ background: s.color }} />
            <span className="text-muted-foreground">{s.label}</span>
            <b className="font-semibold tabular-nums">{format(s.value)}</b>
          </li>
        ))}
      </ul>
    </div>
  );
}

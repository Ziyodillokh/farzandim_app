'use client';

import type { AreaStat, MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { useAreaName } from '@/lib/area-name';
import { buildScale, scaleColor } from '@/lib/color-scale';
import { deltaTone, TONE_TEXT, useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

/**
 * Hudud/tumanlar reytingi: gorizontal ustunlar, respublika chizig'i, tanlangan
 * qator ajratiladi. Ustun rangi — xarita bilan bir xil shkala.
 */
export function RankBars({
  metric,
  areas,
  center,
  selectedId,
  onSelect,
  limit,
  className,
  showDelta = true,
}: {
  metric: MetricKey;
  areas: AreaStat[];
  center: number | null;
  selectedId?: string | null;
  onSelect?: (id: string) => void;
  limit?: number;
  className?: string;
  showDelta?: boolean;
}) {
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const def = METRICS[metric];
  const sorted = areas
    .filter((a) => a.value !== null)
    .sort((a, b) => (def.better === 'down' ? (a.value as number) - (b.value as number) : (b.value as number) - (a.value as number)));
  const rows = limit ? sorted.slice(0, limit) : sorted;
  const values = sorted.map((a) => a.value as number);
  const max = Math.max(...values, center ?? 0);
  const min = Math.min(...values, center ?? max);
  // Ustun boshlanishi 0 dan emas — farqlar ko'rinsin (minimumdan biroz pastdan).
  const floor = Math.max(0, min - (max - min) * 0.6);
  const width = (v: number) => `${Math.max(4, ((v - floor) / (max - floor || 1)) * 100)}%`;
  const scale = buildScale(values, def.better, center);
  const centerPos = center === null ? null : ((center - floor) / (max - floor || 1)) * 100;

  return (
    <ol className={cn('space-y-1.5', className)}>
      {rows.map((a, i) => {
        const selected = selectedId === a.id;
        const Row = onSelect ? 'button' : 'div';
        return (
          <li key={a.id}>
            <Row
              {...(onSelect ? { type: 'button' as const, onClick: () => onSelect(a.id) } : {})}
              className={cn(
                'group grid w-full grid-cols-[1.5rem_minmax(0,9.5rem)_1fr_auto] items-center gap-2 rounded-lg px-1.5 py-1 text-left text-[0.8rem] transition-colors',
                onSelect && 'hover:bg-primary/[0.06]',
                selected && 'bg-primary/[0.1] ring-1 ring-inset ring-primary/30',
              )}
            >
              <span className="text-center text-[0.7rem] font-semibold tabular-nums text-muted-foreground">{a.rank ?? i + 1}</span>
              <span className="truncate font-medium">{areaName(a.id, { short: true, fallback: a.name })}</span>
              <span className="relative h-2.5 overflow-hidden rounded-full bg-muted/60">
                <span className="absolute inset-y-0 left-0 rounded-full transition-[width] duration-700" style={{ width: width(a.value as number), background: scaleColor(a.value, scale) }} />
                {centerPos !== null && <span className="absolute inset-y-[-2px] w-px bg-foreground/50" style={{ left: `${centerPos}%` }} />}
              </span>
              <span className="flex items-baseline gap-1.5 justify-self-end">
                <span className="font-semibold tabular-nums">{fmt.value(metric, a.value)}</span>
                {showDelta && <span className={cn('w-14 text-right text-[0.68rem] tabular-nums', TONE_TEXT[deltaTone(metric, a.delta)])}>{fmt.delta(metric, a.delta)}</span>}
              </span>
            </Row>
          </li>
        );
      })}
    </ol>
  );
}

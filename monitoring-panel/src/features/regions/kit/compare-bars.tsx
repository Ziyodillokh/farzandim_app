'use client';

import { Trophy } from 'lucide-react';
import { Fragment } from 'react';

import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import type { MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { buildScale, DIVERGING, scaleColor } from '@/lib/color-scale';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { isNum } from './heat';

export type CompareSeries = { id: string; label: string };
export type ComparePoint = { value: number | null; delta?: number | null };
export type CompareRowData = {
  metric: MetricKey;
  values: Readonly<Record<string, ComparePoint | undefined>>;
  /** Taqqoslash markazi: respublika yoki "barcha maktablar" o'rtachasi. */
  reference: number | null;
  /** Shkala va rang konteksti (masalan, 14 hudud qiymatlari) — tanlov o'zgarsa ham shkala barqaror. */
  context: ReadonlyArray<number | null | undefined>;
};

/** Ustun boshi minimumdan oraliqning 60% pastda — eng past qiymat ham ko'rinadi (RankBars bilan bir xil). */
const LO_PAD = 0.6;
const HI_PAD = 0.04;
const MIN_BAR_PCT = 2;

export function barDomain(values: ReadonlyArray<number | null | undefined>): { lo: number; hi: number } {
  const v = values.filter(isNum);
  if (!v.length) return { lo: 0, hi: 1 };
  const min = Math.min(...v);
  const max = Math.max(...v);
  const span = max - min || Math.abs(max) * 0.1 || 1;
  return { lo: Math.max(0, min - span * LO_PAD), hi: max + span * HI_PAD };
}

/** Tanlanganlar orasida eng yaxshi qiymat(lar). Neytral ko'rsatkich yoki hammasi teng — yo'q. */
export function bestIds(series: readonly CompareSeries[], values: CompareRowData['values'], better: 'up' | 'down' | 'neutral'): Set<string> {
  if (better === 'neutral') return new Set();
  const present = series.flatMap((s) => {
    const v = values[s.id]?.value;
    return isNum(v) ? [{ id: s.id, v }] : [];
  });
  if (present.length < 2) return new Set();
  const nums = present.map((p) => p.v);
  const target = better === 'down' ? Math.min(...nums) : Math.max(...nums);
  if (nums.every((n) => n === target)) return new Set();
  return new Set(present.filter((p) => p.v === target).map((p) => p.id));
}

/**
 * Bitta ko'rsatkich bo'yicha yonma-yon ustunlar: har seriya (hudud yoki maktab
 * turi) — o'z qatori va nomi bilan, vertikal chiziq — taqqoslash markazi.
 * Rang — markazga nisbatan (moviy yaxshiroq, amber past), xarita bilan bir xil.
 */
export function CompareMetric({
  row,
  label,
  series,
  referenceText,
  gapText,
  deltaText,
  bestLabel,
  labelWidth = '6.5rem',
}: {
  row: CompareRowData;
  label: string;
  series: readonly CompareSeries[];
  /** Sarlavha yonida: "resp.: 67,2%". */
  referenceText: (formatted: string) => string;
  /** Tooltip: "Respublikaga nisbatan: −2,8 p.p.". */
  gapText: (formatted: string) => string;
  /** Tooltip: "O'tgan yilga nisbatan: +0,9 p.p." (o'zgarish bo'lsa). */
  deltaText?: (formatted: string) => string;
  bestLabel: string;
  labelWidth?: string;
}) {
  const fmt = useMetricFormat();
  const def = METRICS[row.metric];
  const values = series.map((s) => row.values[s.id]?.value ?? null);
  const domain = barDomain([...row.context, ...values, row.reference]);
  const scale = buildScale(
    row.context.map((v) => v ?? null),
    def.better,
    row.reference,
    'diverging',
  );
  const best = bestIds(series, row.values, def.better);
  const pos = (v: number) => Math.min(100, Math.max(0, ((v - domain.lo) / (domain.hi - domain.lo || 1)) * 100));
  const refPos = isNum(row.reference) ? pos(row.reference) : null;

  return (
    <div className="min-w-0">
      <div className="mb-1.5 flex items-baseline justify-between gap-3">
        <p className="min-w-0 truncate text-[0.8rem] font-semibold" title={label}>
          {label}
        </p>
        {isNum(row.reference) && <p className="shrink-0 text-[0.68rem] tabular-nums text-muted-foreground">{referenceText(fmt.value(row.metric, row.reference))}</p>}
      </div>
      <div className="relative grid items-center gap-x-2.5 gap-y-1.5" style={{ gridTemplateColumns: `minmax(0,${labelWidth}) minmax(0,1fr) minmax(4.25rem,auto)` }}>
        {series.map((s, i) => {
          const point = row.values[s.id];
          const v = point?.value ?? null;
          const d = point?.delta;
          const isBest = best.has(s.id);
          const gridRow = i + 1;
          return (
            <Fragment key={s.id}>
              <span className={cn('truncate text-[0.74rem]', isBest ? 'font-semibold text-foreground' : 'text-muted-foreground')} style={{ gridRow, gridColumn: 1 }} title={s.label}>
                {s.label}
              </span>
              <Tooltip>
                <TooltipTrigger asChild>
                  <span className="relative block h-2.5 rounded-full bg-muted/70" style={{ gridRow, gridColumn: 2 }}>
                    {isNum(v) && (
                      <span
                        className="absolute inset-y-0 left-0 rounded-full transition-[width] duration-700"
                        style={{ width: `${Math.max(MIN_BAR_PCT, pos(v))}%`, background: scaleColor(v, scale) }}
                      />
                    )}
                  </span>
                </TooltipTrigger>
                <TooltipContent className="space-y-0.5">
                  <p className="font-semibold">
                    {s.label} · {label}: {fmt.value(row.metric, v)}
                  </p>
                  {isNum(v) && isNum(row.reference) && <p className="text-white/75">{gapText(fmt.delta(row.metric, v - row.reference))}</p>}
                  {deltaText && isNum(d) && <p className="text-white/75">{deltaText(fmt.delta(row.metric, d))}</p>}
                </TooltipContent>
              </Tooltip>
              <span className="flex items-center justify-end gap-1 text-[0.78rem] font-semibold tabular-nums" style={{ gridRow, gridColumn: 3 }}>
                {isBest && (
                  <span title={bestLabel} className="inline-flex">
                    <Trophy aria-hidden className="h-3.5 w-3.5 text-cyan-500 dark:text-cyan-300" />
                    <span className="sr-only">{bestLabel}</span>
                  </span>
                )}
                {fmt.value(row.metric, v)}
              </span>
            </Fragment>
          );
        })}
        {refPos !== null && (
          <span
            aria-hidden
            className="pointer-events-none absolute -bottom-1 -top-1 w-0.5 -translate-x-1/2 rounded-full bg-foreground/60"
            // Absolyut grid elementida `auto` chiziq konteyner chetiga teng — ikkala chiziq aniq ko'rsatiladi.
            style={{ gridColumn: '2 / 3', gridRow: `1 / ${series.length + 1}`, left: `${refPos}%` }}
          />
        )}
      </div>
    </div>
  );
}

/** Ustunlar legendasi: 5 pog'onali rang (past → yuqori), markaz chizig'i, eng yaxshi belgisi. */
export function CompareLegend({
  worse,
  better,
  reference,
  best,
  className,
}: {
  worse: string;
  better: string;
  reference: string;
  best: string;
  className?: string;
}) {
  return (
    <div className={cn('flex flex-wrap items-center gap-x-4 gap-y-1.5 text-[0.7rem] text-muted-foreground', className)}>
      <span className="flex items-center gap-1.5">
        <span>{worse}</span>
        <span aria-hidden className="flex overflow-hidden rounded-full">
          {DIVERGING.map((c) => (
            <span key={c} className="h-2 w-4" style={{ background: c }} />
          ))}
        </span>
        <span>{better}</span>
      </span>
      <span className="flex items-center gap-1.5">
        <span aria-hidden className="h-3.5 w-0.5 rounded-full bg-foreground/60" />
        {reference}
      </span>
      <span className="flex items-center gap-1.5">
        <Trophy aria-hidden className="h-3.5 w-3.5 text-cyan-500 dark:text-cyan-300" />
        {best}
      </span>
    </div>
  );
}

'use client';

import { useId } from 'react';
import { Area, AreaChart, CartesianGrid, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import type { SeriesPoint } from '@/data/contracts';
import { useMonthLabel } from '@/lib/format';
import { ChartTooltip } from './chart-tooltip';

export type TrendSeries = { key: string; label: string; points: SeriesPoint[]; color?: string; dashed?: boolean };

/**
 * Oylik trend (oxirgi 12 o'quv oyi). Bir yoki bir nechta qator; ixtiyoriy
 * mos yozuv chizig'i (masalan, respublika o'rtachasi).
 */
export function TrendChart({
  series,
  format,
  height = 220,
  reference,
  referenceLabel,
  domain,
  axisFormat,
  axisWidth = 52,
}: {
  series: TrendSeries[];
  format: (v: number) => string;
  /** O'q yozuvlari uchun qisqa format (standart — `format`), masalan "220" o'rniga "220 daq". */
  axisFormat?: (v: number) => string;
  axisWidth?: number;
  height?: number;
  reference?: number | null;
  referenceLabel?: string;
  domain?: [number | 'auto' | 'dataMin', number | 'auto' | 'dataMax'];
}) {
  const id = useId().replace(/:/g, '');
  const monthLabel = useMonthLabel();
  const keys = series[0]?.points.map((p) => p.key) ?? [];
  const data = keys.map((k, i) => ({
    key: k,
    ...Object.fromEntries(series.map((s) => [s.key, s.points[i]?.value ?? null])),
  }));
  const colors = ['hsl(var(--chart-1))', 'hsl(var(--chart-5))', 'hsl(var(--chart-2))', 'hsl(var(--chart-3))'];
  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -12 }}>
          <defs>
            {series.map((s, i) => (
              <linearGradient key={s.key} id={`tr-${id}-${i}`} x1="0" x2="0" y1="0" y2="1">
                <stop offset="0%" stopColor={s.color ?? colors[i % colors.length]} stopOpacity={0.35} />
                <stop offset="100%" stopColor={s.color ?? colors[i % colors.length]} stopOpacity={0} />
              </linearGradient>
            ))}
          </defs>
          <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="3 4" vertical={false} />
          <XAxis dataKey="key" tickFormatter={(k: string) => monthLabel(k)} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} interval="preserveStartEnd" minTickGap={8} />
          <YAxis domain={domain ?? ['auto', 'auto']} tickFormatter={(v: number) => (axisFormat ?? format)(v)} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} width={axisWidth} />
          <Tooltip
            cursor={{ stroke: 'hsl(var(--primary))', strokeOpacity: 0.3 }}
            content={<ChartTooltip formatLabel={(k) => monthLabel(k, true)} formatValue={(v) => format(v)} />}
          />
          {reference !== undefined && reference !== null && (
            <ReferenceLine y={reference} ifOverflow="extendDomain" stroke="hsl(var(--muted-foreground))" strokeDasharray="4 4" label={referenceLabel ? { value: referenceLabel, position: 'insideTopRight', fontSize: 10, fill: 'hsl(var(--muted-foreground))' } : undefined} />
          )}
          {series.map((s, i) => (
            <Area
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.label}
              stroke={s.color ?? colors[i % colors.length]}
              strokeWidth={2.2}
              strokeDasharray={s.dashed ? '5 4' : undefined}
              fill={s.dashed ? 'none' : `url(#tr-${id}-${i})`}
              connectNulls
              isAnimationActive={false}
              dot={false}
              activeDot={{ r: 4 }}
            />
          ))}
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

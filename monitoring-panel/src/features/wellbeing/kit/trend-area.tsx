'use client';

import { useId } from 'react';
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { ChartTooltip } from '@/components/charts/chart-tooltip';
import type { SeriesPoint } from '@/data/contracts';
import { useMonthLabel } from '@/lib/format';
import type { NiceScale } from './analysis';

export type TrendLine = { key: string; label: string; points: SeriesPoint[]; color: string; dashed?: boolean };

const TICK = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' } as const;

/**
 * Oylik trend (TrendChart'ning mahalliy varianti): o'q belgilari va tooltip
 * formati alohida — "220 daq" kabi uzun belgilar o'qqa sig'adi, shkala
 * `niceScale` belgilari bilan aniq.
 */
export function TrendArea({
  lines,
  format,
  axisFormat,
  scale,
  height = 220,
}: {
  lines: readonly TrendLine[];
  format: (v: number) => string;
  axisFormat: (v: number) => string;
  scale: NiceScale | null;
  height?: number;
}) {
  const id = useId().replace(/:/g, '');
  const monthLabel = useMonthLabel();
  const keys = lines[0]?.points.map((p) => p.key) ?? [];
  const data = keys.map((key, i) => ({ key, ...Object.fromEntries(lines.map((l) => [l.key, l.points[i]?.value ?? null])) }));
  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -4 }}>
          <defs>
            {lines.map((l) => (
              <linearGradient key={l.key} id={`ta-${id}-${l.key}`} x1="0" x2="0" y1="0" y2="1">
                <stop offset="0%" stopColor={l.color} stopOpacity={0.3} />
                <stop offset="100%" stopColor={l.color} stopOpacity={0} />
              </linearGradient>
            ))}
          </defs>
          <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="3 4" vertical={false} />
          <XAxis dataKey="key" tickFormatter={(k: string) => monthLabel(k)} tick={TICK} axisLine={false} tickLine={false} interval="preserveStartEnd" minTickGap={8} />
          <YAxis
            domain={scale?.domain ?? ['auto', 'auto']}
            ticks={scale?.ticks}
            allowDataOverflow={Boolean(scale)}
            tickFormatter={(v: number) => axisFormat(v)}
            tick={TICK}
            axisLine={false}
            tickLine={false}
            width={44}
          />
          <Tooltip
            cursor={{ stroke: 'hsl(var(--primary))', strokeOpacity: 0.3 }}
            content={<ChartTooltip formatLabel={(k) => monthLabel(k, true)} formatValue={(v) => format(v)} />}
          />
          {lines.map((l) => (
            <Area
              key={l.key}
              type="monotone"
              dataKey={l.key}
              name={l.label}
              stroke={l.color}
              strokeWidth={2}
              strokeDasharray={l.dashed ? '5 4' : undefined}
              fill={l.dashed ? 'none' : `url(#ta-${id}-${l.key})`}
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

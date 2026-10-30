'use client';

import { useId } from 'react';
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { ChartTooltip } from '@/components/charts/chart-tooltip';
import type { SeriesPoint } from '@/data/contracts';
import { useMonthLabel } from '@/lib/format';
import type { NiceScale } from './analysis';
import { AxisUnit } from './chart-block';

export type TrendLine = { key: string; label: string; points: SeriesPoint[]; color: string; dashed?: boolean };

const TICK = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' } as const;
const AXIS_WIDTH = 44;
const MARGIN_LEFT = -4;
/** Diagramma tepasidagi bo'shliq; birlik ko'rsatilsa — uning belgisi uchun ham joy (MiniColumns bilan bir xil). */
const TOP = 8;
const TOP_WITH_UNIT = 20;

/**
 * Oylik trend (TrendChart'ning mahalliy varianti): o'q belgilari va tooltip
 * formati alohida, shkala `niceScale` belgilari bilan aniq; `unit` — o'q
 * belgilari birliksiz bo'lsa (daqiqa), birlik o'q ustida yoziladi.
 */
export function TrendArea({
  lines,
  format,
  axisFormat,
  scale,
  unit,
  height = 220,
}: {
  lines: readonly TrendLine[];
  format: (v: number) => string;
  axisFormat: (v: number) => string;
  scale: NiceScale | null;
  unit?: string;
  height?: number;
}) {
  const id = useId().replace(/:/g, '');
  const monthLabel = useMonthLabel();
  const keys = lines[0]?.points.map((p) => p.key) ?? [];
  const data = keys.map((key, i) => ({ key, ...Object.fromEntries(lines.map((l) => [l.key, l.points[i]?.value ?? null])) }));
  return (
    <div style={{ height }} className="relative w-full">
      {unit && <AxisUnit unit={unit} axisWidth={AXIS_WIDTH} marginLeft={MARGIN_LEFT} />}
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: unit ? TOP_WITH_UNIT : TOP, right: 8, bottom: 0, left: MARGIN_LEFT }}>
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
            width={AXIS_WIDTH}
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

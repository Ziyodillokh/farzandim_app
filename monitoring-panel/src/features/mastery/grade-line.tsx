'use client';

import { useId } from 'react';
import { Area, AreaChart, CartesianGrid, LabelList, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { ChartTooltip } from '@/components/charts/chart-tooltip';
import { pctScale } from './kit/num';

export type GradePoint = { key: string; label: string; value: number | null };

const AXIS_TICK = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' };
const LINE_COLOR = 'hsl(var(--chart-1))';

/** Yorliq faqat tanlangan nuqtalarda (birinchi, oxirgi, eng yuqori, eng past) — qolgani tooltipda. */
function labelIndexes(points: readonly GradePoint[]): Set<number> {
  const idx = points.map((p, i) => ({ v: p.value, i })).filter((p): p is { v: number; i: number } => p.v !== null);
  if (idx.length === 0) return new Set();
  const byValue = [...idx].sort((a, b) => a.v - b.v);
  return new Set([idx[0].i, idx[idx.length - 1].i, byValue[0].i, byValue[byValue.length - 1].i]);
}

type LabelProps = { x?: number | string; y?: number | string; value?: number | string | null; index?: number };

/** Recharts LabelList uchun: faqat tanlangan nuqtalarda qiymat yozuvi. */
function selectiveLabel(show: Set<number>, format: (v: number) => string) {
  function GradeValueLabel(props: unknown) {
    const { x, y, value, index } = props as LabelProps;
    if (index === undefined || !show.has(index) || typeof value !== 'number') return null;
    return (
      <text x={Number(x)} y={Number(y) - 10} textAnchor="middle" className="fill-foreground text-[10.5px] font-semibold">
        {format(value)}
      </text>
    );
  }
  return GradeValueLabel;
}

/**
 * Sinflar bo'yicha chiziqli grafik (tartibli toifalar): nuqtalar, tanlangan
 * yorliqlar va o'rtacha chizig'i. Dashboard trend grafigi uslubida. Qiymatlar —
 * foiz (o'q 100% dan oshmaydi).
 */
export function GradeLine({
  points,
  name,
  format,
  tickFormat,
  formatLabel,
  reference = null,
  height = 240,
}: {
  points: GradePoint[];
  name: string;
  format: (v: number) => string;
  tickFormat: (v: number) => string;
  formatLabel: (label: string) => string;
  reference?: number | null;
  height?: number;
}) {
  const id = useId().replace(/:/g, '');
  const show = labelIndexes(points);
  const scale = pctScale([...points.map((p) => p.value), reference]);
  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={points} margin={{ top: 22, right: 14, bottom: 0, left: -12 }}>
          <defs>
            <linearGradient id={`gl-${id}`} x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stopColor={LINE_COLOR} stopOpacity={0.3} />
              <stop offset="100%" stopColor={LINE_COLOR} stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="3 4" vertical={false} />
          <XAxis dataKey="label" tick={AXIS_TICK} axisLine={false} tickLine={false} interval={0} padding={{ left: 10, right: 10 }} />
          <YAxis domain={scale?.domain ?? ['auto', 'auto']} ticks={scale?.ticks} tickFormatter={tickFormat} tick={AXIS_TICK} axisLine={false} tickLine={false} width={48} interval={0} />
          <Tooltip cursor={{ stroke: 'hsl(var(--primary))', strokeOpacity: 0.3 }} content={<ChartTooltip formatLabel={formatLabel} formatValue={(v) => format(v)} />} />
          {reference !== null && <ReferenceLine y={reference} stroke="hsl(var(--muted-foreground))" strokeDasharray="4 4" strokeOpacity={0.7} />}
          <Area
            type="monotone"
            dataKey="value"
            name={name}
            stroke={LINE_COLOR}
            strokeWidth={2.2}
            fill={`url(#gl-${id})`}
            connectNulls
            isAnimationActive={false}
            dot={{ r: 4, fill: LINE_COLOR, stroke: 'hsl(var(--card))', strokeWidth: 2 }}
            activeDot={{ r: 5 }}
          >
            <LabelList dataKey="value" content={selectiveLabel(show, format)} />
          </Area>
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

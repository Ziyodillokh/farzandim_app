'use client';

import { Bar, BarChart, CartesianGrid, Cell, LabelList, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { ChartTooltip } from './chart-tooltip';

export type ColumnDatum = { key: string; label: string; value: number | null; highlight?: boolean };

/** Vertikal ustunlar (sinflar, hafta kunlari...) — qiymat yorlig'i bilan. */
export function Columns({
  data,
  format,
  height = 220,
  name,
  reference,
  color = 'hsl(var(--chart-1))',
  domain,
}: {
  data: ColumnDatum[];
  format: (v: number) => string;
  height?: number;
  name: string;
  reference?: number | null;
  color?: string;
  domain?: [number | 'auto' | 'dataMin', number | 'auto' | 'dataMax'];
}) {
  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 20, right: 6, bottom: 0, left: -12 }}>
          <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="3 4" vertical={false} />
          <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} interval={0} />
          <YAxis domain={domain ?? [0, 'auto']} tickFormatter={(v: number) => format(v)} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} width={48} />
          <Tooltip cursor={{ fill: 'hsl(var(--primary) / 0.06)' }} content={<ChartTooltip formatValue={(v) => format(v)} />} />
          {reference !== undefined && reference !== null && <ReferenceLine y={reference} stroke="hsl(var(--muted-foreground))" strokeDasharray="4 4" />}
          <Bar dataKey="value" name={name} radius={[6, 6, 2, 2]} isAnimationActive={false} maxBarSize={38}>
            {data.map((d) => (
              <Cell key={d.key} fill={d.highlight ? 'hsl(var(--chart-5))' : color} />
            ))}
            <LabelList dataKey="value" position="top" formatter={(v: number | null) => (v === null || v === undefined ? '' : format(v))} style={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

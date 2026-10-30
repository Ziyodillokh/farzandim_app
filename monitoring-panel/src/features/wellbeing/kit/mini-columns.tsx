'use client';

import { Bar, BarChart, CartesianGrid, Cell, LabelList, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { ChartTooltip } from '@/components/charts/chart-tooltip';
import type { NiceScale } from './analysis';
import { AxisUnit } from './chart-block';

export type MiniColumn = { key: string; label: string; value: number | null; tooltipLabel?: string };

const BASE_COLOR = 'hsl(var(--chart-1))';
/** Ajratilgan ustun (e'tibor talab qiladigan chekka qiymat) — amber, qizil emas. */
export const ACCENT_COLOR = 'hsl(36 92% 56%)';
const TICK = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' } as const;
const AXIS_WIDTH = 44;
const MARGIN_LEFT = -6;
const LABEL_HALO = { paintOrder: 'stroke', stroke: 'hsl(var(--card))', strokeWidth: 3, strokeLinejoin: 'round' } as const;

/** O'q belgisi: butun qiymatda ",0" tashlab yuboriladi ("20,0%" → "20%"). */
export const trimZeroDecimals = (text: string) => text.replace(/[,.]0+(?=\D*$)/, '');

type LabelProps = { x?: number | string; y?: number | string; width?: number | string; index?: number; value?: number | string | null };

/** Ajratilgan ketma-ket ustunlar guruhidan bittasi (o'rtadagisi) yorliq oladi — yorliqlar to'qnashmaydi. */
function runCenters(data: readonly MiniColumn[], highlight: ReadonlySet<string> | undefined): Set<number> {
  const out = new Set<number>();
  if (!highlight?.size) return out;
  let start = -1;
  data.forEach((d, i) => {
    const on = highlight.has(d.key);
    if (on && start < 0) start = i;
    const last = i === data.length - 1;
    if (start >= 0 && (!on || last)) {
      const end = on && last ? i : i - 1;
      out.add(Math.floor((start + end) / 2));
      start = -1;
    }
  });
  return out;
}

/**
 * Ixcham ustunli diagramma (kichik ko'paytmalar: sinflar, hafta kunlari).
 * Qiymat yorlig'i faqat ajratilgan guruhda (yoki `labels="all"`) — har ustunga
 * raqam yozilmaydi; qolgani tooltip va o'qda.
 */
export function MiniColumns({
  data,
  name,
  format,
  axisFormat,
  scale,
  unit,
  reference,
  highlight,
  labels = 'highlight',
  color = BASE_COLOR,
  height = 190,
}: {
  data: readonly MiniColumn[];
  name: string;
  format: (v: number) => string;
  axisFormat?: (v: number) => string;
  /**
   * O'q shkalasi (`metricScale`) — bo'lmasa 0 dan avtomatik. Ustun uzunligi
   * qiymatni bildiradi: odatda `zero: true`; o'q kesilsa — buni ko'rinadigan izoh bilan ayting.
   */
  scale?: NiceScale | null;
  /** O'q belgilari birliksiz bo'lsa (daqiqa) — birlik o'q ustida. */
  unit?: string;
  reference?: number | null;
  highlight?: ReadonlySet<string>;
  labels?: 'highlight' | 'all' | 'none';
  color?: string;
  height?: number;
}) {
  const tooltipLabels = new Map(data.map((d) => [d.label, d.tooltipLabel ?? d.label]));
  const centers = runCenters(data, highlight);
  const showLabel = (index: number | undefined) => {
    if (labels === 'none' || index === undefined) return false;
    return labels === 'all' || centers.has(index);
  };
  const renderLabel = (props: LabelProps) => {
    const { x, y, width, index, value } = props;
    if (!showLabel(index) || value === null || value === undefined) return null;
    // Chekka ustunlarda yorliq diagramma chegarasidan chiqmasin.
    const edge = index === data.length - 1 ? 'end' : index === 0 ? 'start' : 'middle';
    const left = Number(x);
    const w = Number(width);
    const tx = edge === 'end' ? left + w : edge === 'start' ? left : left + w / 2;
    // Fon rangidagi "halo" — yorliq shtrix chiziq yoki to'r ustiga tushsa ham o'qiladi.
    return (
      <text x={tx} y={Number(y) - 6} textAnchor={edge} className="fill-foreground text-[10.5px] font-semibold" style={LABEL_HALO}>
        {format(Number(value))}
      </text>
    );
  };
  return (
    <div style={{ height }} className="relative w-full">
      {unit && <AxisUnit unit={unit} axisWidth={AXIS_WIDTH} marginLeft={MARGIN_LEFT} />}
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={[...data]} margin={{ top: 20, right: 4, bottom: 0, left: MARGIN_LEFT }}>
          <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="3 4" vertical={false} />
          <XAxis dataKey="label" tick={TICK} axisLine={false} tickLine={false} interval={0} />
          <YAxis
            domain={scale?.domain ?? [0, 'auto']}
            ticks={scale?.ticks}
            allowDataOverflow
            tickFormatter={(v: number) => (axisFormat ? axisFormat(v) : trimZeroDecimals(format(v)))}
            tick={TICK}
            axisLine={false}
            tickLine={false}
            width={AXIS_WIDTH}
          />
          <Tooltip cursor={{ fill: 'hsl(var(--primary) / 0.06)' }} content={<ChartTooltip formatLabel={(l) => tooltipLabels.get(l) ?? l} formatValue={(v) => format(v)} />} />
          {reference !== undefined && reference !== null && <ReferenceLine y={reference} stroke="hsl(var(--muted-foreground))" strokeDasharray="4 4" />}
          <Bar dataKey="value" name={name} radius={[4, 4, 0, 0]} maxBarSize={24} isAnimationActive={false}>
            {data.map((d) => (
              <Cell key={d.key} fill={highlight?.has(d.key) ? ACCENT_COLOR : color} />
            ))}
            <LabelList dataKey="value" content={renderLabel} />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

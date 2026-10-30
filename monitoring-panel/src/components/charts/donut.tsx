'use client';

import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

export const DONUT_COLORS = [
  'hsl(214 92% 58%)',
  'hsl(190 90% 50%)',
  'hsl(160 64% 46%)',
  'hsl(40 92% 58%)',
  'hsl(205 70% 72%)',
  'hsl(225 60% 66%)',
  'hsl(28 90% 60%)',
  'hsl(220 18% 58%)',
] as const;

export type DonutSlice = { key: string; label: string; value: number; color?: string };

/** Halqa diagramma (SVG) + legenda. Markazda — ixtiyoriy sarlavha. */
export function Donut({
  slices,
  centerLabel,
  centerValue,
  size = 168,
  thickness = 22,
  className,
}: {
  slices: DonutSlice[];
  centerLabel?: string;
  centerValue?: string;
  size?: number;
  thickness?: number;
  className?: string;
}) {
  const fmt = useMetricFormat();
  const total = slices.reduce((s, x) => s + Math.max(0, x.value), 0) || 1;
  const r = (size - thickness) / 2;
  const c = 2 * Math.PI * r;
  // Markaziy qiymat halqa ichiga sig'sin: uzun matn ("169 daq") kichikroq shriftda.
  const hole = size - thickness * 2;
  const valuePx = centerValue ? Math.min(22, (hole * 0.8) / (centerValue.length * 0.66)) : 22;
  let offset = 0;
  return (
    <div className={cn('flex flex-wrap items-center gap-5', className)}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="shrink-0" role="img" aria-label={centerLabel}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="hsl(var(--muted))" strokeWidth={thickness} />
        {slices.map((s, i) => {
          const len = (Math.max(0, s.value) / total) * c;
          const el = (
            <circle
              key={s.key}
              cx={size / 2}
              cy={size / 2}
              r={r}
              fill="none"
              stroke={s.color ?? DONUT_COLORS[i % DONUT_COLORS.length]}
              strokeWidth={thickness}
              strokeDasharray={`${Math.max(0, len - 2)} ${c}`}
              strokeDashoffset={-offset}
              transform={`rotate(-90 ${size / 2} ${size / 2})`}
              className="transition-[stroke-dasharray] duration-700"
            />
          );
          offset += len;
          return el;
        })}
        {(centerValue || centerLabel) && (
          <g>
            {centerValue && (
              <text x="50%" y="48%" textAnchor="middle" className="fill-foreground font-display font-semibold" style={{ fontSize: valuePx }}>
                {centerValue}
              </text>
            )}
            {centerLabel && (
              <text x="50%" y="62%" textAnchor="middle" className="fill-muted-foreground text-[0.62rem]">
                {centerLabel}
              </text>
            )}
          </g>
        )}
      </svg>
      <ul className="min-w-[10rem] flex-1 space-y-1.5 text-[0.8rem]">
        {slices.map((s, i) => (
          <li key={s.key} className="flex items-center justify-between gap-3">
            <span className="flex min-w-0 items-center gap-2">
              <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: s.color ?? DONUT_COLORS[i % DONUT_COLORS.length] }} />
              <span className="truncate">{s.label}</span>
            </span>
            <span className="font-semibold tabular-nums">{fmt.pct((s.value / total) * 100)}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

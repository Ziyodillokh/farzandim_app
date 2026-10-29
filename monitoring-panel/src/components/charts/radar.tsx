'use client';

import { cn } from '@/lib/utils';

export type RadarAxis = { key: string; label: string };
export type RadarSeries = { key: string; label: string; values: Record<string, number | null>; color: string; dashed?: boolean };

/** Radar (o'rgimchak to'ri) diagramma — 0..max shkala, kutubxonasiz SVG. */
export function Radar({
  axes,
  series,
  max = 100,
  size = 300,
  className,
}: {
  axes: RadarAxis[];
  series: RadarSeries[];
  max?: number;
  size?: number;
  className?: string;
}) {
  const cx = size / 2;
  const cy = size / 2;
  const R = size / 2 - 32;
  const angle = (i: number) => (Math.PI * 2 * i) / axes.length - Math.PI / 2;
  const point = (i: number, v: number) => [cx + Math.cos(angle(i)) * R * (v / max), cy + Math.sin(angle(i)) * R * (v / max)] as const;
  const rings = [0.25, 0.5, 0.75, 1];
  // Uzun yorliqlar ("Tadqiqotchi", "Tashabbuskor") kesilmasin: yon joy eng uzun yorliq
  // eniga qarab (12.5px shriftda ~7px/belgi) — yorliq markazdan R·1.13 masofada boshlanadi.
  const longest = Math.max(0, ...axes.map((a) => a.label.length));
  const padX = Math.max(16, Math.ceil(R * 1.13 + longest * 7 + 6 - size / 2));
  return (
    <div className={cn('flex flex-col items-center gap-3', className)}>
      <svg viewBox={`${-padX} 0 ${size + padX * 2} ${size}`} className="h-auto w-full max-w-[400px]" role="img">
        {rings.map((r) => (
          <polygon
            key={r}
            points={axes.map((_, i) => point(i, max * r).join(',')).join(' ')}
            fill="none"
            stroke="hsl(var(--border))"
            strokeWidth="1"
          />
        ))}
        {axes.map((a, i) => {
          const [x, y] = point(i, max);
          const [lx, ly] = point(i, max * 1.13);
          return (
            <g key={a.key}>
              <line x1={cx} y1={cy} x2={x} y2={y} stroke="hsl(var(--border))" strokeWidth="1" />
              <text x={lx} y={ly} textAnchor={Math.abs(lx - cx) < 8 ? 'middle' : lx > cx ? 'start' : 'end'} dominantBaseline="middle" className="fill-muted-foreground text-[12.5px] font-medium">
                {a.label}
              </text>
            </g>
          );
        })}
        {series.map((s) => (
          <polygon
            key={s.key}
            points={axes.map((a, i) => point(i, s.values[a.key] ?? 0).join(',')).join(' ')}
            fill={s.dashed ? 'none' : s.color}
            fillOpacity={s.dashed ? 0 : 0.18}
            stroke={s.color}
            strokeWidth="2"
            strokeDasharray={s.dashed ? '5 4' : undefined}
            strokeLinejoin="round"
          />
        ))}
      </svg>
      {series.length > 1 && (
        <div className="flex flex-wrap justify-center gap-3 text-[0.72rem] text-muted-foreground">
          {series.map((s) => (
            <span key={s.key} className="flex items-center gap-1.5">
              <span className="h-0.5 w-4 rounded" style={{ background: s.color, opacity: s.dashed ? 0.7 : 1 }} />
              {s.label}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}

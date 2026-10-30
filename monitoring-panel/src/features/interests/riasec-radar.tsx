'use client';

import { cn } from '@/lib/utils';
import { openPath, type RadarPoint } from './radar-path';

export type RadarAxis = { key: string; label: string };
export type RadarSeries = { key: string; label: string; values: Record<string, number | null>; color: string; dashed?: boolean };

/** 12.5px yorliqning taxminiy belgi eni (SVG birligida, kirill harflari kengroq). */
const CHAR_WIDTH = 7.4;
/** Yon yorliqlar langari markazdan R × 1,13 × cos 30° uzoqlikda. */
const SIDE_REACH = 1.13 * Math.cos(Math.PI / 6);
const MIN_PAD = 40;
const RINGS = [0.25, 0.5, 0.75, 1];
const VERTEX_RADIUS = 3;

function SeriesShape({ series, vertices }: { series: RadarSeries; vertices: ReadonlyArray<RadarPoint | null> }) {
  const stroke = { stroke: series.color, strokeWidth: 2, strokeDasharray: series.dashed ? '5 4' : undefined, strokeLinejoin: 'round' as const };
  if (vertices.every((v) => v !== null)) {
    return <polygon points={vertices.map((v) => (v as RadarPoint).join(',')).join(' ')} fill={series.dashed ? 'none' : series.color} fillOpacity={series.dashed ? 0 : 0.18} {...stroke} />;
  }
  return (
    <g>
      <path d={openPath(vertices)} fill="none" {...stroke} />
      {vertices.map((v, i) => v && <circle key={i} cx={v[0]} cy={v[1]} r={VERTEX_RADIUS} fill={series.color} />)}
    </g>
  );
}

/**
 * Radar diagramma (umumiy `Radar` bilan bir xil ko'rinish). Farqi: yon tomon
 * bo'shlig'i eng uzun yorliqqa qarab hisoblanadi — "Tashabbuskor",
 * "Исследовательский" kabi nomlar kesilmaydi; qiymatsiz o'q 0 deb chizilmaydi.
 */
export function RiasecRadar({ axes, series, max = 100, size = 300, className }: { axes: RadarAxis[]; series: RadarSeries[]; max?: number; size?: number; className?: string }) {
  const cx = size / 2;
  const cy = size / 2;
  const R = size / 2 - 32;
  const longest = Math.max(0, ...axes.map((a) => a.label.length)) * CHAR_WIDTH;
  const padX = Math.max(MIN_PAD, longest - (cx - SIDE_REACH * R) + 8);
  const angle = (i: number) => (Math.PI * 2 * i) / axes.length - Math.PI / 2;
  const point = (i: number, v: number): RadarPoint => [cx + Math.cos(angle(i)) * R * (v / max), cy + Math.sin(angle(i)) * R * (v / max)];
  const verticesOf = (s: RadarSeries) =>
    axes.map((a, i) => {
      const v = s.values[a.key];
      return v === null || v === undefined || !Number.isFinite(v) ? null : point(i, v);
    });
  return (
    <div className={cn('flex flex-col items-center gap-3', className)}>
      <svg viewBox={`${-padX} 0 ${size + padX * 2} ${size}`} className="h-auto w-full max-w-[460px]" role="img" aria-label={series.map((s) => s.label).join(' · ')}>
        {RINGS.map((r) => (
          <polygon key={r} points={axes.map((_, i) => point(i, max * r).join(',')).join(' ')} fill="none" stroke="hsl(var(--border))" strokeWidth="1" />
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
          <SeriesShape key={s.key} series={s} vertices={verticesOf(s)} />
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

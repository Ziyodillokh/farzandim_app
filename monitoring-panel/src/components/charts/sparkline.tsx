import { useId } from 'react';

import type { SeriesPoint } from '@/data/contracts';
import { cn } from '@/lib/utils';

/** Kichik trend chizig'i (KPI kartalari uchun), kutubxonasiz SVG. */
export function Sparkline({
  series,
  color = 'hsl(var(--primary))',
  height = 36,
  className,
}: {
  series: SeriesPoint[];
  color?: string;
  height?: number;
  className?: string;
}) {
  const id = useId().replace(/:/g, '');
  const values = series.map((p) => p.value);
  const valid = values.filter((v): v is number => v !== null);
  if (valid.length < 2) return <div style={{ height }} className={className} />;
  const min = Math.min(...valid);
  const max = Math.max(...valid);
  const span = max - min || 1;
  const w = 120;
  const pts = values.map((v, i) => [(i / (values.length - 1)) * w, v === null ? null : height - 4 - ((v - min) / span) * (height - 8)] as const);
  const line = pts.filter(([, y]) => y !== null).map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${(y as number).toFixed(1)}`).join(' ');
  const firstX = pts.find(([, y]) => y !== null)?.[0] ?? 0;
  const lastX = [...pts].reverse().find(([, y]) => y !== null)?.[0] ?? w;
  const lastY = [...pts].reverse().find(([, y]) => y !== null)?.[1] ?? 0;
  return (
    <svg viewBox={`0 0 ${w} ${height}`} preserveAspectRatio="none" className={cn('h-9 w-full overflow-visible', className)} aria-hidden>
      <defs>
        <linearGradient id={`sp-${id}`} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.32" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={`${line} L${lastX},${height} L${firstX},${height} Z`} fill={`url(#sp-${id})`} />
      <path d={line} fill="none" stroke={color} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
      <circle cx={lastX} cy={lastY as number} r="2.6" fill={color} />
    </svg>
  );
}

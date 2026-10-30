import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

/** Bo'lim ichidagi kichik sarlavha (dashboard uslubi: katta harf, keng oraliq). */
export function BlockTitle({ children, className }: { children: ReactNode; className?: string }) {
  return <p className={cn('text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground', className)}>{children}</p>;
}

/**
 * Diagramma bloki: sarlavha, ixtiyoriy o'ng tomondagi element (legenda), diagramma
 * va pastdagi qisqa xulosa ("Eng yuqori: …") — 30 soniyada o'qish uchun.
 */
export function ChartBlock({
  title,
  aside,
  caption,
  children,
  className,
}: {
  title: ReactNode;
  aside?: ReactNode;
  caption?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <figure className={cn('min-w-0', className)}>
      <figcaption className="mb-2 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1.5">
        <BlockTitle>{title}</BlockTitle>
        {aside}
      </figcaption>
      {children}
      {caption && <p className="mt-2 text-[0.75rem] leading-snug text-muted-foreground">{caption}</p>}
    </figure>
  );
}

/** Recharts Y o'qi belgisi o'q chetidan shuncha ichkarida: tickSize (6) + tickMargin (2). */
const AXIS_TICK_INSET = 8;

/**
 * Y o'qi birligi ("daq") — o'q belgilari ustida, ular bilan o'ngdan tekislangan.
 * Ota element `relative` bo'lishi, diagramma esa tepasida kamida 20px joy qoldirishi
 * kerak (yuqori belgi shu chiziqda; birlik undan biroz yuqorida — `-top-1`).
 */
export function AxisUnit({ unit, axisWidth, marginLeft }: { unit: string; axisWidth: number; marginLeft: number }) {
  return (
    <span
      className="pointer-events-none absolute -top-1 left-0 whitespace-nowrap text-right text-[11px] leading-none text-muted-foreground"
      style={{ width: axisWidth + marginLeft - AXIS_TICK_INSET }}
    >
      {unit}
    </span>
  );
}

export type LegendItem = { key: string; label: string; color: string; shape?: 'dot' | 'line' | 'dash'; value?: string };

/** Legenda: belgi (nuqta yoki chiziq) + matn; matn rangi — doim neytral. */
export function ChartLegend({ items, className }: { items: readonly LegendItem[]; className?: string }) {
  return (
    <ul className={cn('flex flex-wrap items-center gap-x-4 gap-y-1.5 text-[0.72rem] text-muted-foreground', className)}>
      {items.map((item) => (
        <li key={item.key} className="flex items-center gap-1.5">
          {item.shape === 'line' || item.shape === 'dash' ? (
            <span
              aria-hidden
              className="h-0 w-4 border-t-2"
              style={{ borderColor: item.color, borderStyle: item.shape === 'dash' ? 'dashed' : 'solid' }}
            />
          ) : (
            <span aria-hidden className="h-2.5 w-2.5 rounded-sm" style={{ background: item.color }} />
          )}
          <span>{item.label}</span>
          {item.value && <b className="font-semibold tabular-nums text-foreground">{item.value}</b>}
        </li>
      ))}
    </ul>
  );
}

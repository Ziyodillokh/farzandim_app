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

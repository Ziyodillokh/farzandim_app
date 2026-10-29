'use client';

import type { MouseEvent, ReactNode } from 'react';

import { cn } from '@/lib/utils';
import { ariaSort, SortButton, type SortState } from './sort';

export type KitColumn<T> = {
  key: string;
  header: ReactNode;
  /** Sarlavha ostidagi kichik izoh (masalan, "monitoringda / rasmiy"). */
  sub?: ReactNode;
  cell: (row: T) => ReactNode;
  /** Yakuniy qator (respublika / hudud) katagi. */
  footer?: ReactNode;
  sortable?: boolean;
  /** Saralash tugmasining to'liq nomi (title). */
  sortTitle?: string;
  align?: 'left' | 'center' | 'right';
  className?: string;
};

const ALIGN = { left: 'text-left', center: 'text-center', right: 'text-right' } as const;

/** Qator ichidagi havola yoki tugma bosilsa — qator bosilishi ishlamaydi (ikki marta o'tish bo'lmasin). */
function fromControl(e: MouseEvent): boolean {
  return Boolean((e.target as HTMLElement | null)?.closest('a,button'));
}

/**
 * Hudud/tuman/maktab jadvallari uchun umumiy jadval: birinchi ustun yopishqoq
 * (mobil — gorizontal aylantirish), saralanadigan sarlavhalar, yakuniy qator.
 * Saralashning o'zi chaqiruvchida — bu yerda faqat ko'rsatish.
 */
export function KitTable<T>({
  columns,
  rows,
  rowKey,
  sort,
  onSort,
  onRowClick,
  rowClassName,
  minWidth = 720,
  caption,
  footerClassName,
  className,
}: {
  columns: ReadonlyArray<KitColumn<T>>;
  rows: readonly T[];
  rowKey: (row: T) => string;
  sort?: SortState;
  onSort?: (key: string) => void;
  onRowClick?: (row: T) => void;
  rowClassName?: (row: T) => string | undefined;
  minWidth?: number;
  caption?: string;
  footerClassName?: string;
  className?: string;
}) {
  const hasFooter = columns.some((c) => c.footer !== undefined);
  return (
    // `relative` — ichidagi absolyut elementlar (sr-only) ham shu aylantirish konteyneri bilan kesiladi, sahifa kengaymaydi.
    <div className={cn('relative overflow-x-auto rounded-xl ring-1 ring-inset ring-border/50', className)}>
      <table className="w-full border-separate border-spacing-0 text-[0.8rem]" style={{ minWidth }}>
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead>
          <tr>
            {columns.map((c, i) => {
              const sticky = i === 0;
              const align = sticky ? 'left' : (c.align ?? 'center');
              const active = sort?.key === c.key;
              return (
                <th
                  key={c.key}
                  scope="col"
                  aria-sort={c.sortable && sort ? ariaSort(active, sort.dir) : undefined}
                  className={cn(
                    'px-2 pb-2 pt-2.5 align-bottom text-[0.68rem] font-semibold leading-tight text-muted-foreground',
                    ALIGN[align],
                    sticky && 'sticky left-0 z-20 bg-card/95 pl-3 uppercase tracking-[0.08em] backdrop-blur',
                  )}
                >
                  {c.sortable && sort && onSort ? (
                    <SortButton label={c.header} active={active} dir={sort.dir} onClick={() => onSort(c.key)} align={align} title={c.sortTitle} />
                  ) : (
                    c.header
                  )}
                  {c.sub && <span className="mt-0.5 block text-[0.62rem] font-normal normal-case tracking-normal opacity-80">{c.sub}</span>}
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr
              key={rowKey(row)}
              onClick={onRowClick ? (e) => !fromControl(e) && onRowClick(row) : undefined}
              className={cn('group', onRowClick && 'cursor-pointer', rowClassName?.(row))}
            >
              {columns.map((c, i) =>
                i === 0 ? (
                  <th
                    key={c.key}
                    scope="row"
                    className={cn(
                      'sticky left-0 z-10 whitespace-nowrap border-t border-border/40 bg-card/95 py-1.5 pl-3 pr-3 text-left font-medium backdrop-blur transition-colors',
                      onRowClick && 'group-hover:text-primary',
                      c.className,
                    )}
                  >
                    {c.cell(row)}
                  </th>
                ) : (
                  <td
                    key={c.key}
                    className={cn(
                      'border-t border-border/40 px-1 py-1.5 tabular-nums transition-colors',
                      onRowClick && 'group-hover:bg-primary/[0.035] dark:group-hover:bg-white/[0.025]',
                      ALIGN[c.align ?? 'center'],
                      c.className,
                    )}
                  >
                    {c.cell(row)}
                  </td>
                ),
              )}
            </tr>
          ))}
        </tbody>
        {hasFooter && (
          <tfoot className={footerClassName}>
            <tr>
              {columns.map((c, i) =>
                i === 0 ? (
                  <th key={c.key} scope="row" className="sticky left-0 z-10 whitespace-nowrap border-t-2 border-border/70 bg-card/95 py-2 pl-3 pr-3 text-left font-semibold backdrop-blur">
                    {c.footer}
                  </th>
                ) : (
                  <td key={c.key} className={cn('border-t-2 border-border/70 px-1 py-2 font-semibold tabular-nums', ALIGN[c.align ?? 'center'], c.className)}>
                    {c.footer}
                  </td>
                ),
              )}
            </tr>
          </tfoot>
        )}
      </table>
    </div>
  );
}

'use client';

import { ArrowDown, ArrowUp, ArrowUpDown, ChevronLeft, ChevronRight, SearchX } from 'lucide-react';
import type { ReactNode } from 'react';

import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import type { Pagination, SortDir } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { EmptyState } from './empty-state';

export type Column<T> = {
  key: string;
  header: ReactNode;
  cell: (row: T) => ReactNode;
  /** Servisdagi saralash kaliti (bo'lsa — sarlavha bosiladi). */
  sortKey?: string;
  className?: string;
  headerClassName?: string;
};

export type SortState = { sortBy?: string; sortDir?: SortDir };

/**
 * Umumiy jadval — saralash va sahifalash servisda (backend kabi), bu yerda
 * faqat ko'rsatish. Qatorni bosish (`onRowClick`) — tafsilot sahifasi.
 */
export function DataTable<T>({
  columns,
  rows,
  rowKey,
  loading,
  pagination,
  onPageChange,
  sort,
  onSortChange,
  onRowClick,
  emptyTitle,
  emptyDescription,
  emptyAction,
  className,
  skeletonRows = 8,
}: {
  columns: Column<T>[];
  rows: T[] | undefined;
  rowKey: (row: T) => string;
  loading?: boolean;
  pagination?: Pagination;
  onPageChange?: (page: number) => void;
  sort?: SortState;
  onSortChange?: (sort: SortState) => void;
  onRowClick?: (row: T) => void;
  emptyTitle?: string;
  emptyDescription?: string;
  emptyAction?: ReactNode;
  className?: string;
  skeletonRows?: number;
}) {
  const { t, formatNumber } = useI18n();

  const toggleSort = (key: string) => {
    if (!onSortChange) return;
    if (sort?.sortBy !== key) onSortChange({ sortBy: key, sortDir: 'asc' });
    else onSortChange({ sortBy: key, sortDir: sort.sortDir === 'asc' ? 'desc' : 'asc' });
  };

  const showSkeleton = loading && !rows;

  return (
    <div className={cn('overflow-hidden rounded-xl border bg-card', className)}>
      <Table>
        <TableHeader>
          <TableRow className="hover:bg-transparent">
            {columns.map((col) => (
              <TableHead key={col.key} className={col.headerClassName}>
                {col.sortKey && onSortChange ? (
                  <button
                    type="button"
                    onClick={() => toggleSort(col.sortKey!)}
                    className="-mx-1 inline-flex items-center gap-1 rounded px-1 hover:text-foreground"
                  >
                    {col.header}
                    {sort?.sortBy === col.sortKey ? (
                      sort.sortDir === 'desc' ? <ArrowDown className="h-3.5 w-3.5" /> : <ArrowUp className="h-3.5 w-3.5" />
                    ) : (
                      <ArrowUpDown className="h-3.5 w-3.5 opacity-40" />
                    )}
                  </button>
                ) : (
                  col.header
                )}
              </TableHead>
            ))}
          </TableRow>
        </TableHeader>
        <TableBody>
          {showSkeleton &&
            Array.from({ length: skeletonRows }).map((_, i) => (
              <TableRow key={`sk-${i}`} className="hover:bg-transparent">
                {columns.map((col) => (
                  <TableCell key={col.key}>
                    <Skeleton className="h-4 w-full max-w-[160px]" />
                  </TableCell>
                ))}
              </TableRow>
            ))}
          {rows?.map((row) => (
            <TableRow
              key={rowKey(row)}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
              className={cn(onRowClick && 'cursor-pointer')}
            >
              {columns.map((col) => (
                <TableCell key={col.key} className={col.className}>
                  {col.cell(row)}
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
      {rows && rows.length === 0 && (
        <EmptyState icon={<SearchX />} title={emptyTitle ?? t('common.noResults')} description={emptyDescription ?? t('common.noResultsHint')} action={emptyAction} />
      )}
      {pagination && pagination.total > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3 border-t px-4 py-3 text-sm no-print">
          <span className="text-muted-foreground">
            {t('common.showing', {
              from: formatNumber((pagination.page - 1) * pagination.limit + 1),
              to: formatNumber(Math.min(pagination.page * pagination.limit, pagination.total)),
              total: formatNumber(pagination.total),
            })}
          </span>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="icon-sm" disabled={pagination.page <= 1} onClick={() => onPageChange?.(pagination.page - 1)} aria-label="prev">
              <ChevronLeft />
            </Button>
            <span className="min-w-[72px] text-center tabular-nums">
              {pagination.page} / {pagination.totalPages}
            </span>
            <Button
              variant="outline"
              size="icon-sm"
              disabled={pagination.page >= pagination.totalPages}
              onClick={() => onPageChange?.(pagination.page + 1)}
              aria-label="next"
            >
              <ChevronRight />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

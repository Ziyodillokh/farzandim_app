'use client';

import { ChevronLeft, ChevronRight } from 'lucide-react';

import { Button } from '@/components/ui/button';
import type { Pagination } from '@/data/contracts';
import { useI18n } from '@/i18n';

/** Kartochkali ro'yxatlar uchun sahifalash (bitta sahifa bo'lsa — ko'rinmaydi). */
export function SimplePager({ pagination, onPageChange }: { pagination: Pagination | undefined; onPageChange: (page: number) => void }) {
  const { t, formatNumber } = useI18n();
  if (!pagination || pagination.totalPages <= 1) return null;
  const { page, limit, total, totalPages } = pagination;
  return (
    <div className="mt-6 flex flex-wrap items-center justify-between gap-3 text-sm no-print">
      <span className="text-muted-foreground">
        {t('common.showing', {
          from: formatNumber((page - 1) * limit + 1),
          to: formatNumber(Math.min(page * limit, total)),
          total: formatNumber(total),
        })}
      </span>
      <div className="flex items-center gap-2">
        <Button variant="outline" size="icon-sm" disabled={page <= 1} onClick={() => onPageChange(page - 1)} aria-label={t('common.back')}>
          <ChevronLeft />
        </Button>
        <span className="min-w-[56px] text-center tabular-nums">
          {page} / {totalPages}
        </span>
        <Button variant="outline" size="icon-sm" disabled={page >= totalPages} onClick={() => onPageChange(page + 1)} aria-label={t('common.next')}>
          <ChevronRight />
        </Button>
      </div>
    </div>
  );
}

'use client';

import { Check, X } from 'lucide-react';
import { useMemo } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { EarlyExitBadge } from '@/components/common/status-badges';
import { Button } from '@/components/ui/button';
import type { api } from '@/data/api';
import { useI18n } from '@/i18n';
import { fromIsoDate } from '../lib';

export type EarlyExitRow = Awaited<ReturnType<typeof api.attendance.earlyExits>>[number];

/** Erta ketish so'rovlari jadvali; kutilayotganlar uchun tasdiqlash/rad etish. */
export function EarlyExitTable({
  rows,
  loading,
  canDecide,
  emptyTitle,
  onDecide,
}: {
  rows: EarlyExitRow[] | undefined;
  loading?: boolean;
  canDecide: boolean;
  emptyTitle: string;
  onDecide: (row: EarlyExitRow, approve: boolean) => void;
}) {
  const { t, formatDate } = useI18n();

  const columns = useMemo<Column<EarlyExitRow>[]>(() => {
    const list: Column<EarlyExitRow>[] = [
      {
        key: 'student',
        header: t('attendance.earlyExit.columns.student'),
        cell: (r) => (
          <div>
            <p className="font-medium">{r.studentName}</p>
            <p className="text-xs text-muted-foreground">{r.className}</p>
          </div>
        ),
      },
      {
        key: 'time',
        header: t('attendance.earlyExit.columns.time'),
        className: 'whitespace-nowrap',
        cell: (r) => (
          <div>
            <p className="font-display text-base font-semibold tabular-nums">{r.time}</p>
            <p className="text-xs text-muted-foreground">{formatDate(fromIsoDate(r.date), 'd MMM')}</p>
          </div>
        ),
      },
      { key: 'reason', header: t('attendance.earlyExit.columns.reason'), className: 'max-w-[220px]', cell: (r) => <p className="line-clamp-2 text-sm">{r.reason}</p> },
      { key: 'pickup', header: t('attendance.earlyExit.columns.pickupBy'), className: 'text-sm', cell: (r) => r.pickupBy },
      {
        key: 'requested',
        header: t('attendance.earlyExit.columns.requested'),
        className: 'whitespace-nowrap text-xs text-muted-foreground',
        cell: (r) => formatDate(r.requestedAt, 'dd.MM HH:mm'),
      },
      {
        key: 'status',
        header: t('attendance.earlyExit.columns.status'),
        cell: (r) => (
          <div className="space-y-1">
            <EarlyExitBadge status={r.status} />
            {r.decidedByName && (
              <p className="text-2xs text-muted-foreground">
                {r.decidedByName}
                {r.decidedAt && ` · ${formatDate(r.decidedAt, 'HH:mm')}`}
              </p>
            )}
          </div>
        ),
      },
    ];
    if (!canDecide) return list;
    return [
      ...list,
      {
        key: 'actions',
        header: t('attendance.earlyExit.columns.actions'),
        className: 'text-right',
        headerClassName: 'text-right',
        cell: (r) =>
          r.status === 'PENDING' ? (
            <div className="flex justify-end gap-2">
              <Button size="sm" variant="outline" className="text-destructive hover:text-destructive" onClick={() => onDecide(r, false)}>
                <X />
                {t('attendance.earlyExit.reject')}
              </Button>
              <Button size="sm" onClick={() => onDecide(r, true)}>
                <Check />
                {t('attendance.earlyExit.approve')}
              </Button>
            </div>
          ) : null,
      },
    ];
  }, [t, formatDate, canDecide, onDecide]);

  return <DataTable columns={columns} rows={rows} rowKey={(r) => r.id} loading={loading} emptyTitle={emptyTitle} emptyDescription={t('attendance.earlyExit.emptyHint')} />;
}

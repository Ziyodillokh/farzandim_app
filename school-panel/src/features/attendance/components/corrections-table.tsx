'use client';

import { ArrowRight } from 'lucide-react';
import { useMemo } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { AttendanceBadge } from '@/components/common/status-badges';
import { Badge } from '@/components/ui/badge';
import type { Pagination } from '@/data/contracts';
import type { api } from '@/data/api';
import { useI18n } from '@/i18n';
import { fromIsoDate } from '../lib';

export type CorrectionRow = Awaited<ReturnType<typeof api.attendance.corrections>>[number];

/** Tuzatishlar tarixi: kim, qachon, qaysi kun, oldin → keyin, sabab. */
export function CorrectionsTable({
  rows,
  loading,
  pagination,
  onPageChange,
}: {
  rows: CorrectionRow[] | undefined;
  loading?: boolean;
  pagination?: Pagination;
  onPageChange: (page: number) => void;
}) {
  const { t, formatDate } = useI18n();

  const columns = useMemo<Column<CorrectionRow>[]>(
    () => [
      {
        key: 'at',
        header: t('attendance.corrections.columns.at'),
        className: 'whitespace-nowrap text-sm tabular-nums',
        cell: (r) => formatDate(r.correction.at, 'dd.MM.yyyy HH:mm'),
      },
      {
        key: 'student',
        header: t('attendance.corrections.columns.student'),
        cell: (r) => (
          <div className="flex items-center gap-2">
            <span className="font-medium">{r.studentName}</span>
            <Badge variant="outline" size="sm">
              {r.className}
            </Badge>
          </div>
        ),
      },
      {
        key: 'day',
        header: t('attendance.corrections.columns.day'),
        className: 'whitespace-nowrap text-sm text-muted-foreground',
        cell: (r) => formatDate(fromIsoDate(r.record.date), 'd MMM, EEE'),
      },
      {
        key: 'change',
        header: t('attendance.corrections.columns.change'),
        cell: (r) => (
          <div className="flex items-center gap-1.5">
            <AttendanceBadge status={r.correction.from} size="sm" />
            <ArrowRight className="h-3.5 w-3.5 text-muted-foreground" />
            <AttendanceBadge status={r.correction.to} size="sm" />
          </div>
        ),
      },
      { key: 'reason', header: t('attendance.corrections.columns.reason'), className: 'max-w-[260px]', cell: (r) => <p className="line-clamp-2 text-sm">{r.correction.reason}</p> },
      { key: 'by', header: t('attendance.corrections.columns.by'), className: 'text-sm text-muted-foreground', cell: (r) => r.byName },
    ],
    [t, formatDate],
  );

  return (
    <DataTable
      columns={columns}
      rows={rows}
      rowKey={(r) => `${r.record.id}:${r.correction.at}`}
      loading={loading}
      pagination={pagination}
      onPageChange={onPageChange}
      emptyTitle={t('attendance.corrections.empty')}
      emptyDescription={t('attendance.corrections.emptyHint')}
    />
  );
}

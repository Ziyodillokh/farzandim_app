'use client';

import { AlertTriangle } from 'lucide-react';
import { useMemo } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { Badge } from '@/components/ui/badge';
import type { CardTapLog, CardTapResult } from '@/data/contracts';
import { useI18n } from '@/i18n';

const RESULT_VARIANT: Record<CardTapResult, 'success' | 'info' | 'outline' | 'warning' | 'destructive'> = {
  IN: 'success',
  OUT: 'info',
  NONE: 'outline',
  OUTSIDE: 'outline',
  UNKNOWN: 'warning',
  BLOCKED: 'warning',
  INVALID: 'destructive',
};

/** Kiosk tegishlari jurnali: vaqt, o'quvchi / karta, natija va «shubhali» belgisi. */
export function TapsTable({ rows, loading }: { rows: CardTapLog[] | undefined; loading?: boolean }) {
  const { t, formatDate } = useI18n();

  const columns = useMemo<Column<CardTapLog>[]>(
    () => [
      {
        key: 'time',
        header: t('cards.columns.time'),
        className: 'whitespace-nowrap',
        cell: (r) => <span className="font-display font-semibold tabular-nums">{formatDate(new Date(r.tappedAt), 'd MMM, HH:mm:ss')}</span>,
      },
      {
        key: 'student',
        header: t('cards.columns.student'),
        cell: (r) => (
          <div className="min-w-0">
            <p className="whitespace-nowrap font-medium">{r.studentName ?? t('cards.taps.unknownCard')}</p>
            <p className="font-mono text-2xs text-muted-foreground">{[r.className, r.cardNumber ?? r.uid].filter(Boolean).join(' · ')}</p>
          </div>
        ),
      },
      {
        key: 'result',
        header: t('cards.columns.result'),
        cell: (r) => (
          <div className="flex flex-wrap items-center gap-1.5">
            <Badge variant={RESULT_VARIANT[r.result]}>{t(`enums.cardTapResult.${r.result}`)}</Badge>
            {r.suspicious && (
              <Badge variant="warning" className="gap-1" title={t('cards.taps.suspiciousHint')}>
                <AlertTriangle className="h-3 w-3" />
                {t('cards.taps.suspicious')}
              </Badge>
            )}
          </div>
        ),
      },
    ],
    [formatDate, t],
  );

  return <DataTable columns={columns} rows={rows} rowKey={(r) => r.id} loading={loading} emptyTitle={t('cards.taps.empty')} emptyDescription={t('cards.taps.emptyText')} />;
}

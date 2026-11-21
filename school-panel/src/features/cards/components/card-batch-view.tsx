'use client';

import { Download, FileUp, ListPlus, Nfc, X } from 'lucide-react';
import { useMemo, useState } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { ErrorState } from '@/components/common/error-state';
import { Button } from '@/components/ui/button';
import type { CardReservation } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { formatCardNumber } from '@/lib/card-number';
import { downloadCsv } from '@/lib/csv';
import { printColumns } from '../batch-csv';
import { useCancelReservation, useCardReservations } from '../batch-hooks';
import { BindStationDialog } from './bind-station-dialog';
import { ImportCardsDialog } from './import-cards-dialog';
import { ReserveCardsDialog } from './reserve-cards-dialog';

type BatchDialog = 'reserve' | 'station' | 'import' | null;

/**
 * Karta partiyasi (kartalar maktabga tayyor holda): 1) sinflarga raqam berish, 2) bosmaxona
 * uchun CSV, 3) chop etilgan kartalarni ketma-ket tegizib yoki ta'minotchi fayli bilan bog'lash.
 */
export function CardBatchView() {
  const { t, formatDate } = useI18n();
  const reservations = useCardReservations();
  const cancel = useCancelReservation();
  const [dialog, setDialog] = useState<BatchDialog>(null);
  const [cancelling, setCancelling] = useState<CardReservation | null>(null);
  const items = useMemo(() => reservations.data ?? [], [reservations.data]);
  const closeDialog = (open: boolean) => !open && setDialog(null);

  const columns = useMemo<Column<CardReservation>[]>(
    () => [
      { key: 'class', header: t('cards.batch.csv.className'), className: 'whitespace-nowrap', cell: (r) => <span className="font-medium">{r.className || '—'}</span> },
      {
        key: 'student',
        header: t('cards.batch.csv.student'),
        cell: (r) => (
          <div className="min-w-0">
            <p className="whitespace-nowrap font-medium">{r.studentName}</p>
            <p className="text-2xs text-muted-foreground">{r.studentCode}</p>
          </div>
        ),
      },
      { key: 'number', header: t('cards.batch.csv.number'), cell: (r) => <span className="font-mono font-semibold tabular-nums">{formatCardNumber(r.number)}</span> },
      {
        key: 'actions',
        header: '',
        className: 'w-12 text-right',
        cell: (r) => (
          <Button size="icon" variant="ghost" aria-label={t('cards.batch.cancel')} title={t('cards.batch.cancel')} onClick={() => setCancelling(r)}>
            <X />
          </Button>
        ),
      },
    ],
    [t],
  );

  return (
    <>
      <section className="mb-4 rounded-2xl border bg-card p-4 sm:p-5">
        <h2 className="font-display text-lg font-semibold">{t('cards.batch.title')}</h2>
        <p className="mt-1 max-w-3xl text-sm text-muted-foreground">{t('cards.batch.steps')}</p>
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <Button onClick={() => setDialog('reserve')}>
            <ListPlus />
            {t('cards.batch.reserve')}
          </Button>
          <Button
            variant="outline"
            disabled={items.length === 0}
            onClick={() => downloadCsv(`karta-partiya-${formatDate(new Date(), 'yyyy-MM-dd')}`, items, printColumns(t))}
          >
            <Download />
            {t('cards.batch.export')}
          </Button>
          <Button variant="outline" disabled={items.length === 0} onClick={() => setDialog('station')}>
            <Nfc />
            {t('cards.batch.station')}
          </Button>
          <Button variant="outline" disabled={items.length === 0} onClick={() => setDialog('import')}>
            <FileUp />
            {t('cards.batch.import')}
          </Button>
          {items.length > 0 && <span className="ml-auto text-sm font-semibold tabular-nums text-muted-foreground">{t('cards.batch.waiting', { count: items.length })}</span>}
        </div>
      </section>

      {reservations.error ? (
        <ErrorState error={reservations.error} onRetry={() => void reservations.refetch()} />
      ) : (
        <DataTable
          columns={columns}
          rows={reservations.data}
          rowKey={(r) => r.id}
          loading={reservations.isLoading}
          emptyTitle={t('cards.batch.empty')}
          emptyDescription={t('cards.batch.emptyText')}
        />
      )}

      <ReserveCardsDialog open={dialog === 'reserve'} onOpenChange={closeDialog} />
      <BindStationDialog open={dialog === 'station'} onOpenChange={closeDialog} items={items} />
      <ImportCardsDialog open={dialog === 'import'} onOpenChange={closeDialog} />
      <ConfirmDialog
        open={Boolean(cancelling)}
        onOpenChange={(open) => !open && setCancelling(null)}
        title={t('cards.batch.cancelTitle')}
        description={cancelling ? t('cards.batch.cancelText', { number: formatCardNumber(cancelling.number), name: cancelling.studentName }) : undefined}
        confirmLabel={t('cards.batch.cancel')}
        destructive
        loading={cancel.isPending}
        onConfirm={() => cancelling && cancel.mutate(cancelling.id, { onSuccess: () => setCancelling(null) })}
      />
    </>
  );
}

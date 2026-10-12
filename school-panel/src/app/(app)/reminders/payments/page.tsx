'use client';

import { CalendarClock, CalendarRange, CirclePause, Users, Wallet, X } from 'lucide-react';
import { useCallback, useMemo, useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { DataTable, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { SearchInput, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { api } from '@/data/api';
import type { PaymentFilter, PaymentFilterKind, PaymentRow } from '@/data/mock/services/comms';
import { FinanceCallout } from '@/features/reminders/components/finance-callout';
import { type PaymentAction, usePaymentColumns } from '@/features/reminders/components/payment-columns';
import { PaymentHistorySheet } from '@/features/reminders/components/payment-history-sheet';
import { PaymentShiftDialog } from '@/features/reminders/components/payment-shift-dialog';
import { usePausePayment, usePayments, usePaymentStats, useResumePayment } from '@/features/reminders/hooks';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';

const FILTERS: readonly PaymentFilterKind[] = ['ALL', 'DUE_SOON', 'PREPAID', 'PAUSED'];

export default function PaymentsPage() {
  const { t, formatDate, formatNumber } = useI18n();
  const [filter, setFilter] = useState<PaymentFilter>({ page: 1, limit: 20, filter: 'ALL', sortBy: 'nextDate', sortDir: 'asc' });
  const [selected, setSelected] = useState<ReadonlyMap<string, PaymentRow>>(new Map());
  const [shiftTargets, setShiftTargets] = useState<PaymentRow[]>([]);
  const [pauseTarget, setPauseTarget] = useState<PaymentRow | null>(null);
  const [resumeTarget, setResumeTarget] = useState<PaymentRow | null>(null);
  const [historyTarget, setHistoryTarget] = useState<PaymentRow | null>(null);
  const payments = usePayments(filter);
  const stats = usePaymentStats();
  const pause = usePausePayment();
  const resume = useResumePayment();
  const rows = payments.data?.items;

  const toggle = useCallback(
    (id: string) =>
      setSelected((prev) => {
        const next = new Map(prev);
        const row = rows?.find((r) => r.id === id);
        if (next.has(id)) next.delete(id);
        else if (row) next.set(id, row);
        return next;
      }),
    [rows],
  );
  const togglePage = useCallback(
    (ids: string[], on: boolean) =>
      setSelected((prev) => {
        const next = new Map(prev);
        for (const r of rows ?? []) {
          if (!ids.includes(r.id)) continue;
          if (on) next.set(r.id, r);
          else next.delete(r.id);
        }
        return next;
      }),
    [rows],
  );
  const onAction = useCallback((action: PaymentAction, row: PaymentRow) => {
    if (action === 'shift') setShiftTargets([row]);
    if (action === 'pause') setPauseTarget(row);
    if (action === 'resume') setResumeTarget(row);
    if (action === 'history') setHistoryTarget(row);
  }, []);
  const selectedIds = useMemo(() => new Set(selected.keys()), [selected]);
  const columns = usePaymentColumns({ rows, selected: selectedIds, onToggle: toggle, onTogglePage: togglePage, onAction });
  const update = (patch: Partial<PaymentFilter>) => setFilter((f) => ({ ...f, page: 1, ...patch }));

  const exportCsv = async () => {
    const all = await api.comms.payments.exportRows(filter);
    downloadCsv(t('reminders.payments.exportFile'), all, [
      { header: t('reminders.payments.columns.guardian'), value: (r) => r.guardianName },
      { header: t('reminders.payments.csv.phone'), value: (r) => r.phone },
      { header: t('reminders.payments.csv.children'), value: (r) => r.children.map((c) => c.name).join(', ') },
      { header: t('reminders.payments.csv.classes'), value: (r) => [...new Set(r.children.map((c) => c.className))].join(', ') },
      { header: t('reminders.payments.columns.nextDate'), value: (r) => r.nextDate },
      { header: t('reminders.payments.columns.prepaid'), value: (r) => r.prepaidMonths },
      { header: t('reminders.payments.csv.paused'), value: (r) => (r.paused ? t('common.yes') : t('common.no')) },
    ]);
  };

  const s = stats.data;
  return (
    <>
      <PageHeader title={t('reminders.payments.title')} subtitle={t('reminders.payments.subtitle')} actions={<ExportMenu onCsv={() => void exportCsv()} />} />
      <FinanceCallout className="mb-6" />

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard icon={<Users />} label={t('reminders.payments.stats.families')} value={formatNumber(s?.families ?? 0)} hint={t('reminders.payments.stats.familiesHint')} loading={stats.isLoading} />
        <StatCard
          icon={<CalendarClock />}
          tone="warning"
          label={t('reminders.payments.stats.dueSoon', { days: s?.dueSoonDays ?? 30 })}
          value={formatNumber(s?.dueSoon ?? 0)}
          hint={s?.nearestDate ? t('reminders.payments.stats.dueSoonHint', { date: formatDate(s.nearestDate, 'd MMMM') }) : undefined}
          loading={stats.isLoading}
        />
        <StatCard icon={<Wallet />} tone="success" label={t('reminders.payments.stats.prepaid')} value={formatNumber(s?.prepaid ?? 0)} hint={t('reminders.payments.stats.prepaidHint')} loading={stats.isLoading} />
        <StatCard icon={<CirclePause />} tone="muted" label={t('reminders.payments.stats.paused')} value={formatNumber(s?.paused ?? 0)} hint={t('reminders.payments.stats.pausedHint')} loading={stats.isLoading} />
      </div>

      <Toolbar className="justify-between">
        <Tabs className="w-full min-w-0 overflow-x-auto sm:w-auto" value={filter.filter ?? 'ALL'} onValueChange={(v) => update({ filter: v as PaymentFilterKind })}>
          <TabsList className="w-max">
            {FILTERS.map((f) => (
              <TabsTrigger key={f} value={f}>
                {t(`reminders.payments.filters.${f}`)}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <SearchInput value={filter.search ?? ''} onChange={(search) => update({ search })} placeholder={t('reminders.payments.searchPlaceholder')} />
      </Toolbar>

      {selected.size > 0 && (
        <div className="sticky top-24 z-20 mb-4 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-primary/30 bg-card/95 px-4 py-3 shadow-glass-lg animate-fade-in">
          <p className="text-sm font-semibold">{t('reminders.payments.selected', { count: formatNumber(selected.size) })}</p>
          <div className="flex gap-2">
            <Button variant="ghost" size="sm" onClick={() => setSelected(new Map())}>
              <X />
              {t('reminders.payments.clearSelection')}
            </Button>
            <Button size="sm" onClick={() => setShiftTargets([...selected.values()])}>
              <CalendarRange />
              {t('reminders.payments.bulkShift')}
            </Button>
          </div>
        </div>
      )}

      {payments.isError ? (
        <ErrorState error={payments.error} onRetry={() => void payments.refetch()} />
      ) : (
        <DataTable
          columns={columns}
          rows={rows}
          rowKey={(r) => r.id}
          loading={payments.isLoading}
          pagination={payments.data?.pagination}
          onPageChange={(page) => setFilter((f) => ({ ...f, page }))}
          sort={{ sortBy: filter.sortBy, sortDir: filter.sortDir }}
          onSortChange={(sort: SortState) => setFilter((f) => ({ ...f, ...sort, page: 1 }))}
        />
      )}

      <PaymentShiftDialog targets={shiftTargets} onOpenChange={(open) => !open && setShiftTargets([])} onDone={() => shiftTargets.length > 1 && setSelected(new Map())} />
      <PaymentHistorySheet payment={historyTarget} onOpenChange={(open) => !open && setHistoryTarget(null)} />
      <ConfirmDialog
        open={pauseTarget !== null}
        onOpenChange={(open) => !open && setPauseTarget(null)}
        title={t('reminders.payments.pause.title')}
        description={t('reminders.payments.pause.description', { name: pauseTarget?.guardianName ?? '' })}
        confirmLabel={t('reminders.payments.pause.confirm')}
        requireReason
        reasonLabel={t('reminders.payments.pause.reason')}
        loading={pause.isPending}
        onConfirm={(note) => pauseTarget && pause.mutate({ id: pauseTarget.id, note }, { onSuccess: () => setPauseTarget(null) })}
      />
      <ConfirmDialog
        open={resumeTarget !== null}
        onOpenChange={(open) => !open && setResumeTarget(null)}
        title={t('reminders.payments.resume.title')}
        description={t('reminders.payments.resume.description', { name: resumeTarget?.guardianName ?? '', date: resumeTarget ? formatDate(resumeTarget.nextDate, 'd MMMM yyyy') : '' })}
        confirmLabel={t('reminders.payments.resume.confirm')}
        loading={resume.isPending}
        onConfirm={() => resumeTarget && resume.mutate({ id: resumeTarget.id, note: t('reminders.payments.resume.defaultNote') }, { onSuccess: () => setResumeTarget(null) })}
      />
    </>
  );
}

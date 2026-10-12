'use client';

import { BellRing, CirclePause, Inbox, Plus, Repeat } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { ReminderKind } from '@/data/contracts';
import type { ReminderFilter, ReminderRow, ReminderWhen } from '@/data/mock/services/comms';
import { SimplePager } from '@/features/messages/components/simple-pager';
import { REMINDER_KINDS } from '@/features/reminders/components/kind-icon';
import { ReminderCard } from '@/features/reminders/components/reminder-card';
import { ReminderFormDialog } from '@/features/reminders/components/reminder-form-dialog';
import { useReminders, useRemoveReminder, useToggleReminder, useVerifications } from '@/features/reminders/hooks';
import { useI18n } from '@/i18n';

const WHEN: readonly ReminderWhen[] = ['UPCOMING', 'PAST'];

export default function RemindersPage() {
  const { t, formatDate, formatNumber } = useI18n();
  const can = useCan();
  const [filter, setFilter] = useState<ReminderFilter>({ when: 'UPCOMING', page: 1, limit: 20 });
  const [editing, setEditing] = useState<ReminderRow | null>(null);
  const [formOpen, setFormOpen] = useState(false);
  const [deleting, setDeleting] = useState<ReminderRow | null>(null);
  const list = useReminders(filter);
  const verifications = useVerifications({ status: 'OPEN', limit: 1 }, can('payments.manage'));
  const toggle = useToggleReminder();
  const remove = useRemoveReminder();

  // Ko'rsatkichlar servisda butun ro'yxat bo'yicha hisoblanadi (filtr/sahifalashdan qat'i nazar).
  const stats = list.data?.stats;
  const statsLoading = list.isLoading && !list.data;

  const openCreate = () => {
    setEditing(null);
    setFormOpen(true);
  };
  const when = filter.when ?? 'UPCOMING';

  return (
    <>
      <PageHeader
        title={t('reminders.title')}
        subtitle={t('reminders.subtitle')}
        actions={
          <Button onClick={openCreate}>
            <Plus />
            {t('reminders.add')}
          </Button>
        }
      />

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          icon={<BellRing />}
          label={t('reminders.stats.upcoming')}
          value={formatNumber(stats?.upcoming ?? 0)}
          hint={stats?.nextAt ? t('reminders.stats.nextHint', { date: formatDate(stats.nextAt, 'd MMMM, HH:mm') }) : undefined}
          loading={statsLoading}
        />
        <StatCard icon={<Repeat />} tone="info" label={t('reminders.stats.repeating')} value={formatNumber(stats?.repeating ?? 0)} loading={statsLoading} />
        <StatCard icon={<CirclePause />} tone="muted" label={t('reminders.stats.paused')} value={formatNumber(stats?.paused ?? 0)} loading={statsLoading} />
        {can('payments.manage') && (
          <Link href="/reminders/verifications" className="rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
            <StatCard
              icon={<Inbox />}
              tone={(verifications.data?.counts.OPEN ?? 0) > 0 ? 'warning' : 'success'}
              label={t('reminders.stats.verifications')}
              value={formatNumber(verifications.data?.counts.OPEN ?? 0)}
              hint={t('reminders.stats.verificationsHint')}
              loading={verifications.isLoading}
              className="h-full"
            />
          </Link>
        )}
      </div>

      <Toolbar className="justify-between">
        <Tabs value={when} onValueChange={(v) => setFilter((f) => ({ ...f, page: 1, when: v as ReminderWhen }))}>
          <TabsList>
            {WHEN.map((w) => (
              <TabsTrigger key={w} value={w}>
                {t(`reminders.tabs.${w}`)}
                <span className="rounded-full bg-muted-foreground/10 px-1.5 text-2xs tabular-nums">{formatNumber(list.data?.counts[w] ?? 0)}</span>
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <div className="flex w-full flex-wrap gap-2 sm:w-auto">
          <SearchInput value={filter.search ?? ''} onChange={(search) => setFilter((f) => ({ ...f, page: 1, search }))} placeholder={t('reminders.searchPlaceholder')} />
          <FilterSelect
            value={filter.kind}
            onChange={(kind) => setFilter((f) => ({ ...f, page: 1, kind: kind as ReminderKind | undefined }))}
            options={REMINDER_KINDS.map((k) => ({ value: k, label: t(`enums.reminderKind.${k}`) }))}
            allLabel={`${t('reminders.form.kind')}: ${t('common.all')}`}
            className="sm:w-56"
          />
        </div>
      </Toolbar>

      {list.isError && <ErrorState error={list.error} onRetry={() => void list.refetch()} />}
      {list.isLoading && !list.data && (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-36 rounded-xl" />
          ))}
        </div>
      )}
      {list.data && list.data.items.length === 0 && (
        <div className="rounded-xl border bg-card">
          <EmptyState
            icon={<BellRing />}
            title={filter.search || filter.kind ? t('common.noResults') : t(`reminders.empty.${when}.title`)}
            description={filter.search || filter.kind ? t('common.noResultsHint') : t(`reminders.empty.${when}.description`)}
            action={when === 'UPCOMING' && !filter.search && <Button onClick={openCreate}>{t('reminders.add')}</Button>}
          />
        </div>
      )}
      {list.data && list.data.items.length > 0 && (
        <div className="space-y-3">
          {list.data.items.map((row) => (
            <ReminderCard
              key={row.id}
              row={row}
              onEdit={(r) => {
                setEditing(r);
                setFormOpen(true);
              }}
              onDelete={setDeleting}
              onToggle={(r, active) => toggle.mutate({ id: r.id, active })}
              toggling={toggle.isPending && toggle.variables?.id === row.id}
            />
          ))}
        </div>
      )}

      <SimplePager pagination={list.data?.pagination} onPageChange={(page) => setFilter((f) => ({ ...f, page }))} />

      <ReminderFormDialog open={formOpen} onOpenChange={setFormOpen} reminder={editing} />
      <ConfirmDialog
        open={deleting !== null}
        onOpenChange={(open) => !open && setDeleting(null)}
        title={t('reminders.actions.deleteTitle')}
        description={t('reminders.actions.deleteDescription', { title: deleting?.title ?? '' })}
        confirmLabel={t('reminders.actions.delete')}
        destructive
        loading={remove.isPending}
        onConfirm={() => deleting && remove.mutate(deleting.id, { onSettled: () => setDeleting(null) })}
      />
    </>
  );
}

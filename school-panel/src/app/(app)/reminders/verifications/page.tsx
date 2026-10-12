'use client';

import { ChevronLeft, ChevronRight, Inbox } from 'lucide-react';
import { useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SearchInput, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { VerificationStatus } from '@/data/contracts';
import type { VerificationFilter, VerificationRow } from '@/data/mock/services/comms';
import { FinanceCallout } from '@/features/reminders/components/finance-callout';
import { VerificationAnswerDialog } from '@/features/reminders/components/verification-answer-dialog';
import { VerificationCard } from '@/features/reminders/components/verification-card';
import { useCloseVerification, useVerifications } from '@/features/reminders/hooks';
import { useI18n } from '@/i18n';

const TABS = ['OPEN', 'ANSWERED', 'CLOSED', 'ALL'] as const;
type Tab = (typeof TABS)[number];

export default function VerificationsPage() {
  const { t, formatNumber } = useI18n();
  const [filter, setFilter] = useState<VerificationFilter>({ status: 'OPEN', page: 1, limit: 10 });
  const [answering, setAnswering] = useState<VerificationRow | null>(null);
  const [closing, setClosing] = useState<VerificationRow | null>(null);
  const list = useVerifications(filter);
  const close = useCloseVerification();
  const tab: Tab = filter.status ?? 'ALL';
  const pagination = list.data?.pagination;
  const tabLabel = (key: Tab) => (key === 'ALL' ? t('reminders.verifications.all') : t(`enums.verificationStatus.${key}`));

  return (
    <>
      <PageHeader title={t('reminders.verifications.title')} subtitle={t('reminders.verifications.subtitle')} />
      <FinanceCallout className="mb-6" />

      <Toolbar className="justify-between">
        <Tabs value={tab} onValueChange={(v) => setFilter((f) => ({ ...f, page: 1, status: v === 'ALL' ? undefined : (v as VerificationStatus) }))}>
          <TabsList className="h-auto flex-wrap">
            {TABS.map((key) => (
              <TabsTrigger key={key} value={key}>
                {tabLabel(key)}
                <span className="rounded-full bg-muted-foreground/10 px-1.5 text-2xs tabular-nums">{formatNumber(list.data?.counts[key] ?? 0)}</span>
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <SearchInput value={filter.search ?? ''} onChange={(search) => setFilter((f) => ({ ...f, page: 1, search }))} placeholder={t('reminders.verifications.searchPlaceholder')} />
      </Toolbar>

      {list.isError && <ErrorState error={list.error} onRetry={() => void list.refetch()} />}
      {list.isLoading && !list.data && (
        <div className="grid gap-4 xl:grid-cols-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-64 rounded-xl" />
          ))}
        </div>
      )}
      {list.data && list.data.items.length === 0 && (
        <div className="rounded-xl border bg-card">
          <EmptyState
            icon={<Inbox />}
            title={filter.search ? t('common.noResults') : t('reminders.verifications.empty.title')}
            description={filter.search ? t('common.noResultsHint') : t('reminders.verifications.empty.description')}
          />
        </div>
      )}
      {list.data && list.data.items.length > 0 && (
        <div className="grid gap-4 xl:grid-cols-2">
          {list.data.items.map((row) => (
            <VerificationCard key={row.id} row={row} onAnswer={setAnswering} onClose={setClosing} />
          ))}
        </div>
      )}

      {pagination && pagination.totalPages > 1 && (
        <div className="mt-6 flex items-center justify-end gap-2 text-sm no-print">
          <Button variant="outline" size="icon-sm" disabled={pagination.page <= 1} onClick={() => setFilter((f) => ({ ...f, page: pagination.page - 1 }))} aria-label={t('common.back')}>
            <ChevronLeft />
          </Button>
          <span className="min-w-[56px] text-center tabular-nums">
            {pagination.page} / {pagination.totalPages}
          </span>
          <Button variant="outline" size="icon-sm" disabled={pagination.page >= pagination.totalPages} onClick={() => setFilter((f) => ({ ...f, page: pagination.page + 1 }))} aria-label={t('common.next')}>
            <ChevronRight />
          </Button>
        </div>
      )}

      <VerificationAnswerDialog request={answering} onOpenChange={(open) => !open && setAnswering(null)} />
      <ConfirmDialog
        open={closing !== null}
        onOpenChange={(open) => !open && setClosing(null)}
        title={t('reminders.verifications.closeTitle')}
        description={t('reminders.verifications.closeDescription')}
        confirmLabel={t('reminders.verifications.close')}
        loading={close.isPending}
        onConfirm={() => closing && close.mutate(closing.id, { onSettled: () => setClosing(null) })}
      />
    </>
  );
}

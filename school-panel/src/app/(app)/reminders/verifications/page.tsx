'use client';

import { Inbox } from 'lucide-react';
import { useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SearchInput, Toolbar } from '@/components/common/toolbar';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { VerificationStatus } from '@/data/contracts';
import type { VerificationFilter, VerificationRow } from '@/data/mock/services/comms';
import { FinanceCallout } from '@/features/reminders/components/finance-callout';
import { VerificationAnswerDialog } from '@/features/reminders/components/verification-answer-dialog';
import { VerificationCard } from '@/features/reminders/components/verification-card';
import { useCloseVerification, useVerifications } from '@/features/reminders/hooks';
import { SimplePager } from '@/features/messages/components/simple-pager';
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
  const tabLabel = (key: Tab) => (key === 'ALL' ? t('reminders.verifications.all') : t(`enums.verificationStatus.${key}`));

  return (
    <>
      <PageHeader title={t('reminders.verifications.title')} subtitle={t('reminders.verifications.subtitle')} />
      <FinanceCallout className="mb-6" />

      <Toolbar className="justify-between">
        <Tabs className="w-full min-w-0 overflow-x-auto sm:w-auto" value={tab} onValueChange={(v) => setFilter((f) => ({ ...f, page: 1, status: v === 'ALL' ? undefined : (v as VerificationStatus) }))}>
          <TabsList className="w-max">
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
            <Skeleton key={i} className="h-64 rounded-2xl" />
          ))}
        </div>
      )}
      {list.data && list.data.items.length === 0 && (
        <Card>
          <EmptyState
            icon={<Inbox />}
            title={filter.search ? t('common.noResults') : t('reminders.verifications.empty.title')}
            description={filter.search ? t('common.noResultsHint') : t('reminders.verifications.empty.description')}
          />
        </Card>
      )}
      {list.data && list.data.items.length > 0 && (
        <div className="grid gap-4 xl:grid-cols-2">
          {list.data.items.map((row) => (
            <VerificationCard key={row.id} row={row} onAnswer={setAnswering} onClose={setClosing} />
          ))}
        </div>
      )}

      <SimplePager pagination={list.data?.pagination} onPageChange={(page) => setFilter((f) => ({ ...f, page }))} />

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

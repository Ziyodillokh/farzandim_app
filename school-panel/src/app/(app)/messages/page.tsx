'use client';

import { MessagesSquare, PenSquare } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';

import { useCan } from '@/auth/use-session';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SearchInput, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { MessageStatus } from '@/data/contracts';
import type { AnnouncementFilter } from '@/data/mock/services/comms';
import { AnnouncementCard } from '@/features/messages/components/announcement-card';
import { AnnouncementSheet } from '@/features/messages/components/announcement-sheet';
import { useAnnouncements } from '@/features/messages/hooks';
import { SimplePager } from '@/features/messages/components/simple-pager';
import { useI18n } from '@/i18n';

const TABS = ['ALL', 'SENT', 'SCHEDULED', 'DRAFT'] as const;
type Tab = (typeof TABS)[number];
const PAGE_SIZE = 12;

export default function MessagesPage() {
  const { t, formatNumber } = useI18n();
  const can = useCan();
  const canSend = can('messages.sendSchool') || can('messages.sendClass');
  const [filter, setFilter] = useState<AnnouncementFilter>({ page: 1, limit: PAGE_SIZE });
  const [openId, setOpenId] = useState<string | null>(null);
  const list = useAnnouncements(filter);
  const tab: Tab = filter.status ?? 'ALL';

  const newButton = canSend && (
    <Button asChild>
      <Link href="/messages/new">
        <PenSquare />
        {t('messages.newMessage')}
      </Link>
    </Button>
  );

  return (
    <>
      <PageHeader title={t('messages.title')} subtitle={t('messages.subtitle')} actions={newButton} />

      <Toolbar className="justify-between">
        <Tabs value={tab} onValueChange={(v) => setFilter((f) => ({ ...f, page: 1, status: v === 'ALL' ? undefined : (v as MessageStatus) }))}>
          <TabsList className="h-auto flex-wrap">
            {TABS.map((key) => (
              <TabsTrigger key={key} value={key}>
                {t(`messages.tabs.${key}`)}
                <span className="rounded-full bg-muted-foreground/10 px-1.5 text-2xs tabular-nums">{formatNumber(list.data?.counts[key] ?? 0)}</span>
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <SearchInput value={filter.search ?? ''} onChange={(search) => setFilter((f) => ({ ...f, page: 1, search }))} placeholder={t('messages.searchPlaceholder')} />
      </Toolbar>

      {list.isError && <ErrorState error={list.error} onRetry={() => void list.refetch()} />}

      {list.isLoading && !list.data && (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-60 rounded-xl" />
          ))}
        </div>
      )}

      {list.data && list.data.items.length === 0 && (
        <div className="rounded-xl border bg-card">
          <EmptyState
            icon={<MessagesSquare />}
            title={filter.search ? t('common.noResults') : t('messages.empty.title')}
            description={filter.search ? t('common.noResultsHint') : t('messages.empty.description')}
            action={!filter.search && newButton}
          />
        </div>
      )}

      {list.data && list.data.items.length > 0 && (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {list.data.items.map((row) => (
            <AnnouncementCard key={row.id} row={row} onOpen={setOpenId} />
          ))}
        </div>
      )}

      <SimplePager pagination={list.data?.pagination} onPageChange={(page) => setFilter((f) => ({ ...f, page }))} />

      <AnnouncementSheet id={openId} onOpenChange={(open) => !open && setOpenId(null)} />
    </>
  );
}

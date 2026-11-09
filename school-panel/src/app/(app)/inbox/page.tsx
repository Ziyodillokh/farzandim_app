'use client';

import { Inbox, Lock, MessageCircleMore } from 'lucide-react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useCallback, useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SearchInput } from '@/components/common/toolbar';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { InboxStatusFilter } from '@/data/contracts';
import { ThreadList } from '@/features/inbox/components/thread-list';
import { ThreadView } from '@/features/inbox/components/thread-view';
import { useInboxList, useInboxThread } from '@/features/inbox/hooks';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const STATUSES: readonly InboxStatusFilter[] = ['OPEN', 'RESOLVED', 'ALL'];

export default function InboxPage() {
  return (
    <Suspense fallback={<Skeleton className="h-[34rem] w-full rounded-2xl" />}>
      <InboxScreen />
    </Suspense>
  );
}

function InboxScreen() {
  const { t } = useI18n();
  const router = useRouter();
  const selected = useSearchParams().get('thread');
  const [status, setStatus] = useState<InboxStatusFilter>('OPEN');
  const [search, setSearch] = useState('');
  const list = useInboxList({ status, search: search || undefined });
  const thread = useInboxThread(selected);
  const onSearch = useCallback((value: string) => setSearch(value), []);
  const select = useCallback((id: string | null) => router.replace(id ? `/inbox?thread=${encodeURIComponent(id)}` : '/inbox', { scroll: false }), [router]);
  const unread = list.data?.counts.unread ?? 0;

  const listBody = () => {
    if (list.error) return <ErrorState error={list.error} onRetry={() => void list.refetch()} />;
    if (list.isLoading) {
      return (
        <div className="space-y-2 p-4">
          {Array.from({ length: 5 }, (_, i) => (
            <Skeleton key={i} className="h-20 w-full rounded-xl" />
          ))}
        </div>
      );
    }
    const items = list.data?.items ?? [];
    if (items.length === 0) {
      return <EmptyState icon={<Inbox />} title={t(`inbox.empty.${status}` as TKey)} description={t('inbox.empty.hint')} />;
    }
    return <ThreadList items={items} selectedId={selected} onSelect={select} />;
  };

  const threadBody = () => {
    if (!selected) {
      return <EmptyState className="h-full" icon={<MessageCircleMore />} title={t('inbox.select.title')} description={t('inbox.select.hint')} />;
    }
    if (thread.error) return <ErrorState error={thread.error} onRetry={() => void thread.refetch()} />;
    if (!thread.data) {
      return (
        <div className="space-y-4 p-5">
          <Skeleton className="h-12 w-2/3 rounded-xl" />
          <Skeleton className="h-24 w-4/5 rounded-2xl" />
          <Skeleton className="ml-auto h-16 w-3/5 rounded-2xl" />
        </div>
      );
    }
    return <ThreadView thread={thread.data} onBack={() => select(null)} />;
  };

  return (
    <>
      <PageHeader title={t('inbox.title')} subtitle={t('inbox.subtitle')} badge={unread > 0 ? <span className="rounded-full bg-primary px-2.5 py-0.5 text-xs font-bold text-primary-foreground">{t('inbox.unreadBadge', { count: unread })}</span> : undefined} />

      <Card className="mb-5 flex items-center gap-3 p-4 text-sm">
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
          <Lock className="h-4 w-4" />
        </span>
        <p className="text-foreground/80">{t('inbox.privacy')}</p>
      </Card>

      <Card className="grid min-h-[34rem] overflow-hidden p-0 lg:grid-cols-[minmax(19rem,24rem)_1fr]">
        <div className={cn('flex min-h-0 flex-col border-border/50 lg:border-r', selected && 'hidden lg:flex')}>
          <div className="space-y-3 border-b border-border/50 p-4">
            <Tabs value={status} onValueChange={(v) => setStatus(v as InboxStatusFilter)}>
              <TabsList className="w-full">
                {STATUSES.map((s) => (
                  <TabsTrigger key={s} value={s} className="flex-1">
                    {t(`inbox.tabs.${s}` as TKey)}
                  </TabsTrigger>
                ))}
              </TabsList>
            </Tabs>
            <SearchInput value={search} onChange={onSearch} placeholder={t('inbox.searchPlaceholder')} className="sm:w-full" />
          </div>
          <div className="min-h-0 flex-1 overflow-y-auto">{listBody()}</div>
        </div>
        <div className={cn('min-h-[30rem]', !selected && 'hidden lg:block')}>{threadBody()}</div>
      </Card>
    </>
  );
}

'use client';

import { Clock4, LogIn, LogOut } from 'lucide-react';
import { type ReactNode, useMemo, useState } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { Badge } from '@/components/ui/badge';
import { paginate } from '@/data/mock/query';
import type { FeedItem } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { type FeedOptions, useFeed } from '../hooks';
import { feedTone, FeedKindIcon } from './feed-list';
import { SourceTag } from './source-tag';

const FEED_LIMIT = 500;
const PAGE_SIZE = 25;

function SummaryPill({ icon, label, value, tone }: { icon: ReactNode; label: string; value: string; tone: string }) {
  return (
    <div className="glass flex items-center gap-3 rounded-2xl px-4 py-3">
      <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ring-1 ring-inset [&_svg]:size-[18px]', tone)}>{icon}</span>
      <span className="text-sm font-medium text-muted-foreground">{label}</span>
      <span className="ml-auto font-display text-xl font-semibold tabular-nums">{value}</span>
    </div>
  );
}

/** To'liq jonli oqim jadvali (filtrlar sahifada). */
export function FeedEventsTab({ options }: { options: Omit<FeedOptions, 'limit'> }) {
  const { t, formatDate, formatNumber } = useI18n();
  const [page, setPage] = useState(1);
  const feed = useFeed({ ...options, limit: FEED_LIMIT });
  const items = feed.data;

  const summary = useMemo(() => {
    const list = items ?? [];
    return {
      in: list.filter((e) => e.kind === 'IN').length,
      out: list.filter((e) => e.kind === 'OUT').length,
      late: list.filter((e) => e.late).length,
    };
  }, [items]);
  const paged = items ? paginate(items, page, PAGE_SIZE) : undefined;

  const columns = useMemo<Column<FeedItem>[]>(
    () => [
      { key: 'time', header: t('attendance.feed.columns.time'), className: 'w-20 font-semibold tabular-nums', cell: (e) => formatDate(e.at, 'HH:mm') },
      {
        key: 'student',
        header: t('attendance.feed.columns.student'),
        cell: (e) => (
          <div className="flex items-center gap-3">
            <FeedKindIcon item={e} className="h-8 w-8 rounded-lg" />
            <span className="whitespace-nowrap font-medium">{e.studentName}</span>
          </div>
        ),
      },
      { key: 'class', header: t('common.class'), cell: (e) => <Badge variant="outline" className="whitespace-nowrap">{e.className}</Badge> },
      {
        key: 'event',
        header: t('attendance.feed.columns.event'),
        cell: (e) => (
          <span className={cn('text-sm font-medium', feedTone(e).text)}>
            {t(`attendance.feed.kind.${e.kind}`)}
            {e.late && ` ${t('attendance.feed.lateTag')}`}
          </span>
        ),
      },
      { key: 'source', header: t('attendance.feed.columns.source'), cell: (e) => <SourceTag source={e.source} /> },
    ],
    [t, formatDate],
  );

  if (feed.error) return <ErrorState error={feed.error} onRetry={() => void feed.refetch()} />;

  return (
    <>
      <div className="mb-4 grid gap-3 sm:grid-cols-3">
        <SummaryPill icon={<LogIn />} tone="bg-success/10 text-success ring-success/20" label={t('attendance.feed.summary.in')} value={formatNumber(summary.in)} />
        <SummaryPill icon={<LogOut />} tone="bg-info/10 text-info ring-info/20" label={t('attendance.feed.summary.out')} value={formatNumber(summary.out)} />
        <SummaryPill icon={<Clock4 />} tone="bg-warning/15 text-warning ring-warning/25" label={t('attendance.feed.summary.late')} value={formatNumber(summary.late)} />
      </div>
      <DataTable
        columns={columns}
        rows={paged?.items}
        rowKey={(e) => e.id}
        loading={feed.isLoading}
        pagination={paged?.pagination}
        onPageChange={setPage}
        emptyTitle={t('attendance.feed.empty')}
        emptyDescription={t('attendance.feed.emptyHint')}
      />
    </>
  );
}

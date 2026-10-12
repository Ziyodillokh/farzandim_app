'use client';

import { ArrowRight, Radio } from 'lucide-react';
import Link from 'next/link';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useFeed } from '../hooks';
import { FeedList } from './feed-list';
import { LiveDot } from './live-indicator';

const SIDE_LIMIT = 8;

/** Taxtaning yon paneli — bugungi oxirgi kirish/chiqishlar. */
export function FeedSidePanel({ className }: { className?: string }) {
  const { t } = useI18n();
  const feed = useFeed({ limit: SIDE_LIMIT });

  return (
    <Card className={cn('overflow-hidden', className)}>
      <div className="flex items-center justify-between gap-3 border-b border-border/50 bg-gradient-to-r from-primary/[0.07] to-transparent px-5 py-4 dark:border-white/[0.06]">
        <div className="flex items-center gap-2.5">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
            <Radio className="h-[18px] w-[18px]" />
          </span>
          <div>
            <h2 className="flex items-center gap-2 text-[0.95rem] font-semibold">
              {t('attendance.feed.title')}
              <LiveDot />
            </h2>
            <p className="text-xs text-muted-foreground">{t('attendance.feed.todayOnly')}</p>
          </div>
        </div>
        <Button asChild variant="ghost" size="sm" className="rounded-full text-primary hover:bg-primary/[0.06] no-print">
          <Link href="/attendance/feed">
            {t('attendance.feed.viewAll')}
            <ArrowRight />
          </Link>
        </Button>
      </div>
      <div className="px-4 py-1.5">
        {feed.error ? (
          <ErrorState error={feed.error} onRetry={() => void feed.refetch()} />
        ) : feed.data && feed.data.length === 0 ? (
          <EmptyState icon={<Radio />} title={t('attendance.feed.empty')} description={t('attendance.feed.emptyHint')} className="py-10" />
        ) : (
          <FeedList items={feed.data} loading={feed.isLoading} skeletonRows={SIDE_LIMIT} />
        )}
      </div>
    </Card>
  );
}

'use client';

import { LogIn, LogOut } from 'lucide-react';

import { Skeleton } from '@/components/ui/skeleton';
import type { FeedItem } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { STATUS_TONE } from '../lib';
import { SourceTag } from './source-tag';

/** Hodisa rangi: kirish — yashil, kechikib kirish — sariq, chiqish — ko'k. */
export function feedTone(item: Pick<FeedItem, 'kind' | 'late'>) {
  if (item.kind === 'OUT') return STATUS_TONE.LEFT_EARLY;
  return item.late ? STATUS_TONE.LATE : STATUS_TONE.PRESENT;
}

export function FeedKindIcon({ item, className }: { item: Pick<FeedItem, 'kind' | 'late'>; className?: string }) {
  const tone = feedTone(item);
  const Icon = item.kind === 'IN' ? LogIn : LogOut;
  return (
    <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl', tone.soft, tone.text, className)}>
      <Icon className="h-4 w-4" />
    </span>
  );
}

/** Ixcham hodisalar ro'yxati (taxtadagi yon panel). Yangi hodisa yuqoridan "suzib" chiqadi. */
export function FeedList({ items, loading, skeletonRows = 6 }: { items: FeedItem[] | undefined; loading?: boolean; skeletonRows?: number }) {
  const { t, formatDate } = useI18n();

  if (loading && !items) {
    return (
      <ul className="divide-y">
        {Array.from({ length: skeletonRows }).map((_, i) => (
          <li key={i} className="flex items-center gap-3 py-2.5">
            <Skeleton className="h-9 w-9 rounded-xl" />
            <div className="flex-1 space-y-1.5">
              <Skeleton className="h-3.5 w-2/3" />
              <Skeleton className="h-3 w-1/2" />
            </div>
          </li>
        ))}
      </ul>
    );
  }

  return (
    <ul className="divide-y">
      {items?.map((item) => (
        <li key={item.id} className="flex items-center gap-3 py-2.5 animate-slide-up">
          <FeedKindIcon item={item} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{item.studentName}</p>
            <p className="mt-0.5 flex items-center gap-1.5 truncate text-xs text-muted-foreground">
              <span className="font-semibold text-foreground/80">{item.className}</span>
              <span>·</span>
              <span className={cn(item.late && feedTone(item).text)}>
                {t(`attendance.feed.kind.${item.kind}`)}
                {item.late && ` ${t('attendance.feed.lateTag')}`}
              </span>
            </p>
          </div>
          <div className="shrink-0 text-right">
            <p className="text-sm font-semibold tabular-nums">{formatDate(item.at, 'HH:mm')}</p>
            <SourceTag source={item.source} className="text-2xs [&_svg]:h-3 [&_svg]:w-3" />
          </div>
        </li>
      ))}
    </ul>
  );
}

'use client';

import { Bell, BellOff, CheckCheck } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { useSession } from '@/auth/use-session';
import { Button } from '@/components/ui/button';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Skeleton } from '@/components/ui/skeleton';
import type { NotificationItem } from '@/data/contracts';
import { toLocalIso } from '@/data/mock/calendar';
import { clockNow, clockToday } from '@/data/mock/clock';
import { useI18n } from '@/i18n';
import { useNotificationFeed, useReadState } from '../hooks';
import { groupByDay, isUnread, markAllRead, markRead, unreadCount } from '../read-state';
import { NotificationRow } from './notification-row';

const BADGE_MAX = 9;

function Group({ label, items, isRowUnread, onOpen }: { label: string; items: NotificationItem[]; isRowUnread: (item: NotificationItem) => boolean; onOpen: (item: NotificationItem) => void }) {
  if (items.length === 0) return null;
  return (
    <section>
      <h3 className="px-2.5 pb-1 pt-2 text-2xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">{label}</h3>
      <ul className="space-y-0.5">
        {items.map((item) => (
          <NotificationRow key={item.id} item={item} unread={isRowUnread(item)} onOpen={onOpen} />
        ))}
      </ul>
    </section>
  );
}

function FeedSkeleton() {
  return (
    <div className="space-y-3 p-2.5">
      {[0, 1, 2].map((i) => (
        <div key={i} className="flex gap-3">
          <Skeleton className="h-8 w-8 rounded-lg" />
          <div className="flex-1 space-y-1.5">
            <Skeleton className="h-3 w-24" />
            <Skeleton className="h-3.5 w-full" />
          </div>
        </div>
      ))}
    </div>
  );
}

function EmptyFeed({ title, hint }: { title: string; hint: string }) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-10 text-center">
      <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
        <BellOff className="h-5 w-5" />
      </span>
      <p className="text-sm font-semibold">{title}</p>
      <p className="max-w-[16rem] text-xs text-muted-foreground">{hint}</p>
    </div>
  );
}

/** Bildirishnomalar markazi — topbardagi qo'ng'iroqcha. */
export function NotificationBell() {
  const { t } = useI18n();
  const router = useRouter();
  const session = useSession();
  const feed = useNotificationFeed();
  const [readState, updateReadState] = useReadState(session?.staffId);
  const [open, setOpen] = useState(false);

  const items = feed.data ?? [];
  const count = unreadCount(items, readState);
  const groups = groupByDay(items, clockToday());
  const isRowUnread = (item: NotificationItem) => isUnread(item, readState);
  const label = count > 0 ? `${t('notifications.title')}: ${t('notifications.unreadCount', { count })}` : t('notifications.title');

  const openItem = (item: NotificationItem) => {
    updateReadState((s) => markRead(s, item));
    if (!item.href) return;
    setOpen(false);
    router.push(item.href);
  };

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="relative rounded-xl" aria-label={label} title={t('notifications.title')}>
          <Bell />
          {count > 0 && (
            <span
              aria-hidden
              className="absolute right-1 top-1 flex h-[1.1rem] min-w-[1.1rem] items-center justify-center rounded-full bg-destructive px-1 text-[0.62rem] font-bold leading-none text-destructive-foreground ring-2 ring-white tabular-nums dark:ring-background"
            >
              {count > BADGE_MAX ? `${BADGE_MAX}+` : count}
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-[22rem] max-w-[calc(100vw-1.5rem)] p-0">
        <div className="flex items-center justify-between gap-3 border-b border-border/60 px-4 py-3 dark:border-white/[0.06]">
          <div className="min-w-0">
            <p className="font-semibold leading-tight">{t('notifications.title')}</p>
            <p className="mt-0.5 text-xs text-muted-foreground">{count > 0 ? t('notifications.unreadCount', { count }) : t('notifications.allRead')}</p>
          </div>
          <Button
            variant="ghost"
            size="sm"
            className="h-8 shrink-0 px-2.5 text-primary hover:text-primary"
            disabled={count === 0}
            onClick={() => updateReadState((s) => markAllRead(s, items, toLocalIso(clockNow())))}
          >
            <CheckCheck />
            {t('notifications.markAllRead')}
          </Button>
        </div>
        <div className="max-h-[min(28rem,70vh)] overflow-y-auto overscroll-contain px-1.5 pb-2">
          {feed.isPending ? (
            <FeedSkeleton />
          ) : feed.isError ? (
            <EmptyFeed title={t('notifications.loadError')} hint={t('notifications.loadErrorHint')} />
          ) : items.length === 0 ? (
            <EmptyFeed title={t('notifications.emptyTitle')} hint={t('notifications.emptyHint')} />
          ) : (
            <>
              <Group label={t('notifications.today')} items={groups.today} isRowUnread={isRowUnread} onOpen={openItem} />
              <Group label={t('notifications.earlier')} items={groups.earlier} isRowUnread={isRowUnread} onOpen={openItem} />
            </>
          )}
        </div>
      </PopoverContent>
    </Popover>
  );
}

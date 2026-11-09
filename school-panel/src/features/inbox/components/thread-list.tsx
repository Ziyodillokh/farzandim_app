'use client';

import { CheckCheck, CornerDownLeft } from 'lucide-react';

import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import type { ParentThreadRow } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';
import { TopicChip } from './topic-chip';

/** Ota-ona murojaatlari ro'yxati: o'qilmagan — qalin va nishonli, oxirgi xabar oldindan ko'rinadi. */
export function ThreadList({ items, selectedId, onSelect }: { items: ParentThreadRow[]; selectedId: string | null; onSelect: (id: string) => void }) {
  const { t, formatRelative } = useI18n();
  return (
    <ul className="divide-y divide-border/50" data-testid="inbox-list">
      {items.map((thread) => {
        const active = thread.id === selectedId;
        const unread = thread.unread > 0;
        const waiting = thread.lastAuthor === 'PARENT' && thread.status === 'OPEN';
        return (
          <li key={thread.id}>
            <button
              type="button"
              onClick={() => onSelect(thread.id)}
              aria-current={active ? 'true' : undefined}
              className={cn(
                'flex w-full gap-3 px-4 py-3.5 text-left transition-colors hover:bg-primary/[0.04] focus-visible:bg-primary/[0.06] focus-visible:outline-none',
                active && 'bg-primary/[0.08] hover:bg-primary/[0.08]',
              )}
              data-testid="inbox-row"
            >
              <Avatar className="h-10 w-10 shrink-0">
                <AvatarFallback className="text-xs font-semibold">{initials(thread.guardian.fullName)}</AvatarFallback>
              </Avatar>
              <span className="min-w-0 flex-1">
                <span className="flex items-baseline gap-2">
                  <span className={cn('truncate text-sm', unread ? 'font-semibold text-foreground' : 'font-medium text-foreground/85')}>
                    {thread.guardian.fullName}
                  </span>
                  <time dateTime={thread.lastMessageAt} className="ml-auto shrink-0 text-2xs tabular-nums text-muted-foreground">
                    {formatRelative(thread.lastMessageAt)}
                  </time>
                </span>
                <span className="mt-0.5 block truncate text-xs text-muted-foreground">
                  {t('inbox.studentLine', { name: thread.student.name, className: thread.student.className })}
                </span>
                <span className="mt-1.5 flex items-center gap-2">
                  {thread.preview?.author === 'STAFF' ? (
                    <CornerDownLeft className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-label={t('inbox.you')} />
                  ) : null}
                  <span className={cn('line-clamp-1 text-[0.8rem]', unread ? 'text-foreground' : 'text-muted-foreground')}>{thread.preview?.text ?? ''}</span>
                  {unread ? (
                    <span className="ml-auto flex h-5 min-w-5 shrink-0 items-center justify-center rounded-full bg-primary px-1.5 text-[0.68rem] font-bold tabular-nums text-primary-foreground">
                      {thread.unread}
                    </span>
                  ) : thread.status === 'RESOLVED' ? (
                    <CheckCheck className="ml-auto h-4 w-4 shrink-0 text-emerald-500" aria-label={t('inbox.status.RESOLVED')} />
                  ) : null}
                </span>
                {waiting && !unread && (
                  <span className="mt-1.5 inline-flex">
                    <TopicChip label={t('inbox.waiting')} tone="warning" />
                  </span>
                )}
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}

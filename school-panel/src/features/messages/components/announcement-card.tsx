'use client';

import { CalendarClock, FileText, Send, Star } from 'lucide-react';

import { MessageStatusBadge } from '@/components/common/status-badges';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import type { AnnouncementRow } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { AudienceChips } from './audience-chips';
import { DeliveryStats } from './delivery-stats';

const DATE_PATTERN = 'd MMM, HH:mm';

/** Xabar kartochkasi: holat, auditoriya va (yuborilgan bo'lsa) yetkazish/o'qilish ulushi. */
export function AnnouncementCard({ row, onOpen }: { row: AnnouncementRow; onOpen: (id: string) => void }) {
  const { t, tc, formatDate } = useI18n();
  const StatusIcon = row.status === 'SENT' ? Send : row.status === 'SCHEDULED' ? CalendarClock : FileText;
  const when =
    row.status === 'SENT' && row.sentAt
      ? t('messages.card.sentAt', { date: formatDate(row.sentAt, DATE_PATTERN) })
      : row.status === 'SCHEDULED' && row.scheduledAt
        ? t('messages.card.scheduledFor', { date: formatDate(row.scheduledAt, DATE_PATTERN) })
        : t('messages.card.draft');

  return (
    <Card
      role="button"
      tabIndex={0}
      onClick={() => onOpen(row.id)}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          onOpen(row.id);
        }
      }}
      className={cn(
        'card-glow group flex cursor-pointer flex-col gap-4 p-5 outline-none animate-fade-in focus-visible:ring-2 focus-visible:ring-ring',
        row.priority === 'IMPORTANT' && 'border-l-4 border-l-warning',
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-2 text-xs text-muted-foreground">
          <span
            className={cn(
              'flex h-8 w-8 shrink-0 items-center justify-center rounded-lg',
              row.status === 'SENT' ? 'bg-success/10 text-success' : row.status === 'SCHEDULED' ? 'bg-info/10 text-info' : 'bg-muted text-muted-foreground',
            )}
          >
            <StatusIcon className="h-4 w-4" />
          </span>
          <span className="truncate">{when}</span>
        </div>
        <div className="flex shrink-0 items-center gap-1.5">
          {row.priority === 'IMPORTANT' && (
            <Badge variant="warning" className="gap-1">
              <Star className="h-3 w-3 fill-current" />
              {t('enums.messagePriority.IMPORTANT')}
            </Badge>
          )}
          <MessageStatusBadge status={row.status} />
        </div>
      </div>

      <div className="min-w-0">
        <h3 className="line-clamp-1 font-semibold group-hover:text-primary">{row.title}</h3>
        <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{row.body}</p>
      </div>

      <AudienceChips kind={row.audience.kind} names={row.audienceNames} max={3} />

      <div className="mt-auto border-t pt-3">
        {row.status === 'SENT' ? (
          <DeliveryStats stats={row.stats} />
        ) : (
          <p className="text-xs text-muted-foreground">
            {t('messages.card.recipients')}: <span className="font-semibold text-foreground">{tc('messages.recipientsCount', row.stats.recipients)}</span>
          </p>
        )}
        <p className="mt-3 truncate text-2xs text-muted-foreground">{t('messages.card.by', { name: row.authorName })}</p>
      </div>
    </Card>
  );
}

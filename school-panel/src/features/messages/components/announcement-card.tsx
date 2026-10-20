'use client';

import { CalendarClock, FileText, Send, Star } from 'lucide-react';

import { StaffAvatar } from '@/components/common/staff-avatar';
import { MessageStatusBadge } from '@/components/common/status-badges';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import type { AnnouncementRow } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ICON_TONES, type IconTone, WARM_GLOW } from '../styles';
import { AudienceChips } from './audience-chips';
import { DeliveryStats } from './delivery-stats';

const DATE_PATTERN = 'd MMM, HH:mm';
const STATUS_VISUAL = {
  SENT: { icon: Send, tone: 'cyan' },
  SCHEDULED: { icon: CalendarClock, tone: 'primary' },
  DRAFT: { icon: FileText, tone: 'muted' },
} as const satisfies Record<AnnouncementRow['status'], { icon: typeof Send; tone: IconTone }>;

/** Xabar kartochkasi: holat, auditoriya va (yuborilgan bo'lsa) yetkazish/o'qilish ulushi. */
export function AnnouncementCard({ row, onOpen }: { row: AnnouncementRow; onOpen: (id: string) => void }) {
  const { t, tc, formatDate } = useI18n();
  const { icon: StatusIcon, tone } = STATUS_VISUAL[row.status];
  const important = row.priority === 'IMPORTANT';
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
      className="card-glow group relative flex cursor-pointer flex-col overflow-hidden outline-none animate-fade-in focus-visible:ring-2 focus-visible:ring-ring"
    >
      {important && <div aria-hidden className={WARM_GLOW} />}
      <div className="relative flex flex-1 flex-col gap-4 p-5">
        <div className="flex items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-2.5 text-xs text-muted-foreground">
            <span className={cn('flex h-8 w-8 shrink-0 items-center justify-center rounded-lg', ICON_TONES[tone])}>
              <StatusIcon className="h-4 w-4" />
            </span>
            <span className="truncate">{when}</span>
          </div>
          <div className="flex shrink-0 items-center gap-1.5">
            {important && (
              <Badge variant="warning" className="gap-1">
                <Star className="h-3 w-3 fill-current" />
                <span className="hidden sm:inline">{t('enums.messagePriority.IMPORTANT')}</span>
              </Badge>
            )}
            <MessageStatusBadge status={row.status} />
          </div>
        </div>

        <div className="min-w-0">
          <h3 className="line-clamp-1 text-[0.95rem] font-semibold tracking-[-0.005em] transition-colors group-hover:text-primary">{row.title}</h3>
          <p className="mt-1.5 line-clamp-2 text-sm leading-relaxed text-muted-foreground">{row.body}</p>
        </div>

        <AudienceChips kind={row.audience.kind} names={row.audienceNames} max={3} />

        <div className="mt-auto space-y-3 border-t border-border/50 pt-4 dark:border-white/[0.06]">
          {row.status === 'SENT' ? (
            <DeliveryStats stats={row.stats} />
          ) : (
            <p className="text-xs text-muted-foreground">
              {t('messages.card.recipients')}: <span className="font-semibold text-foreground">{tc('messages.recipientsCount', row.stats.recipients)}</span>
            </p>
          )}
          <div className="flex min-w-0 items-center gap-2">
            <StaffAvatar staffId={row.byStaffId} name={row.authorName} size="xs" />
            <span className="truncate text-xs text-muted-foreground">{t('messages.card.by', { name: row.authorName })}</span>
          </div>
        </div>
      </div>
    </Card>
  );
}

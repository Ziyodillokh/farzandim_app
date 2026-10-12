'use client';

import { CalendarClock, Pencil, Repeat, Trash2 } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import type { ReminderRow } from '@/data/mock/services/comms';
import { AudienceChips } from '@/features/messages/components/audience-chips';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { KindIcon } from './kind-icon';

/** Smart Reminder kartochkasi: tur, vaqt, takrorlanish, auditoriya va faollik tugmasi. */
export function ReminderCard({
  row,
  onEdit,
  onDelete,
  onToggle,
  toggling,
}: {
  row: ReminderRow;
  onEdit: (row: ReminderRow) => void;
  onDelete: (row: ReminderRow) => void;
  onToggle: (row: ReminderRow, active: boolean) => void;
  toggling?: boolean;
}) {
  const { t, tc, formatDate, formatRelative } = useI18n();
  const at = row.nextAt ?? row.sendAt;
  const muted = !row.active || row.isPast;

  return (
    <Card className={cn('card-glow flex flex-col gap-4 p-5 animate-fade-in sm:flex-row sm:items-start', muted && 'opacity-80')}>
      <KindIcon kind={row.kind} className={cn(!row.active && 'grayscale')} />
      <div className="min-w-0 flex-1 space-y-2">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="font-semibold">{row.title}</h3>
          <Badge variant="outline" size="sm">
            {t(`enums.reminderKind.${row.kind}`)}
          </Badge>
          {row.repeat !== 'NONE' && (
            <Badge variant="info" size="sm" className="gap-1">
              <Repeat className="h-3 w-3" />
              {t(`enums.reminderRepeat.${row.repeat}`)}
            </Badge>
          )}
          {!row.active && !row.isPast && (
            <Badge variant="secondary" size="sm">
              {t('reminders.card.paused')}
            </Badge>
          )}
        </div>
        <p className="line-clamp-2 text-sm text-muted-foreground">{row.body}</p>
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-muted-foreground">
          <span className="inline-flex items-center gap-1.5 font-medium text-foreground">
            <CalendarClock className="h-3.5 w-3.5 text-primary" />
            {row.isPast ? t('reminders.card.sentAt', { date: formatDate(at, 'd MMMM, HH:mm') }) : formatDate(at, 'd MMMM, EEEE · HH:mm')}
          </span>
          {!row.isPast && <span>{formatRelative(at)}</span>}
          <span>{tc('messages.recipientsCount', row.recipients)}</span>
        </div>
        <AudienceChips kind={row.audience.kind} names={row.audienceNames} max={4} />
      </div>
      <div className="flex shrink-0 items-center gap-1 sm:flex-col sm:items-end sm:gap-3">
        {!row.isPast && (
          <label className="flex items-center gap-2 text-xs text-muted-foreground">
            {row.active ? t('reminders.card.active') : t('reminders.card.paused')}
            <Switch checked={row.active} disabled={toggling} onCheckedChange={(active) => onToggle(row, active)} aria-label={t('reminders.card.toggle')} />
          </label>
        )}
        <div className="ml-auto flex gap-1 sm:ml-0">
          <Button variant="ghost" size="icon-sm" onClick={() => onEdit(row)} aria-label={t('reminders.actions.edit')}>
            <Pencil />
          </Button>
          <Button variant="ghost" size="icon-sm" className="text-destructive hover:text-destructive" onClick={() => onDelete(row)} aria-label={t('reminders.actions.delete')}>
            <Trash2 />
          </Button>
        </div>
      </div>
    </Card>
  );
}

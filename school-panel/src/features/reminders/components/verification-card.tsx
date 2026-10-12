'use client';

import { CalendarClock, CircleCheck, Quote, Reply } from 'lucide-react';

import { VerificationBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import type { VerificationRow } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';

/** Tekshiruv so'rovi: ota-ona xabari, bog'liq eslatma va maktab javobi. */
export function VerificationCard({ row, onAnswer, onClose }: { row: VerificationRow; onAnswer: (row: VerificationRow) => void; onClose: (row: VerificationRow) => void }) {
  const { t, tc, formatDate, formatRelative } = useI18n();
  const open = row.status !== 'CLOSED';

  return (
    <Card className={cn('flex flex-col gap-4 p-5 animate-fade-in', row.status === 'OPEN' && 'border-l-4 border-l-warning', row.status === 'CLOSED' && 'opacity-75')}>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <Avatar className="h-10 w-10">
            <AvatarFallback className="bg-primary/10 text-xs font-semibold text-primary">{initials(row.guardianName)}</AvatarFallback>
          </Avatar>
          <div className="min-w-0">
            <p className="truncate font-semibold">{row.guardianName}</p>
            <p className="text-xs text-muted-foreground tabular-nums">{row.phone}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-xs text-muted-foreground" title={formatDate(row.createdAt, 'd MMMM yyyy, HH:mm')}>
            {formatRelative(row.createdAt)}
          </span>
          <VerificationBadge status={row.status} />
        </div>
      </div>

      <div className="flex flex-wrap gap-1.5">
        {row.children.map((c) => (
          <Badge key={c.id} variant="outline" className="font-normal">
            {c.name} <span className="text-muted-foreground">· {c.className}</span>
          </Badge>
        ))}
      </div>

      <blockquote className="relative rounded-xl bg-muted/60 p-4 pl-11 text-sm leading-relaxed">
        <Quote className="absolute left-4 top-4 h-4 w-4 text-muted-foreground/60" />
        {row.message}
      </blockquote>

      {row.payment && (
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs">
          <span className="font-semibold uppercase tracking-wider text-muted-foreground">{t('reminders.verifications.related')}</span>
          <span className="inline-flex items-center gap-1.5">
            <CalendarClock className="h-3.5 w-3.5 text-primary" />
            {t('reminders.verifications.nextDate')}: <span className="font-semibold tabular-nums">{formatDate(row.payment.nextDate, 'd MMMM yyyy')}</span>
          </span>
          {row.payment.prepaidMonths > 0 && (
            <Badge variant="success" size="sm">
              {t('reminders.verifications.prepaid')}: {tc('reminders.payments.prepaidMonths', row.payment.prepaidMonths)}
            </Badge>
          )}
          {row.payment.paused && (
            <Badge variant="secondary" size="sm">
              {t('reminders.verifications.paused')}
            </Badge>
          )}
        </div>
      )}

      {row.answer && (
        <div className="rounded-xl border border-success/25 bg-success/[0.06] p-4">
          <p className="flex items-center gap-1.5 text-xs font-semibold text-success">
            <CircleCheck className="h-3.5 w-3.5" />
            {t('reminders.verifications.schoolAnswer')}
          </p>
          <p className="mt-1.5 text-sm leading-relaxed">{row.answer}</p>
          {row.answeredAt && (
            <p className="mt-2 text-2xs text-muted-foreground">{t('reminders.verifications.answeredBy', { name: row.answeredByName ?? '—', date: formatDate(row.answeredAt, 'd MMM, HH:mm') })}</p>
          )}
        </div>
      )}

      {open && (
        <div className="flex flex-wrap justify-end gap-2 border-t pt-4">
          <Button variant="ghost" size="sm" onClick={() => onClose(row)}>
            {t('reminders.verifications.close')}
          </Button>
          <Button size="sm" variant={row.status === 'OPEN' ? 'default' : 'outline'} onClick={() => onAnswer(row)}>
            <Reply />
            {t('reminders.verifications.answer')}
          </Button>
        </div>
      )}
    </Card>
  );
}

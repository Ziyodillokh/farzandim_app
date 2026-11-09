'use client';

import { CalendarClock, CircleCheck, ExternalLink, Quote, Receipt, Reply } from 'lucide-react';
import { useState } from 'react';

import { StaffAvatar } from '@/components/common/staff-avatar';
import { VerificationBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import type { VerificationRow } from '@/data/mock/services/comms';
import { INNER_TILE, WARM_GLOW } from '@/features/messages/styles';
import { useI18n } from '@/i18n';
import { withBase } from '@/lib/base-path';
import { cn, initials } from '@/lib/utils';

/** Backend — to'liq imzolangan havola; demo — `public/` yo'li (basePath bilan). */
const receiptSrc = (url: string) => (/^https?:\/\//.test(url) ? url : withBase(url));

/** Onlayn to'lov cheki: kichik rasm, bosilsa kattalashadi. */
function ReceiptPreview({ url }: { url: string }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const src = receiptSrc(url);
  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(INNER_TILE, 'group flex w-full items-center gap-4 p-3 text-left transition-colors hover:bg-primary/[0.05]')}
        aria-label={t('reminders.verifications.receiptOpen')}
        data-testid="verification-receipt"
      >
        {/* eslint-disable-next-line @next/next/no-img-element -- statik eksport, imzolangan proksi havola */}
        <img src={src} alt="" loading="lazy" className="h-24 w-16 shrink-0 rounded-lg object-cover object-top ring-1 ring-border/60" />
        <span className="min-w-0">
          <span className="flex items-center gap-1.5 text-sm font-semibold">
            <Receipt className="h-4 w-4 text-primary" />
            {t('reminders.verifications.receipt')}
          </span>
          <span className="mt-0.5 block text-xs text-muted-foreground">{t('reminders.verifications.receiptHint')}</span>
          <span className="mt-1.5 block text-xs font-medium text-primary group-hover:underline">{t('reminders.verifications.receiptOpen')}</span>
        </span>
      </button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{t('reminders.verifications.receipt')}</DialogTitle>
            <DialogDescription>{t('reminders.verifications.receiptHint')}</DialogDescription>
          </DialogHeader>
          {/* eslint-disable-next-line @next/next/no-img-element -- statik eksport, imzolangan proksi havola */}
          <img src={src} alt={t('reminders.verifications.receipt')} className="max-h-[70vh] w-full rounded-xl object-contain ring-1 ring-border/60" />
          <a href={src} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline">
            <ExternalLink className="h-4 w-4" />
            {t('reminders.verifications.receiptNewTab')}
          </a>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** Tekshiruv so'rovi: ota-ona xabari, bog'liq eslatma va maktab javobi. */
export function VerificationCard({ row, onAnswer, onClose }: { row: VerificationRow; onAnswer: (row: VerificationRow) => void; onClose: (row: VerificationRow) => void }) {
  const { t, tc, formatDate, formatRelative } = useI18n();
  const isOpen = row.status === 'OPEN';
  const canAct = row.status !== 'CLOSED';

  return (
    <Card className="relative overflow-hidden animate-fade-in">
      {isOpen && <div aria-hidden className={WARM_GLOW} />}
      <div className={cn('relative flex flex-col gap-4 p-5', row.status === 'CLOSED' && 'opacity-75')}>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex min-w-0 items-center gap-3">
            <Avatar className="h-10 w-10">
              <AvatarFallback className="bg-gradient-to-br from-sky-400/25 to-brand-500/25 text-xs font-semibold text-primary ring-1 ring-inset ring-primary/20">
                {initials(row.guardianName)}
              </AvatarFallback>
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

        <blockquote className={cn(INNER_TILE, 'relative p-4 pl-11 text-sm leading-relaxed')}>
          <Quote className="absolute left-4 top-4 h-4 w-4 text-primary/50" />
          {row.message}
        </blockquote>

        {row.receiptUrl && <ReceiptPreview url={row.receiptUrl} />}

        {row.payment && (
          <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs">
            <span className="text-2xs font-semibold uppercase tracking-wider text-muted-foreground">{t('reminders.verifications.related')}</span>
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
          <div className="rounded-xl bg-primary/[0.06] p-4 ring-1 ring-inset ring-primary/20 dark:bg-primary/[0.1]">
            <p className="flex items-center gap-1.5 text-xs font-semibold text-primary">
              <CircleCheck className="h-3.5 w-3.5" />
              {t('reminders.verifications.schoolAnswer')}
            </p>
            <p className="mt-1.5 text-sm leading-relaxed">{row.answer}</p>
            {row.answeredAt && (
              <div className="mt-2.5 flex items-center gap-2 text-2xs text-muted-foreground">
                <StaffAvatar staffId={row.answeredByStaffId} name={row.answeredByName ?? undefined} size="xs" />
                {t('reminders.verifications.answeredBy', { name: row.answeredByName ?? '—', date: formatDate(row.answeredAt, 'd MMM, HH:mm') })}
              </div>
            )}
          </div>
        )}

        {canAct && (
          <div className="flex flex-wrap justify-end gap-2 border-t border-border/50 pt-4 dark:border-white/[0.06]">
            <Button variant="ghost" size="sm" onClick={() => onClose(row)}>
              {t('reminders.verifications.close')}
            </Button>
            <Button size="sm" variant={isOpen ? 'default' : 'outline'} onClick={() => onAnswer(row)}>
              <Reply />
              {t('reminders.verifications.answer')}
            </Button>
          </div>
        )}
      </div>
    </Card>
  );
}

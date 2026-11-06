'use client';

import { CircleCheck, Clock, Quote } from 'lucide-react';
import Link from 'next/link';

import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import type { LinkRequest } from '@/data/contracts';
import { INNER_TILE } from '@/features/classes/styles';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';
import type { LinkDecision } from '../hooks';

/** Bitta ulanish so'rovi: o'quvchi, sinf, vaqt, (tekshiruv) ota-ona kodi holati yoki (tuzatish) bolaning izohi + amallar. */
export function RequestCard({ request, onDecide }: { request: LinkRequest; onDecide: (request: LinkRequest, decision: LinkDecision) => void }) {
  const { t, formatDate, formatRelative } = useI18n();
  const correction = request.kind === 'CORRECTION';

  // Telefonda amallar mazmun ostida (ustun), kengroq ekranda o'ngda (qator). `flex-1` + `flex-wrap` birga ishlatilsa
  // mazmun 0 gacha siqilib ketadi (flex-basis 0) — shuning uchun ustun/qator almashinuvi `sm:` bilan.
  return (
    <li className={cn('flex flex-col gap-4 p-4 sm:flex-row sm:items-start sm:justify-between', INNER_TILE)} data-testid="link-request" data-kind={request.kind}>
      <div className="flex min-w-0 flex-1 gap-3">
        <Avatar className="h-10 w-10">
          <AvatarFallback className="bg-gradient-to-br from-brand-400 to-brand-800 text-2xs font-semibold text-white">{initials(request.studentName)}</AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1 space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            {request.studentId ? (
              <Link
                href={`/students/view?id=${encodeURIComponent(request.studentId)}`}
                title={t('linkRequests.openStudent')}
                className="font-semibold hover:text-primary hover:underline focus-visible:rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                {request.studentName}
              </Link>
            ) : (
              <span className="font-semibold">{request.studentName}</span>
            )}
            <Badge variant="outline">{request.className}</Badge>
          </div>
          <p className="text-xs text-muted-foreground">
            {t('linkRequests.requested', { time: formatRelative(request.createdAt) })} ·{' '}
            <time dateTime={request.createdAt}>{formatDate(request.createdAt, 'dd.MM.yyyy, HH:mm')}</time>
          </p>
          {correction ? (
            <div className="space-y-1.5">
              {request.reason && (
                <Badge variant="warning" size="sm">
                  {t(`linkRequests.correction.reason.${request.reason}`)}
                </Badge>
              )}
              <figure className="flex gap-2 rounded-lg bg-muted/60 p-3 text-sm dark:bg-white/[0.04]">
                <Quote className="mt-0.5 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
                <div className="min-w-0">
                  <figcaption className="text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{t('linkRequests.correction.note')}</figcaption>
                  <blockquote className="mt-1 whitespace-pre-wrap break-words" data-testid="link-request-note">
                    {request.note ?? <span className="text-muted-foreground">{t('linkRequests.correction.noNote')}</span>}
                  </blockquote>
                </div>
              </figure>
            </div>
          ) : (
            <Badge variant={request.parentUsed ? 'success' : 'warning'} size="sm" className="gap-1.5">
              {request.parentUsed ? <CircleCheck className="h-3 w-3" aria-hidden /> : <Clock className="h-3 w-3" aria-hidden />}
              {t(request.parentUsed ? 'linkRequests.parentCode.used' : 'linkRequests.parentCode.pending')}
            </Badge>
          )}
        </div>
      </div>
      <div className="flex gap-2 sm:shrink-0">
        <Button size="sm" variant="outline" className="flex-1 text-destructive hover:text-destructive sm:flex-none" onClick={() => onDecide(request, 'reject')}>
          {t(correction ? 'linkRequests.correction.unlink' : 'linkRequests.review.reject')}
        </Button>
        <Button size="sm" className="flex-1 sm:flex-none" onClick={() => onDecide(request, 'confirm')}>
          {t(correction ? 'linkRequests.correction.keep' : 'linkRequests.review.confirm')}
        </Button>
      </div>
    </li>
  );
}

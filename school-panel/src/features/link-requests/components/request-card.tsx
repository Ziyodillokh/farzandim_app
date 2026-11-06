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
import { DECISION_ORDER, LINK_ACTIONS, type LinkDecision } from '../lib/decisions';

/**
 * Bitta ulanish so'rovi: o'quvchi, sinf, bola profilidagi ism (ota-ona bergan — xodim qaror qilishiga yordam beradi), vaqt,
 * ishonch belgisi (bolaning ota-onasi o'quvchiga ulanganmi), tuzatishda bolaning izohi va amallar.
 * Tugmalar `LINK_ACTIONS` jadvalidan: CORRECTION'da «Ulanishni saqlash» = `confirm`, «Ulanishni uzish» = `reject`.
 */
export function RequestCard({ request, onDecide }: { request: LinkRequest; onDecide: (request: LinkRequest, decision: LinkDecision) => void }) {
  const { t, formatDate, formatRelative } = useI18n();
  const { student, child, parent } = request;
  const correction = request.kind === 'CORRECTION';
  const guardian = request.kind === 'GUARDIAN';
  // Bir xil nomli tugmalar qaysi o'quvchiga tegishli ekanini ekran o'qish dasturi ham bilsin (aria-describedby).
  // Id'da ":" bor (REVIEW: `<kod>:<bola>`) — `aria-describedby` uchun bu yaroqli, lekin CSS selektor emas.
  const whoId = `link-request-${request.id}-who`;

  // Telefonda amallar mazmun ostida (ustun), kengroq ekranda o'ngda (qator). `flex-1` + `flex-wrap` birga ishlatilsa
  // mazmun 0 gacha siqilib ketadi (flex-basis 0) — shuning uchun ustun/qator almashinuvi `sm:` bilan.
  return (
    <li className={cn('flex flex-col gap-4 p-4 sm:flex-row sm:items-start sm:justify-between', INNER_TILE)} data-testid="link-request" data-kind={request.kind}>
      <div className="flex min-w-0 flex-1 gap-3">
        <Avatar className="h-10 w-10">
          <AvatarFallback className="bg-gradient-to-br from-brand-400 to-brand-800 text-2xs font-semibold text-white">{initials(student.fullName)}</AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1 space-y-2">
          <div id={whoId} className="flex flex-wrap items-center gap-2">
            <Link
              href={`/students/view?id=${encodeURIComponent(student.id)}`}
              title={t('linkRequests.openStudent')}
              className="font-semibold hover:text-primary hover:underline focus-visible:rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              {student.fullName}
            </Link>
            {student.className && <Badge variant="outline">{student.className}</Badge>}
          </div>
          {guardian && parent && (
            <p className="text-sm" data-testid="link-request-guardian">
              {t('linkRequests.guardian.who', { name: parent.name, phone: parent.maskedPhone ?? t('linkRequests.guardian.noPhone') })}
            </p>
          )}
          {child && (
            <p className="text-sm text-muted-foreground" data-testid="link-request-child">
              {t(guardian ? 'linkRequests.guardian.child' : 'linkRequests.childName', { name: child.name })}
            </p>
          )}
          <p className="text-xs text-muted-foreground">
            {t('linkRequests.requested', { time: formatRelative(request.createdAt) })} ·{' '}
            <time dateTime={request.createdAt}>{formatDate(request.createdAt, 'dd.MM.yyyy, HH:mm')}</time>
          </p>
          {!guardian && (
            <Badge variant={request.parentLinked ? 'success' : 'warning'} size="sm" className="gap-1.5" data-testid="link-request-parent">
              {request.parentLinked ? <CircleCheck className="h-3 w-3" aria-hidden /> : <Clock className="h-3 w-3" aria-hidden />}
              {t(request.parentLinked ? 'linkRequests.parent.linked' : 'linkRequests.parent.notLinked')}
            </Badge>
          )}
          {correction && (
            <div className="space-y-1.5">
              {request.reason && (
                <Badge variant="warning" size="sm">
                  {t(`linkRequests.correction.reason.${request.reason}`)}
                </Badge>
              )}
              <figure className="rounded-lg bg-muted/60 p-3 text-sm dark:bg-white/[0.04]">
                <figcaption className="flex items-center gap-1.5 text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">
                  <Quote className="h-3.5 w-3.5 shrink-0" aria-hidden />
                  {t('linkRequests.correction.note')}
                </figcaption>
                <blockquote className="mt-1 whitespace-pre-wrap break-words" data-testid="link-request-note">
                  {request.note ?? <span className="text-muted-foreground">{t('linkRequests.correction.noNote')}</span>}
                </blockquote>
              </figure>
            </div>
          )}
        </div>
      </div>
      <div className="flex gap-2 sm:shrink-0">
        {DECISION_ORDER.map((decision) => {
          const action = LINK_ACTIONS[request.kind][decision];
          return (
            <Button
              key={decision}
              size="sm"
              variant={action.destructive ? 'outline' : 'default'}
              className={cn('flex-1 sm:flex-none', action.destructive && 'text-destructive hover:text-destructive')}
              aria-describedby={whoId}
              data-decision={decision}
              onClick={() => onDecide(request, decision)}
            >
              {t(action.label)}
            </Button>
          );
        })}
      </div>
    </li>
  );
}

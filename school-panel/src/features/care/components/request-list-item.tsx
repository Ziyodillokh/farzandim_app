'use client';

import { CalendarClock, ChevronRight, NotebookPen, ShieldAlert } from 'lucide-react';
import Link from 'next/link';

import { CareStatusBadge, UrgencyBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import type { CareRequestRow } from '@/data/mock/services/care';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';
import { Card } from '@/components/ui/card';

/** Murojaatlar qutisidagi bitta qator (faqat psixolog ko'radi). */
export function RequestListItem({ request }: { request: CareRequestRow }) {
  const { t, tc, formatDate, formatRelative } = useI18n();
  const urgentOpen = request.urgency === 'URGENT' && request.status !== 'RESOLVED';
  return (
    <li>
      <Link href={`/care/requests/view?id=${request.id}`} className="group block rounded-2xl focus-visible:outline-none">
        <Card
          className={cn(
            'relative flex items-start gap-4 overflow-hidden p-4 transition-all group-hover:-translate-y-px group-hover:shadow-glass-lg',
            urgentOpen && 'ring-1 ring-inset ring-destructive/25',
          )}
        >
          {urgentOpen && <span aria-hidden className="absolute inset-y-3 left-0 w-1 rounded-r-full bg-destructive/70" />}
        <Avatar className="h-10 w-10">
          <AvatarFallback className="bg-gradient-to-br from-sky-100 to-brand-200 text-xs font-semibold text-brand-800 dark:from-brand-800/60 dark:to-brand-900/60 dark:text-brand-100">{initials(request.studentName)}</AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="font-semibold">{request.studentName}</p>
            <Badge variant="outline" size="sm">{request.className}</Badge>
            <UrgencyBadge urgency={request.urgency} />
            <Badge variant="secondary" size="sm">{t(`enums.careTopicTag.${request.topic}`)}</Badge>
            <span className="ml-auto whitespace-nowrap text-xs text-muted-foreground" title={formatDate(request.createdAt, 'd MMMM, HH:mm')}>
              {formatRelative(request.createdAt)}
            </span>
          </div>
          <p className="mt-1.5 line-clamp-2 text-sm text-foreground/80">«{request.message}»</p>
          <div className="mt-2.5 flex flex-wrap items-center gap-x-4 gap-y-1.5 text-xs text-muted-foreground">
            <CareStatusBadge status={request.status} />
            {request.meetingAt && (
              <span className="flex items-center gap-1">
                <CalendarClock className="h-3.5 w-3.5" />
                {t('care.requests.meetingAt', { date: formatDate(request.meetingAt, 'd MMM, HH:mm') })}
              </span>
            )}
            {request.notes.length > 0 && (
              <span className="flex items-center gap-1">
                <NotebookPen className="h-3.5 w-3.5" />
                {tc('care.requests.notesCount', request.notes.length)}
              </span>
            )}
            {request.protocolActivated && (
              <span className="flex items-center gap-1 font-medium text-destructive">
                <ShieldAlert className="h-3.5 w-3.5" />
                {t('care.requests.protocolActive')}
              </span>
            )}
          </div>
        </div>
        <ChevronRight className="mt-2 h-4 w-4 shrink-0 text-muted-foreground transition-all group-hover:translate-x-0.5 group-hover:text-primary" />
        </Card>
      </Link>
    </li>
  );
}

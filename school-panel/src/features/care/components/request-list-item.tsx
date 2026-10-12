'use client';

import { CalendarClock, ChevronRight, NotebookPen, ShieldAlert } from 'lucide-react';
import Link from 'next/link';

import { CareStatusBadge, UrgencyBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import type { CareRequestRow } from '@/data/mock/services/care';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';

/** Murojaatlar qutisidagi bitta qator (faqat psixolog ko'radi). */
export function RequestListItem({ request }: { request: CareRequestRow }) {
  const { t, tc, formatDate, formatRelative } = useI18n();
  const urgentOpen = request.urgency === 'URGENT' && request.status !== 'RESOLVED';
  return (
    <li>
      <Link
        href={`/care/requests/view?id=${request.id}`}
        className={cn(
          'group flex items-start gap-4 rounded-xl border bg-card p-4 shadow-soft transition-all hover:-translate-y-px hover:border-primary/30 hover:shadow-soft-lg',
          urgentOpen && 'border-destructive/30 bg-destructive/[0.03]',
        )}
      >
        <Avatar className="h-10 w-10">
          <AvatarFallback className="bg-primary/10 text-xs font-semibold text-primary">{initials(request.studentName)}</AvatarFallback>
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
        <ChevronRight className="mt-2 h-4 w-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
      </Link>
    </li>
  );
}

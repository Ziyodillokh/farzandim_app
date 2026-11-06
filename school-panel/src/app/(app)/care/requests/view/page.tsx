'use client';

import { ArrowUpRight, CalendarClock, Clock3, Eye, EyeOff, MessageSquareQuote, ShieldAlert, Tag, UserRound, UserRoundCheck } from 'lucide-react';
import { useSearchParams } from 'next/navigation';
import { Suspense, type ReactNode } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SectionCard } from '@/components/common/section-card';
import { CareStatusBadge, UrgencyBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { ServiceError } from '@/data/contracts';
import { ConfidentialityCard } from '@/features/care/components/confidentiality-card';
import { RequestActions } from '@/features/care/components/request-actions';
import { RequestThread } from '@/features/care/components/request-thread';
import { RequestTimeline } from '@/features/care/components/request-timeline';
import { useCareRequest } from '@/features/care/hooks';
import { ICON_CHIP, TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';

export default function CareRequestViewPage() {
  return (
    <Suspense fallback={<ViewSkeleton />}>
      <RequestView />
    </Suspense>
  );
}

function ViewSkeleton() {
  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <Skeleton className="h-64 rounded-2xl lg:col-span-2" />
      <Skeleton className="h-64 rounded-2xl" />
    </div>
  );
}

function Detail({ icon, label, children }: { icon: ReactNode; label: string; children: ReactNode }) {
  return (
    <div className="flex items-start gap-3">
      <span className={cn(ICON_CHIP, 'h-8 w-8 rounded-lg bg-primary/[0.07] text-primary/80 ring-primary/10 [&_svg]:size-4')}>{icon}</span>
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <div className="text-sm font-medium">{children}</div>
      </div>
    </div>
  );
}

function RequestView() {
  const { t, formatDate } = useI18n();
  const id = useSearchParams().get('id');
  const query = useCareRequest(id);
  const request = query.data;
  const back = { backHref: '/care/requests', backLabel: t('care.request.back') };

  if (!id || (query.error instanceof ServiceError && query.error.code === 'NOT_FOUND')) {
    return (
      <>
        <PageHeader title={t('care.request.title')} {...back} />
        <EmptyState icon={<MessageSquareQuote />} title={t('care.request.notFound')} />
      </>
    );
  }
  if (query.error) {
    return (
      <>
        <PageHeader title={t('care.request.title')} {...back} />
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      </>
    );
  }
  if (!request) {
    return (
      <>
        <PageHeader title={t('care.request.title')} {...back} />
        <ViewSkeleton />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title={t('care.request.title')}
        {...back}
        badge={
          <div className="flex flex-wrap items-center gap-2">
            <UrgencyBadge urgency={request.urgency} />
            <CareStatusBadge status={request.status} />
            {request.assignedTo && (
              <Badge variant="outline" data-testid="handler-badge">
                {request.escalatedAt ? <UserRoundCheck className="h-3 w-3" aria-hidden /> : <UserRound className="h-3 w-3" aria-hidden />}
                {t('care.requests.assignedTo', { name: request.assignedTo.name })}
              </Badge>
            )}
            {request.escalatedAt && (
              <Badge variant="warning" data-testid="escalated-badge">
                <ArrowUpRight className="h-3 w-3" aria-hidden />
                {t('care.request.escalatedBadge')}
              </Badge>
            )}
          </div>
        }
      />

      {request.protocolActivated && (
        <div className="mb-6 flex items-start gap-3 rounded-2xl bg-destructive/[0.05] p-4 ring-1 ring-inset ring-destructive/20 animate-fade-in">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-destructive/10 text-destructive">
            <ShieldAlert className="h-[18px] w-[18px]" />
          </span>
          <div className="text-sm">
            <p className="font-semibold text-destructive">{t('care.request.protocol.activeTitle')}</p>
            {request.notified.length > 0 && (
              <p className="mt-0.5 text-foreground/80">
                {t('care.request.protocol.notified', {
                  names: request.notified.map((n) => `${n.name} (${t(`enums.role.${n.role}`).toLowerCase()})`).join(', '),
                })}
              </p>
            )}
            <p className="mt-0.5 text-muted-foreground">{t('care.request.protocol.noDetails')}</p>
          </div>
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <RequestThread request={request} />
          <RequestTimeline request={request} />
        </div>

        <div className="space-y-6">
          <SectionCard title={t('care.request.student')} icon={<UserRound />}>
            <div className={cn(TILE, 'mb-4 flex items-center gap-3 p-3')}>
              <Avatar className="h-12 w-12">
                <AvatarFallback className="bg-gradient-to-br from-sky-100 to-brand-200 font-semibold text-brand-800 dark:from-brand-800/60 dark:to-brand-900/60 dark:text-brand-100">{initials(request.studentName)}</AvatarFallback>
              </Avatar>
              <div className="min-w-0">
                <p className="truncate font-semibold">{request.studentName}</p>
                <Badge variant="outline" size="sm" className="mt-1">{request.className}</Badge>
              </div>
            </div>
            <div className="space-y-3.5">
              <Detail icon={<Clock3 />} label={t('care.request.received')}>
                {formatDate(request.createdAt, 'd MMMM yyyy, HH:mm')}
              </Detail>
              <Detail icon={<Tag />} label={t('care.request.topic')}>
                {t(`enums.careTopicTag.${request.topic}`)}
              </Detail>
              <Detail icon={<ShieldAlert />} label={t('care.request.urgency')}>
                {t(`enums.careUrgency.${request.urgency}`)}
              </Detail>
              <Detail icon={<CalendarClock />} label={t('care.request.meeting')}>
                {request.meetingAt ? formatDate(request.meetingAt, 'd MMMM, EEEE, HH:mm') : t('care.request.noMeeting')}
              </Detail>
              <Detail icon={<UserRound />} label={t('care.request.handler')}>
                {request.assignedTo?.name ?? t('care.request.unassigned')}
              </Detail>
              <Detail icon={request.openedAt ? <Eye /> : <EyeOff />} label={t('care.request.openedAt')}>
                {request.openedAt
                  ? `${formatDate(request.openedAt, 'd MMM, HH:mm')}${request.openedBy ? ` · ${request.openedBy.name}` : ''}`
                  : t('care.request.notOpened')}
              </Detail>
            </div>
          </SectionCard>
          <RequestActions request={request} />
          <ConfidentialityCard />
        </div>
      </div>
    </>
  );
}

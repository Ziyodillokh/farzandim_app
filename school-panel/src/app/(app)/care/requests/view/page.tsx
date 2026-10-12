'use client';

import { CalendarClock, Clock3, MessageSquareQuote, ShieldAlert, Tag } from 'lucide-react';
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
import { RequestTimeline } from '@/features/care/components/request-timeline';
import { useCareRequest } from '@/features/care/hooks';
import { useI18n } from '@/i18n';
import { initials } from '@/lib/utils';

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
      <Skeleton className="h-64 rounded-xl lg:col-span-2" />
      <Skeleton className="h-64 rounded-xl" />
    </div>
  );
}

function Detail({ icon, label, children }: { icon: ReactNode; label: string; children: ReactNode }) {
  return (
    <div className="flex items-start gap-3">
      <span className="mt-0.5 text-muted-foreground [&_svg]:size-4">{icon}</span>
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <div className="text-sm font-medium">{children}</div>
      </div>
    </div>
  );
}

function RequestView() {
  const { t, formatDate, formatRelative } = useI18n();
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
          <div className="flex items-center gap-2">
            <UrgencyBadge urgency={request.urgency} />
            <CareStatusBadge status={request.status} />
          </div>
        }
      />

      {request.protocolActivated && (
        <div className="mb-6 flex items-start gap-3 rounded-xl border border-destructive/25 bg-destructive/[0.05] p-4 animate-fade-in">
          <ShieldAlert className="mt-0.5 h-5 w-5 shrink-0 text-destructive" />
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
          <SectionCard title={t('care.request.message')}>
            <figure className="relative rounded-xl bg-gradient-to-br from-primary/[0.06] to-transparent p-5">
              <MessageSquareQuote className="absolute right-4 top-4 h-6 w-6 text-primary/20" aria-hidden />
              <blockquote className="pr-8 text-[0.95rem] leading-relaxed">«{request.message}»</blockquote>
              <figcaption className="mt-3 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                <Badge variant="secondary" size="sm">{t(`enums.careTopicTag.${request.topic}`)}</Badge>
                <span>{formatDate(request.createdAt, 'd MMMM, HH:mm')}</span>
                <span>· {formatRelative(request.createdAt)}</span>
              </figcaption>
            </figure>
          </SectionCard>
          <RequestTimeline request={request} />
        </div>

        <div className="space-y-6">
          <SectionCard title={t('care.request.student')}>
            <div className="mb-5 flex items-center gap-3">
              <Avatar className="h-12 w-12">
                <AvatarFallback className="bg-primary/10 font-semibold text-primary">{initials(request.studentName)}</AvatarFallback>
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
            </div>
          </SectionCard>
          <RequestActions request={request} />
          <ConfidentialityCard />
        </div>
      </div>
    </>
  );
}

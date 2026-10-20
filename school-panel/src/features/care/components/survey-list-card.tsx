'use client';

import { Hourglass, ListChecks } from 'lucide-react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { Badge, type BadgeProps } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import type { CareSurveyStatus } from '@/data/contracts';
import type { CareSurveySummary } from '@/data/mock/services/care';
import { ICON_CHIP, TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { CARE_MIN_GROUP } from '@/lib/k-anon';
import { cn } from '@/lib/utils';
import { useCareSurveySummaries } from '../hooks';
import { ageGroupsLabel, TOPIC_ICONS } from '../lib/labels';

const STATUS_VARIANT: Record<CareSurveyStatus, NonNullable<BadgeProps['variant']>> = { DRAFT: 'secondary', ACTIVE: 'info', CLOSED: 'outline' };
const SKELETON_ROWS = 3;

function Participation({ survey }: { survey: CareSurveySummary }) {
  const { t } = useI18n();
  const p = survey.participation;
  if (!p) {
    return (
      <p className="flex items-center gap-1.5 text-xs text-muted-foreground" title={t('care.surveyList.collectingHint', { k: CARE_MIN_GROUP })}>
        <Hourglass className="h-3.5 w-3.5 shrink-0 text-sky-500" aria-hidden />
        {t('care.surveyList.collecting')}
      </p>
    );
  }
  return (
    <div className="w-full sm:w-40">
      <div className="mb-1 flex items-baseline justify-between gap-2 text-xs tabular-nums">
        <span className="text-muted-foreground">{t('care.surveyList.participation')}</span>
        <span className="font-semibold">{p.rate}%</span>
      </div>
      <Progress value={p.rate} className="h-1.5" indicatorClassName="bg-gradient-to-r from-sky-400 to-primary" aria-label={t('care.surveyList.participation')} />
      <p className="mt-1 text-right text-2xs text-muted-foreground tabular-nums">
        {t('care.surveyList.participationValue', { respondents: p.respondents, invited: p.invited })}
      </p>
    </div>
  );
}

function SurveyRow({ survey }: { survey: CareSurveySummary }) {
  const { t, tc, formatDate } = useI18n();
  return (
    <li className={cn(TILE, 'flex flex-col gap-3 p-3 sm:flex-row sm:items-center')}>
      <div className="flex min-w-0 flex-1 items-start gap-3">
        <div className={cn(ICON_CHIP, 'w-11 flex-col bg-primary/10 py-1 text-primary ring-primary/15')}>
          <span className="font-display text-base font-semibold leading-tight">{formatDate(survey.weekStart, 'd')}</span>
          <span className="text-[0.62rem] font-medium uppercase tracking-wide">{formatDate(survey.weekStart, 'MMM')}</span>
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="min-w-0 truncate text-sm font-medium">{survey.title}</p>
            <Badge variant={STATUS_VARIANT[survey.status]} size="sm">
              {t(`enums.surveyStatus.${survey.status}`)}
            </Badge>
          </div>
          <p className="mt-0.5 text-xs text-muted-foreground">
            {tc('care.surveyList.questions', survey.questionCount)} · {ageGroupsLabel(t, survey.ageGroups)}
          </p>
          <ul className="mt-2 flex flex-wrap gap-1.5" aria-label={t('care.overview.topic')}>
            {survey.topics.map((topic) => {
              const Icon = TOPIC_ICONS[topic];
              return (
                <li key={topic} className="inline-flex items-center gap-1 rounded-full bg-sky-500/10 px-2 py-0.5 text-2xs font-medium text-sky-700 ring-1 ring-inset ring-sky-500/20 dark:text-sky-300">
                  <Icon className="h-3 w-3" aria-hidden />
                  {t(`enums.careTopic.${topic}`)}
                </li>
              );
            })}
          </ul>
        </div>
      </div>
      <Participation survey={survey} />
    </li>
  );
}

/** Direktor/admin uchun so'rovnomalar ro'yxati (faqat o'qish): sarlavha, hafta, mavzular; ishtirok faqat k ≥ 5. */
export function SurveyListCard({ className }: { className?: string }) {
  const { t } = useI18n();
  const summaries = useCareSurveySummaries();

  const body = () => {
    if (summaries.error) return <ErrorState error={summaries.error} onRetry={() => void summaries.refetch()} />;
    if (summaries.isLoading) {
      return (
        <div className="space-y-2">
          {Array.from({ length: SKELETON_ROWS }).map((_, i) => (
            <Skeleton key={i} className="h-20 rounded-xl" />
          ))}
        </div>
      );
    }
    if (!summaries.data?.length) return <EmptyState icon={<ListChecks />} title={t('care.surveyList.empty')} className="py-8" />;
    return (
      <ul className="space-y-2">
        {summaries.data.map((s) => (
          <SurveyRow key={s.id} survey={s} />
        ))}
      </ul>
    );
  };

  return (
    <SectionCard title={t('care.surveyList.title')} description={t('care.surveyList.hint')} icon={<ListChecks />} className={className} bodyClassName="p-3">
      {body()}
    </SectionCard>
  );
}

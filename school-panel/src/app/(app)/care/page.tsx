'use client';

import { ClipboardList, HeartHandshake, MessageSquareHeart, Smile } from 'lucide-react';
import { useState } from 'react';

import { useCan } from '@/auth/use-session';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { CareBreakdown } from '@/data/schemas/care';
import { BreakdownChart, type ChartTopic } from '@/features/care/components/breakdown-chart';
import { InsightsCard } from '@/features/care/components/insights-card';
import { PrivacyBanner } from '@/features/care/components/privacy-banner';
import { PsychologistLinks } from '@/features/care/components/psychologist-links';
import { TopicScoreCards } from '@/features/care/components/topic-score-cards';
import { TrendChart } from '@/features/care/components/trend-chart';
import { useCareAggregate, useCareSurveyOptions } from '@/features/care/hooks';
import { useI18n } from '@/i18n';

export default function CareOverviewPage() {
  const { t, formatDate, formatNumber } = useI18n();
  const can = useCan();
  const [surveyId, setSurveyId] = useState<string | undefined>();
  const [breakdown, setBreakdown] = useState<CareBreakdown>('CLASS');
  const [topic, setTopic] = useState<ChartTopic>('AVERAGE');
  const options = useCareSurveyOptions();
  const hasSurveys = (options.data?.length ?? 0) > 0;
  const aggregate = useCareAggregate({ surveyId, breakdown }, hasSurveys);
  const data = aggregate.data;
  const selectedId = surveyId ?? data?.surveyId ?? options.data?.[0]?.id;
  const loading = options.isLoading || aggregate.isLoading;

  const surveySelect = hasSurveys && (
    <Select value={selectedId} onValueChange={setSurveyId}>
      <SelectTrigger className="h-10 w-full sm:w-72" aria-label={t('care.overview.survey')}>
        <SelectValue placeholder={t('care.overview.survey')} />
      </SelectTrigger>
      <SelectContent>
        {options.data?.map((s) => (
          <SelectItem key={s.id} value={s.id}>
            <span className="flex items-center gap-2">
              {t('care.overview.weekOf', { date: formatDate(s.weekStart, 'd MMMM') })}
              {s.status === 'ACTIVE' && <Badge variant="success" size="sm">{t('enums.surveyStatus.ACTIVE')}</Badge>}
            </span>
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );

  const body = () => {
    if (options.error) return <ErrorState error={options.error} onRetry={() => void options.refetch()} />;
    if (!loading && !hasSurveys) {
      return <EmptyState icon={<HeartHandshake />} title={t('care.overview.noSurvey')} description={t('care.overview.noSurveyHint')} />;
    }
    if (aggregate.error) return <ErrorState error={aggregate.error} onRetry={() => void aggregate.refetch()} />;
    const wellbeing = data?.overall.WELLBEING;
    return (
      <div className="space-y-6">
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <StatCard
            icon={<ClipboardList />}
            label={t('care.overview.participation')}
            value={`${data?.participationRate ?? 0}%`}
            hint={t('care.overview.participationHint', { respondents: formatNumber(data?.respondents ?? 0), invited: formatNumber(data?.invited ?? 0) })}
            loading={loading}
            footer={!loading && <Progress value={data?.participationRate ?? 0} />}
          />
          <StatCard
            icon={<Smile />}
            tone="success"
            label={t('care.overview.wellbeing')}
            value={wellbeing === undefined ? '—' : `${wellbeing}`}
            hint={t('care.overview.wellbeingHint')}
            loading={loading}
          />
          <StatCard
            icon={<MessageSquareHeart />}
            tone="info"
            label={t('care.overview.requestsThisWeek')}
            value={data?.requestsThisWeek ?? '—'}
            hint={t('care.overview.requestsHint')}
            loading={loading}
          />
        </div>

        <section>
          <div className="mb-3">
            <h2 className="text-[0.95rem] font-semibold">{t('care.overview.topicsTitle')}</h2>
            <p className="text-sm text-muted-foreground">{t('care.overview.topicsHint')}</p>
          </div>
          {!loading && data && Object.keys(data.overall).length === 0 ? (
            <EmptyState title={t('care.overview.noData')} className="rounded-xl border border-dashed py-10" />
          ) : (
            <TopicScoreCards overall={data?.overall} loading={loading} />
          )}
        </section>

        <div className="grid gap-6 xl:grid-cols-3">
          <div className="xl:col-span-2">
            <BreakdownChart
              aggregate={data}
              loading={loading}
              breakdown={breakdown}
              onBreakdownChange={setBreakdown}
              topic={topic}
              onTopicChange={setTopic}
            />
          </div>
          <div className="flex flex-col gap-6">
            <InsightsCard aggregate={data} loading={loading} breakdown={breakdown} onSelectTopic={setTopic} />
            <TrendChart aggregate={data} loading={loading} />
          </div>
        </div>
      </div>
    );
  };

  return (
    <>
      <PageHeader title={t('care.title')} subtitle={t('care.subtitle')} actions={surveySelect} />
      <PrivacyBanner />
      {can('care.individual') && <PsychologistLinks />}
      {body()}
    </>
  );
}

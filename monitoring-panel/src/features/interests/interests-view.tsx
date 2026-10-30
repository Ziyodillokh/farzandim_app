'use client';

import { Map as MapIcon } from 'lucide-react';

import { Section } from '@/components/common/section';
import type { MetricKey, Scope } from '@/data/contracts';
import { useAreaMetric, useInterests } from '@/features/filters/use-monitoring';
import { MapPanel } from '@/features/map/map-panel';
import { LearningFooter, QueryError } from '@/features/mastery/kit/layout';
import { useScopeLabels } from '@/features/mastery/kit/scope';
import { useI18n } from '@/i18n';
import { CareerFieldsSection, ReadinessSection } from './career-section';
import { GenderChoicesSection } from './gender-choices';
import { GeneralInterestsSection } from './general-interests';
import { InterestsAreasSection } from './interests-areas';
import { InterestsKpis } from './interests-kpis';
import { RiasecSection } from './riasec-section';
import { SubjectChoiceSection } from './subject-choice';

const READINESS: MetricKey = 'careerReadiness';
const MAP_METRICS: readonly MetricKey[] = [READINESS];

function ReadinessMapSection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const { national, mapTitle } = useScopeLabels(scope);
  return (
    <Section id="interests-map" icon={<MapIcon />} title={`${mapTitle} · ${t('metrics.careerReadiness.label')}`} subtitle={national ? t('interests.sections.mapSub') : t('interests.sections.mapSubDistricts')}>
      <MapPanel scope={scope} metrics={MAP_METRICS} initial={READINESS} showTabs={false} />
    </Section>
  );
}

/**
 * Qiziqishlar sahifasi: KPI, tanlangan fanlar va o'zlashtirish, umumiy
 * qiziqishlar, o'g'il/qiz tanlovi, RIASEC, kasb sohalari, kasbga tayyorgarlik
 * (xarita bilan) va hududlar bo'yicha yetakchi qiziqishlar.
 */
export function InterestsView({ scope }: { scope: Scope }) {
  const query = useInterests(scope);
  // Xarita bilan bir xil so'rov (kesh umumiy): respublika qiymati — taqqoslash uchun.
  const readiness = useAreaMetric(READINESS, scope);
  if (query.isError) return <QueryError error={query.error} onRetry={() => void query.refetch()} />;
  const data = query.data;
  const nationalReadiness = scope.kind === 'REGION' ? (readiness.data?.national.value ?? null) : null;
  return (
    <div className="space-y-5">
      <InterestsKpis scope={scope} data={data} nationalReadiness={nationalReadiness} />
      <SubjectChoiceSection data={data} />
      <div className="grid gap-5 xl:grid-cols-2">
        <GeneralInterestsSection data={data} />
        <GenderChoicesSection data={data} />
      </div>
      <RiasecSection scope={scope} data={data} />
      <div className="grid gap-5 xl:grid-cols-2">
        <CareerFieldsSection data={data} />
        <ReadinessSection data={data} metric={readiness.data} regionScope={scope.kind === 'REGION'} />
      </div>
      <ReadinessMapSection scope={scope} />
      <InterestsAreasSection scope={scope} data={data} />
      <LearningFooter />
    </div>
  );
}

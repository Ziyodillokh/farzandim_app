'use client';

import { Map as MapIcon } from 'lucide-react';

import { Section } from '@/components/common/section';
import type { MetricKey, Scope } from '@/data/contracts';
import { useMastery } from '@/features/filters/use-monitoring';
import { MapPanel } from '@/features/map/map-panel';
import { useI18n } from '@/i18n';
import { LearningFooter, QueryError } from './kit/layout';
import { useScopeLabels } from './kit/scope';
import { GradeSection, TrendSection } from './mastery-charts';
import { DifficultySection, GroupsSection } from './mastery-groups';
import { MasteryHeatSection } from './mastery-heat';
import { MasteryKpis } from './mastery-kpis';
import { SubjectRankingSection } from './subject-ranking';

const MAP_METRICS: readonly MetricKey[] = ['mastery', 'success', 'tests'];

function MasteryMapSection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const { national, mapTitle } = useScopeLabels(scope);
  return (
    <Section id="mastery-map" icon={<MapIcon />} title={mapTitle} subtitle={national ? t('mastery.map.sub') : t('mastery.map.subDistricts')}>
      <MapPanel scope={scope} metrics={MAP_METRICS} initial="mastery" />
    </Section>
  );
}

/**
 * O'zlashtirish sahifasi: KPI, xarita, fanlar reytingi, hudud × fan jadvali,
 * sinflar, dinamika, jins, maktab turi va adaptiv qiyinlik. Respublika
 * doirasida — 14 hudud, hudud doirasida — tumanlar.
 */
export function MasteryView({ scope }: { scope: Scope }) {
  const query = useMastery(scope);
  if (query.isError) return <QueryError error={query.error} onRetry={() => void query.refetch()} />;
  const data = query.data;
  return (
    <div className="space-y-5">
      <MasteryKpis scope={scope} data={data} />
      <MasteryMapSection scope={scope} />
      <SubjectRankingSection scope={scope} data={data} />
      <MasteryHeatSection scope={scope} data={data} />
      <div className="grid gap-5 xl:grid-cols-2">
        <GradeSection data={data} />
        <TrendSection scope={scope} data={data} />
      </div>
      <div className="grid gap-5 xl:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]">
        <GroupsSection data={data} />
        <DifficultySection data={data} />
      </div>
      <LearningFooter />
    </div>
  );
}

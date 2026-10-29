'use client';

import { ShieldCheck } from 'lucide-react';
import { useCallback, useMemo } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Card } from '@/components/ui/card';
import type { MetricKey } from '@/data/contracts';
import { K_MIN } from '@/data/mock/model/engine';
import { ScopeSelect, usePageScope } from '@/features/filters/scope-select';
import { useFilters } from '@/features/filters/store';
import { useOverview, useSchools } from '@/features/filters/use-monitoring';
import { PageFooter } from '@/features/regions/kit/page-footer';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { DistrictsSection } from './district-table';
import { RegionSchoolsSection } from './region-schools-table';
import { SchoolKpis } from './school-kpis';
import { SchoolListSection, type ScopeReference } from './school-list';
import { SchoolTypesSection } from './school-types';

/**
 * "Maktablar" (doiraga qarab): respublika foydalanuvchisi hududni tanlaydi,
 * viloyat foydalanuvchisi — doim o'z hududi. Maktablar faqat anonim kod bilan.
 */
export function SchoolsView() {
  const { t } = useI18n();
  const areaName = useAreaName();
  const scope = usePageScope();
  const [filters] = useFilters();
  const schools = useSchools(scope);
  const overview = useOverview(scope);
  const { refetch: refetchSchools } = schools;
  const { refetch: refetchOverview } = overview;
  const retrySchools = useCallback(() => void refetchSchools(), [refetchSchools]);
  const retryOverview = useCallback(() => void refetchOverview(), [refetchOverview]);

  const kpis = overview.data?.kpis;
  const reference = useMemo<ScopeReference>(() => {
    const value = (key: MetricKey) => kpis?.find((k) => k.key === key)?.value ?? null;
    return { mastery: value('mastery'), attendance: value('attendance'), wellbeing: value('wellbeing'), iqMean: value('iqMean') };
  }, [kpis]);

  const subtitle = scope.kind === 'REGION' ? t('schools.subtitleRegion', { region: areaName(scope.regionId) }) : t('schools.subtitle');

  return (
    <>
      <PageHeader title={t('schools.title')} subtitle={subtitle} actions={<ScopeSelect className="w-[262px]" />} />
      <div className="space-y-5">
        {overview.error ? (
          <Card>
            <ErrorState error={overview.error} onRetry={retryOverview} />
          </Card>
        ) : (
          <SchoolKpis counts={overview.data?.counts} />
        )}
        <SchoolTypesSection
          types={schools.data?.types}
          activeType={filters.schoolType}
          scopeReference={reference}
          error={schools.error}
          onRetry={retrySchools}
        />
        <SchoolListSection kind="top" rows={schools.data?.topGrowth} scope={scope} reference={reference} error={schools.error} onRetry={retrySchools} />
        <SchoolListSection kind="support" rows={schools.data?.needSupport} scope={scope} reference={reference} error={schools.error} onRetry={retrySchools} />
        <p className="flex items-start gap-2.5 rounded-2xl bg-primary/[0.05] px-4 py-3 text-[0.78rem] ring-1 ring-inset ring-primary/15 dark:bg-white/[0.03]">
          <ShieldCheck aria-hidden className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
          <span>{t('schools.privacyNote', { k: K_MIN })}</span>
        </p>
        {scope.kind === 'REGION' ? (
          <DistrictsSection regionId={scope.regionId} districts={schools.data?.districts} reference={reference} error={schools.error} onRetry={retrySchools} />
        ) : (
          <RegionSchoolsSection />
        )}
        <PageFooter />
      </div>
    </>
  );
}

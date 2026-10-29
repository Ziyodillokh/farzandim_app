'use client';

import { useMemo } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import type { Scope } from '@/data/contracts';
import { useAreaMatrix, useWellbeing } from '@/features/filters/use-monitoring';
import { useI18n } from '@/i18n';
import { CarePanel } from './care-panel';
import { GroupsSection } from './groups-section';
import { PageNav } from './kit/page-nav';
import { MapSection, NATIONAL_SCOPE, PageFootnote } from './kit/page-parts';
import { PROBLEM_METRICS, WELLBEING_MAP_METRICS } from './problem-keys';
import { ProblemsSection } from './problems-section';
import { SurveyPanel } from './survey-panel';
import { TrendsSection } from './trends-section';
import { WellbeingOverview } from './wellbeing-overview';

const IDS = {
  overview: 'wb-overview',
  problems: 'wb-problems',
  map: 'wb-map',
  survey: 'wb-survey',
  care: 'wb-care',
  groups: 'wb-groups',
  trends: 'wb-trends',
} as const;

/**
 * "Farovonlik va muammolar": KPI, bolalar o'rtasidagi muammo signallari
 * hududlar (yoki tumanlar) kesimida, xarita, so'rovnoma, murojaatlar, sinf/jins
 * kesimlari va dinamika. Hammasi — skrining signali, tashxis emas.
 */
export function WellbeingView({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const regionScope = scope.kind === 'REGION';
  const wellbeing = useWellbeing(scope);
  // Hudud doirasida — respublika bilan taqqoslash (respublikada kesh bir xil kalit).
  const national = useWellbeing(NATIONAL_SCOPE);
  const matrix = useAreaMatrix(PROBLEM_METRICS, scope);
  const nationalData = regionScope ? national.data : undefined;

  const nav = useMemo(
    () => (Object.keys(IDS) as Array<keyof typeof IDS>).map((key) => ({ id: IDS[key], label: t(`wellbeing.nav.${key}`) })),
    [t],
  );

  if (wellbeing.isError) return <ErrorState error={wellbeing.error} onRetry={() => void wellbeing.refetch()} />;

  return (
    <>
      <PageNav items={nav} label={t('wellbeing.nav.label')} />
      <div className="space-y-5">
        <WellbeingOverview id={IDS.overview} data={wellbeing.data} national={nationalData} />
        <ScreeningDisclaimer variant="banner" />
        <ProblemsSection id={IDS.problems} scope={scope} matrix={matrix.data} error={matrix.error} onRetry={() => void matrix.refetch()} />
        <MapSection id={IDS.map} scope={scope} metrics={WELLBEING_MAP_METRICS} initial="bullying" />
        <div className="grid gap-5 xl:grid-cols-2">
          <SurveyPanel id={IDS.survey} data={wellbeing.data} regionScope={regionScope} />
          <CarePanel id={IDS.care} data={wellbeing.data} />
        </div>
        <GroupsSection id={IDS.groups} data={wellbeing.data} />
        <TrendsSection id={IDS.trends} scope={scope} data={wellbeing.data} national={nationalData} />
        <PageFootnote>
          <p>{t('common.screening.regionsNote')}</p>
        </PageFootnote>
      </div>
    </>
  );
}

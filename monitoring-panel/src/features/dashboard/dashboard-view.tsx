'use client';

import { Map, Sparkles } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Scope } from '@/data/contracts';
import { K_MIN } from '@/data/mock/model/engine';
import { useInsights, useOverview } from '@/features/filters/use-monitoring';
import { InsightList } from '@/features/insights/insight-list';
import { MapPanel } from '@/features/map/map-panel';
import { useI18n } from '@/i18n';
import { DashboardHero, type HeroProfile } from './hero';
import { KpiGrid } from './kpi-grid';
import { InterestsSection, IqSection, MasterySection } from './learning-sections';
import { AttendanceSection, DigitalSection, WellbeingSection } from './life-sections';
import { SectionNav } from './section-nav';

/**
 * "Bitta dashboard": doiraning (respublika yoki hudud) barcha yo'nalishlari bir
 * sahifada — hero, KPI, xarita, fanlar, IQ, qiziqishlar, farovonlik, davomat,
 * raqamli odatlar va xulosalar. Hudud profili ham shu ko'rinishdan foydalanadi.
 */
export function DashboardView({ scope, profile }: { scope: Scope; profile?: HeroProfile }) {
  const { t } = useI18n();
  const overview = useOverview(scope);
  const insights = useInsights(scope);
  return (
    <>
      <DashboardHero scope={scope} overview={overview.data} profile={profile} />
      <SectionNav districts={scope.kind === 'REGION'} />
      <div className="space-y-5">
        <div id="sec-kpis" className="scroll-mt-28">
          <KpiGrid overview={overview.data} loading={overview.isLoading} />
        </div>
        <Section
          id="sec-map"
          icon={<Map />}
          title={scope.kind === 'NATIONAL' ? t('dashboard.sections.map') : t('dashboard.sections.districts')}
          subtitle={t('dashboard.mapSub')}
          href={scope.kind === 'NATIONAL' ? '/regions' : undefined}
          hrefLabel={t('dashboard.openSection')}
        >
          <MapPanel scope={scope} />
        </Section>
        <Section id="sec-insights" icon={<Sparkles />} title={t('insights.title')} subtitle={t('insights.subtitle')}>
          {insights.data ? (
            <InsightList insights={insights.data} collapsedCount={6} className="grid gap-2.5 space-y-0 md:grid-cols-2 xl:grid-cols-3" />
          ) : (
            <Skeleton className="h-[220px] w-full rounded-xl" />
          )}
        </Section>
        <MasterySection scope={scope} />
        <div className="grid gap-5 xl:grid-cols-2">
          <IqSection scope={scope} />
          <InterestsSection scope={scope} />
        </div>
        <WellbeingSection scope={scope} />
        <div className="grid gap-5 xl:grid-cols-2">
          <AttendanceSection scope={scope} />
          <DigitalSection scope={scope} />
        </div>
        <footer className="space-y-1.5 rounded-2xl bg-primary/[0.04] p-4 text-[0.72rem] text-muted-foreground ring-1 ring-inset ring-border/50 dark:bg-white/[0.02]">
          <p>
            <b className="text-foreground">{t('common.privacy.title')}.</b> {t('common.privacy.text', { k: K_MIN })}
          </p>
          <p>{t('common.screening.regionsNote')}</p>
          <p>{t('dashboard.sourcesNote')}</p>
        </footer>
      </div>
    </>
  );
}

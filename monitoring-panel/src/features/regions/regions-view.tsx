'use client';

import { Map } from 'lucide-react';

import { PageHeader } from '@/components/common/page-header';
import { Section } from '@/components/common/section';
import { MapPanel } from '@/features/map/map-panel';
import { useI18n } from '@/i18n';
import { PageFooter } from './kit/page-footer';
import { RegionCompareSection } from './region-compare';
import { RegionsTableSection } from './regions-table';
import { NATIONAL_SCOPE, useRegionsData } from './use-regions-data';

/**
 * "Hududlar" (faqat respublika foydalanuvchisi): xarita + reyting, barcha
 * hududlar jadvali va 2–3 hududni solishtirish. Qatorlar va xarita — hudud profiliga.
 */
export function RegionsView() {
  const { t } = useI18n();
  const { rows, national, error, retry } = useRegionsData();
  return (
    <>
      <PageHeader title={t('regions.title')} subtitle={t('regions.subtitle')} />
      <div className="space-y-5">
        <Section id="sec-map" icon={<Map />} title={t('regions.map.title')} subtitle={t('regions.map.subtitle')}>
          <MapPanel scope={NATIONAL_SCOPE} />
        </Section>
        <RegionsTableSection rows={rows} national={national} error={error} onRetry={retry} />
        <RegionCompareSection rows={rows} national={national} error={error} onRetry={retry} />
        <PageFooter notes={[t('common.screening.regionsNote')]} />
      </div>
    </>
  );
}

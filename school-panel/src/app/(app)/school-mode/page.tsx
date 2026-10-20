'use client';

import { LayoutGrid, Smartphone } from 'lucide-react';
import { useMemo, useRef, useState } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import type { DeviceFilter } from '@/data/mock/services/school-mode';
import { ClassTiles, ComplianceLegend } from '@/features/school-mode/components/class-tiles';
import { DevicesPanel } from '@/features/school-mode/components/devices-panel';
import { EmergencyControls } from '@/features/school-mode/components/emergency-controls';
import { LiveKpis } from '@/features/school-mode/components/live-kpis';
import { SafetyCallout } from '@/features/school-mode/components/safety-callout';
import { ClassEmergencyStrip, StatusHero } from '@/features/school-mode/components/status-hero';
import { useSmOverview } from '@/features/school-mode/hooks';
import { useI18n } from '@/i18n';

const INITIAL_FILTER: DeviceFilter = { page: 1, limit: 15, sortBy: 'status', sortDir: 'asc' };

export default function SchoolModeLivePage() {
  const { t } = useI18n();
  const overview = useSmOverview();
  const [filter, setFilter] = useState<DeviceFilter>(INITIAL_FILTER);
  const devicesRef = useRef<HTMLDivElement>(null);

  const classOptions = useMemo(
    () => (overview.data?.classes ?? []).map((c) => ({ value: c.classId, label: c.className })),
    [overview.data?.classes],
  );

  const selectClass = (classId: string) => {
    setFilter((f) => ({ ...f, page: 1, classId: f.classId === classId ? undefined : classId }));
    devicesRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const header = (
    <PageHeader
      title={t('schoolMode.title')}
      subtitle={t('schoolMode.subtitle')}
      badge={
        <Badge variant="success" className="gap-1.5">
          <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-current" aria-hidden />
          {t('schoolMode.liveBadge')}
        </Badge>
      }
    />
  );

  if (overview.isError) {
    return (
      <>
        {header}
        <ErrorState error={overview.error} onRetry={() => void overview.refetch()} />
      </>
    );
  }

  return (
    <>
      {header}
      <ClassEmergencyStrip overview={overview.data} />
      <StatusHero
        overview={overview.data}
        loading={overview.isLoading}
        actions={<EmergencyControls overview={overview.data} />}
      />
      <LiveKpis overview={overview.data} loading={overview.isLoading} />

      <SectionCard
        className="mb-6 animate-slide-up"
        icon={<LayoutGrid />}
        title={t('schoolMode.classes.title')}
        description={t('schoolMode.classes.description')}
        actions={<ComplianceLegend />}
      >
        <ClassTiles
          rows={overview.data?.classes}
          shifts={overview.data?.shifts ?? []}
          loading={overview.isLoading}
          selectedId={filter.classId}
          onSelect={selectClass}
        />
      </SectionCard>

      <div ref={devicesRef} className="mb-6 scroll-mt-24">
        <SectionCard icon={<Smartphone />} title={t('schoolMode.devices.title')} description={t('schoolMode.devices.description')} bodyClassName="p-4 sm:p-5">
          <DevicesPanel filter={filter} onFilterChange={setFilter} classOptions={classOptions} />
        </SectionCard>
      </div>

      <SafetyCallout />
    </>
  );
}

'use client';

import { useMemo } from 'react';

import { ErrorState } from '@/components/common/error-state';
import type { MetricKey, Scope } from '@/data/contracts';
import { useAttendance } from '@/features/filters/use-monitoring';
import { AreaTableSection } from '@/features/wellbeing/kit/area-table-section';
import { PageNav } from '@/features/wellbeing/kit/page-nav';
import { MapSection, NATIONAL_SCOPE, PageFootnote } from '@/features/wellbeing/kit/page-parts';
import { useI18n } from '@/i18n';
import { AttendanceOverview } from './attendance-overview';
import { BreakdownsSection } from './breakdowns-section';

const IDS = {
  overview: 'att-overview',
  map: 'att-map',
  breakdowns: 'att-breakdowns',
  areas: 'att-areas',
} as const;

/** Xarita va jadval ko'rsatkichlari. */
const ATTENDANCE_METRICS: readonly MetricKey[] = ['attendance', 'late', 'chronic'];

/**
 * "Davomat": KPI va holatlar taqsimoti, xarita, oylar / hafta kunlari / sinflar /
 * maktab turlari kesimi va saralanadigan hududlar (tumanlar) jadvali.
 */
export function AttendanceView({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const regionScope = scope.kind === 'REGION';
  const attendance = useAttendance(scope);
  const national = useAttendance(NATIONAL_SCOPE);
  const nationalData = regionScope ? national.data : undefined;

  const nav = useMemo(
    () => (Object.keys(IDS) as Array<keyof typeof IDS>).map((key) => ({ id: IDS[key], label: t(`attendance.nav.${key}`) })),
    [t],
  );

  if (attendance.isError) return <ErrorState error={attendance.error} onRetry={() => void attendance.refetch()} />;

  return (
    <>
      <PageNav items={nav} label={t('attendance.nav.label')} />
      <div className="space-y-5">
        <AttendanceOverview id={IDS.overview} data={attendance.data} national={nationalData} />
        <MapSection id={IDS.map} scope={scope} metrics={ATTENDANCE_METRICS} initial="attendance" />
        <BreakdownsSection id={IDS.breakdowns} scope={scope} data={attendance.data} national={nationalData} />
        <AreaTableSection
          id={IDS.areas}
          scope={scope}
          metrics={ATTENDANCE_METRICS}
          title={regionScope ? t('attendance.areas.titleDistrict') : t('attendance.areas.title')}
          csvFile={t('attendance.areas.csvFile')}
        />
        <PageFootnote>
          <p>
            <b className="text-foreground">{t('metrics.attendance.title')}:</b> {t('metrics.attendance.description')}{' '}
            <b className="text-foreground">{t('metrics.chronic.title')}:</b> {t('metrics.chronic.description')}
          </p>
        </PageFootnote>
      </div>
    </>
  );
}

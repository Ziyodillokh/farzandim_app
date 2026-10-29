'use client';

import { CalendarCheck2 } from 'lucide-react';

import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { Attendance } from '@/data/contracts';
import { BlockTitle } from '@/features/wellbeing/kit/chart-block';
import { LeadCard, LeadCardSkeleton } from '@/features/wellbeing/kit/lead-card';
import { StackedShare } from '@/features/wellbeing/kit/stacked-share';
import { StatTile, StatTileSkeleton } from '@/features/wellbeing/kit/stat-tile';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { ABSENT_KEYS, PRESENT_KEYS, STATUS_COLORS, STATUS_KEYS, type StatusKey } from './status-colors';


/** Holatlar taqsimoti: 100% ustun, "Keldi / Kelmadi" qavslari va asosiy chetlanish. */
function StatusCard({ statuses }: { statuses: Attendance['statuses'] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  if (!statuses) {
    return (
      <Card className="flex h-full items-center justify-center p-5 text-sm text-muted-foreground">
        {t('common.noData')}
      </Card>
    );
  }
  const deviations: StatusKey[] = ['late', 'leftEarly', 'excused', 'absent'];
  const main = deviations.reduce((best, k) => (statuses[k] > statuses[best] ? k : best), deviations[0] as StatusKey);
  const missed = statuses.excused + statuses.absent;
  return (
    <Card className="h-full p-5">
      <div className="mb-3 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <BlockTitle>{t('attendance.statuses.title')}</BlockTitle>
        <p className="text-[0.75rem] text-muted-foreground">
          {t('attendance.statuses.mainDeviation', { status: t(`enums.attendanceStatus.${main}`).toLowerCase(), value: fmt.pct(statuses[main]) })}
        </p>
      </div>
      <StackedShare
        segments={STATUS_KEYS.map((k) => ({ key: k, label: t(`enums.attendanceStatus.${k}`), value: statuses[k], color: STATUS_COLORS[k] }))}
        format={(v) => fmt.pct(v)}
        groups={[
          { key: 'came', label: t('attendance.statuses.came'), keys: PRESENT_KEYS },
          { key: 'missed', label: t('attendance.statuses.missed'), keys: ABSENT_KEYS },
        ]}
      />
      {missed > 0 && (
        <p className="mt-3 text-[0.72rem] text-muted-foreground">{t('attendance.statuses.excusedShare', { value: fmt.pct((statuses.excused / missed) * 100, 0) })}</p>
      )}
    </Card>
  );
}

/**
 * Davomat KPI bloki: bosh ko'rsatkich (davomat darajasi, trend), kechikish,
 * surunkali kelmaslik, erta ketish va holatlar taqsimoti.
 */
export function AttendanceOverview({ id, data, national }: { id: string; data: Attendance | undefined; national: Attendance | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const pct = (v: number | null | undefined) => fmt.pct(v);
  return (
    <div id={id} className="scroll-mt-32">
      <div className="grid gap-3 xl:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        {!data ? (
          <LeadCardSkeleton className="min-h-[300px]" />
        ) : (
          <LeadCard
            icon={<CalendarCheck2 />}
            label={t('metrics.attendance.title')}
            metric="attendance"
            stat={data.rate}
            value={fmt.value('attendance', data.rate.value)}
            national={national?.rate.value}
            series={data.byMonth}
            sparkHeight={96}
            description={t('metrics.attendance.description')}
          >
            {data.statuses && (
              <p className="text-[0.75rem] text-muted-foreground">
                {t('attendance.overview.missedDays', { value: fmt.pct(data.statuses.excused + data.statuses.absent) })}
              </p>
            )}
          </LeadCard>
        )}
        <div className="grid gap-3">
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {!data ? (
              [0, 1, 2].map((i) => <StatTileSkeleton key={i} className="min-h-[124px]" />)
            ) : (
              <>
                <StatTile metric="late" stat={data.late} label={t('metrics.late.label')} national={national?.late.value} description={t('metrics.late.description')} />
                <StatTile metric="chronic" stat={data.chronic} label={t('metrics.chronic.label')} national={national?.chronic.value} description={t('metrics.chronic.description')} />
                <StatTile
                  metric="late"
                  stat={data.earlyExits}
                  label={t('attendance.overview.earlyExits')}
                  national={national?.earlyExits.value}
                  description={t('attendance.overview.earlyExitsDesc')}
                  format={pct}
                  className="col-span-2 sm:col-span-1"
                />
              </>
            )}
          </div>
          {!data ? <Skeleton className="h-[150px] w-full rounded-2xl" /> : <StatusCard statuses={data.statuses} />}
        </div>
      </div>
      <p className="mt-2 text-[0.7rem] text-muted-foreground">{national ? t('wellbeing.kit.deltaNote') : t('wellbeing.kit.deltaNoteNational')}</p>
    </div>
  );
}

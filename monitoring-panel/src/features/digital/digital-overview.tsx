'use client';

import { ShieldCheck, Smartphone } from 'lucide-react';

import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { Digital, Stat } from '@/data/contracts';
import { BarList } from '@/features/wellbeing/kit/bar-list';
import { BlockTitle } from '@/features/wellbeing/kit/chart-block';
import { LeadCard, LeadCardSkeleton } from '@/features/wellbeing/kit/lead-card';
import { StatTile, StatTileSkeleton } from '@/features/wellbeing/kit/stat-tile';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

const asStat = (value: number | null): Stat => ({ value, base: null, delta: null, n: 0 });

const SCHOOL_DAY_COLOR = 'hsl(var(--chart-1))';
const WEEKEND_COLOR = 'hsl(var(--chart-5))';

/** Ma'lumot manbai: faqat ota-ona roziligi bilan ulangan qurilmalar, faqat agregat. */
export function ConsentNote({ devices }: { devices: number | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <div className="flex items-start gap-3 rounded-2xl bg-emerald-500/[0.06] p-4 text-sm ring-1 ring-inset ring-emerald-500/20">
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-emerald-500/15 text-emerald-700 dark:text-emerald-300">
        <ShieldCheck className="h-4 w-4" />
      </span>
      <div className="min-w-0">
        <p className="font-semibold">{t('digital.consent.title')}</p>
        <p className="mt-0.5 text-muted-foreground">{t('digital.consent.text')}</p>
        {devices !== undefined && <p className="mt-1 text-xs text-muted-foreground">{t('digital.consent.devices', { count: fmt.count(devices) })}</p>}
      </div>
    </div>
  );
}

/** O'quv kuni va dam olish kunidagi ekran vaqti. */
function DayTypeCard({ data }: { data: Digital }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const diff = data.schoolDay !== null && data.weekend !== null ? data.weekend - data.schoolDay : null;
  const format = (v: number | null) => fmt.value('screenTime', v);
  return (
    <Card className="h-full p-5">
      <div className="mb-3 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <BlockTitle>{t('metrics.screenTime.label')}</BlockTitle>
        {diff !== null && diff > 0 && <p className="text-[0.75rem] text-muted-foreground">{t('digital.overview.weekendMore', { diff: fmt.value('screenTime', diff) })}</p>}
      </div>
      <BarList
        labelWidth="8.5rem"
        rows={[
          { key: 'school', label: t('digital.overview.schoolDay'), value: data.schoolDay, color: SCHOOL_DAY_COLOR },
          { key: 'weekend', label: t('digital.overview.weekend'), value: data.weekend, color: WEEKEND_COLOR },
        ]}
        format={format}
      />
    </Card>
  );
}

/**
 * Raqamli odatlar KPI bloki: ekran vaqti (bosh ko'rsatkich, trend), tungi
 * foydalanish, dars rejimi, qadamlar, qurilmalar va o'quv/dam olish kuni farqi.
 */
export function DigitalOverview({ id, data, national }: { id: string; data: Digital | undefined; national: Digital | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <div id={id} className="scroll-mt-32">
      <div className="grid gap-3 xl:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        {!data ? (
          <LeadCardSkeleton className="min-h-[290px]" />
        ) : (
          <LeadCard
            icon={<Smartphone />}
            label={t('metrics.screenTime.title')}
            metric="screenTime"
            stat={data.screenTime}
            suffix={t('digital.overview.perDay')}
            national={national?.screenTime.value}
            series={data.trend}
            sparkHeight={84}
            description={t('metrics.screenTime.description')}
          />
        )}
        <div className="grid gap-3">
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {!data ? (
              [0, 1, 2, 3].map((i) => <StatTileSkeleton key={i} className="min-h-[124px]" />)
            ) : (
              <>
                <StatTile
                  metric="night"
                  stat={data.night}
                  label={t('metrics.night.label')}
                  national={national?.night.value}
                  description={t('metrics.night.description')}
                  hint={t('digital.overview.sleep', { value: fmt.value('sleep', data.sleep.value) })}
                />
                <StatTile metric="schoolMode" stat={data.schoolMode} label={t('metrics.schoolMode.label')} national={national?.schoolMode.value} description={t('metrics.schoolMode.description')} />
                <StatTile metric="steps" stat={data.steps} label={t('metrics.steps.label')} national={national?.steps.value} description={t('metrics.steps.description')} />
                <StatTile
                  metric="steps"
                  stat={asStat(data.devices)}
                  label={t('digital.overview.devices')}
                  description={t('digital.overview.devicesDesc')}
                  format={(v) => fmt.count(v)}
                />
              </>
            )}
          </div>
          {!data ? <Skeleton className="h-[130px] w-full rounded-2xl" /> : <DayTypeCard data={data} />}
        </div>
      </div>
      <p className="mt-2 text-[0.7rem] text-muted-foreground">{national ? t('wellbeing.kit.deltaNote') : t('wellbeing.kit.deltaNoteNational')}</p>
    </div>
  );
}

'use client';

import { HeartHandshake } from 'lucide-react';

import type { MetricKey, Stat, Wellbeing } from '@/data/contracts';
import { useI18n, type TKey } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { LeadCard, LeadCardSkeleton } from './kit/lead-card';
import { StatTile, StatTileSkeleton } from './kit/stat-tile';
import { LevelBadge, LevelScale } from './level';

type TileKey = 'bullying' | 'anxiety' | 'support' | 'sleep' | 'safetyGap' | 'careRequests' | 'schoolQuality' | 'teacherRelation';

/** KPI plitkalari tartibi: avval muammo signallari, keyin murojaatlar va maktab muhiti. */
const TILES: ReadonlyArray<{ key: TileKey; label: TKey }> = [
  { key: 'bullying', label: 'metrics.bullying.label' },
  { key: 'anxiety', label: 'metrics.anxiety.label' },
  { key: 'support', label: 'enums.problem.support' },
  { key: 'sleep', label: 'metrics.sleep.label' },
  { key: 'safetyGap', label: 'enums.problem.safetyGap' },
  { key: 'careRequests', label: 'dashboard.carePer1000' },
  { key: 'schoolQuality', label: 'metrics.schoolQuality.label' },
  { key: 'teacherRelation', label: 'metrics.teacherRelation.label' },
];

/**
 * Farovonlik KPI bloki: bosh ko'rsatkich (farovonlik indeksi — daraja, trend,
 * shkala) va 8 ta signal plitkasi; hudud doirasida — respublika qiymati bilan.
 */
export function WellbeingOverview({ id, data, national }: { id: string; data: Wellbeing | undefined; national: Wellbeing | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const statOf = (w: Wellbeing | undefined, key: TileKey): Stat | undefined => w?.[key];
  const hintOf = (key: MetricKey) => {
    if (!data) return undefined;
    if (key === 'support') return t('wellbeing.overview.watch', { value: fmt.pct(data.watch.value) });
    if (key === 'careRequests') return t('wellbeing.overview.urgent', { value: fmt.pct(data.urgentShare) });
    return undefined;
  };

  return (
    <div id={id} className="scroll-mt-32">
      <div className="grid gap-3 xl:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        {!data ? (
          <LeadCardSkeleton className="min-h-[260px]" />
        ) : (
          <LeadCard
            icon={<HeartHandshake />}
            label={t('metrics.wellbeing.title')}
            metric="wellbeing"
            stat={data.index}
            suffix={t('wellbeing.overview.outOf')}
            badge={<LevelBadge level={data.level} />}
            national={national?.index.value}
            series={data.trend}
            description={t('metrics.wellbeing.description')}
          >
            <LevelScale value={data.index.value} national={national?.index.value} />
            <p className="mt-2 text-[0.72rem] text-muted-foreground">{t('wellbeing.overview.respondents', { count: fmt.count(data.respondents) })}</p>
          </LeadCard>
        )}
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {TILES.map(({ key, label }) =>
            !data ? (
              <StatTileSkeleton key={key} className="min-h-[124px]" />
            ) : (
              <StatTile
                key={key}
                metric={key}
                stat={statOf(data, key)}
                label={t(label)}
                national={national ? statOf(national, key)?.value : undefined}
                description={t(`metrics.${key}.description`)}
                hint={hintOf(key)}
              />
            ),
          )}
        </div>
      </div>
      <p className="mt-2 text-[0.7rem] text-muted-foreground">{national ? t('wellbeing.kit.deltaNote') : t('wellbeing.kit.deltaNoteNational')}</p>
    </div>
  );
}

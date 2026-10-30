'use client';

import { Brain, Hourglass, ShieldCheck, Sparkles, Sprout, UserCheck, Users } from 'lucide-react';

import { Sparkline } from '@/components/charts/sparkline';
import type { Iq } from '@/data/contracts';
import { IQ_BAND_COLORS } from '@/lib/color-scale';
import { Meter, StackBar } from '@/features/mastery/kit/bars';
import { CountUpValue, KpiRow, KpiRowSkeleton, KpiTile, SPARK_TONE, UnitValue } from '@/features/mastery/kit/kpi-tile';
import { useCompactParts } from '@/features/mastery/kit/use-compact';
import { useI18n } from '@/i18n';
import { deltaTone } from '@/lib/format';
import { cn } from '@/lib/utils';
import { bandShare, hasBandData, IQ_BANDS_ASC, modalBand } from './iq-norm';

/** Darajalar taqsimoti — ingichka yig'ma chiziq (KPI kartasi pastida). */
function BandStrip({ bands }: { bands: Iq['bands'] }) {
  const { t } = useI18n();
  return <StackBar parts={IQ_BANDS_ASC.map((b) => ({ key: b, label: t(`enums.iqBand.${b}`), value: bandShare(bands, b), color: IQ_BAND_COLORS[b] }))} />;
}

function NormBadge({ normed }: { normed: boolean }) {
  const { t } = useI18n();
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[0.68rem] font-semibold ring-1 ring-inset',
        normed ? 'bg-emerald-500/10 text-emerald-700 ring-emerald-500/25 dark:text-emerald-300' : 'bg-amber-500/10 text-amber-700 ring-amber-500/30 dark:text-amber-300',
      )}
    >
      {normed ? <ShieldCheck className="h-3.5 w-3.5" /> : <Hourglass className="h-3.5 w-3.5" />}
      {normed ? t('iq.kpi.normed') : t('iq.kpi.provisional')}
    </span>
  );
}

/** O'rtacha ball faqat norma tasdiqlanganda; aks holda — eng katta ulushli daraja. Taqsimot yo'q — chiziq ham yo'q. */
function MeanTile({ data }: { data: Iq }) {
  const { t } = useI18n();
  const strip = hasBandData(data.bands) ? <BandStrip bands={data.bands} /> : undefined;
  if (data.normed) {
    return (
      <KpiTile
        label={t('metrics.iqMean.title')}
        icon={<Brain />}
        value={<CountUpValue metric="iqMean" value={data.mean.value} />}
        metric="iqMean"
        delta={data.mean.delta}
        note={t('iq.kpi.meanNote')}
        footer={strip}
      />
    );
  }
  const modal = modalBand(data.bands);
  return (
    <KpiTile
      label={t('iq.kpi.modalBand')}
      icon={<Brain />}
      value={modal ? t(`enums.iqBand.${modal.key}`) : '—'}
      textValue
      note={t('iq.kpi.modalBandNote')}
      footer={strip}
    />
  );
}

/** IQ KPI qatori: qamrov, o'rtacha ball (yoki daraja), yuqori daraja, rivojlanish zonasi, qatnashganlar. */
export function IqKpis({ data }: { data: Iq | undefined }) {
  const { t } = useI18n();
  const compact = useCompactParts();
  if (!data) return <KpiRowSkeleton />;
  const participants = compact(data.participants);
  return (
    <KpiRow>
      <KpiTile
        label={t('metrics.iqParticipation.title')}
        icon={<Users />}
        value={<CountUpValue metric="iqParticipation" value={data.participation.value} />}
        metric="iqParticipation"
        delta={data.participation.delta}
        note={t('iq.kpi.participationNote')}
        footer={<Sparkline series={data.trend} color={SPARK_TONE[deltaTone('iqParticipation', data.participation.delta)]} />}
      />
      <MeanTile data={data} />
      <KpiTile
        label={t('metrics.iqHigh.label')}
        icon={<Sparkles />}
        value={<CountUpValue metric="iqHigh" value={data.high.value} />}
        metric="iqHigh"
        delta={data.high.delta}
        note={t('iq.kpi.highNote')}
        footer={<Meter value={data.high.value} barClassName="bg-gradient-to-r from-sky-500 to-cyan-400" />}
      />
      <KpiTile
        label={t('metrics.iqGrowthZone.label')}
        icon={<Sprout />}
        value={<CountUpValue metric="iqGrowthZone" value={data.growthZone.value} />}
        metric="iqGrowthZone"
        delta={data.growthZone.delta}
        note={t('iq.kpi.growthNote')}
        footer={<Meter value={data.growthZone.value} barClassName="bg-gradient-to-r from-amber-500 to-amber-400" />}
      />
      <KpiTile
        label={t('dashboard.participants')}
        icon={<UserCheck />}
        value={participants.unit ? <UnitValue value={participants.value} unit={participants.unit} /> : participants.value}
        note={t('iq.kpi.participantsNote')}
        footer={<NormBadge normed={data.normed} />}
      />
    </KpiRow>
  );
}

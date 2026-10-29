'use client';

import { BriefcaseBusiness, Gauge } from 'lucide-react';

import { DeltaChip } from '@/components/charts/delta-chip';
import { ShareBars } from '@/components/charts/share-bars';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { AreaMetric, AreaStat, Interests } from '@/data/contracts';
import { Note, SubHeading } from '@/features/mastery/kit/layout';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';

const pct = (v: number) => `${Math.min(100, Math.max(0, v))}%`;

/** Kasb sohalariga moyillik (8 soha). */
export function CareerFieldsSection({ data }: { data: Interests | undefined }) {
  const { t } = useI18n();
  return (
    <Section id="interests-careers" icon={<BriefcaseBusiness />} title={t('interests.sections.careers')} subtitle={t('interests.sections.careersSub')}>
      {!data ? (
        <Skeleton className="h-[320px] w-full rounded-xl" />
      ) : (
        <ShareBars rows={data.careerFields.map((f) => ({ key: f.key, label: t(`enums.careerField.${f.key}`), share: f.share }))} barClassName="bg-gradient-to-r from-cyan-500 to-sky-400" />
      )}
    </Section>
  );
}

/** 0–100 shkala: indeks belgisi va (hudud doirasida) respublika chizig'i. */
function ReadinessScale({ value, national }: { value: number | null; national: number | null }) {
  const { t } = useI18n();
  return (
    <div>
      <div className="relative h-3 rounded-full bg-gradient-to-r from-sky-500/15 via-sky-500/35 to-cyan-400/70">
        {national !== null && <span title={t('common.nationalAvg')} className="absolute -top-1 h-5 w-0.5 rounded-full bg-foreground/60" style={{ left: pct(national) }} />}
        {value !== null && (
          <span className="absolute top-1/2 h-5 w-5 -translate-x-1/2 -translate-y-1/2 rounded-full border-[3px] border-card bg-primary shadow-soft" style={{ left: pct(value) }} />
        )}
      </div>
      <div className="mt-2 flex justify-between text-[0.68rem] text-muted-foreground">
        <span>0 · {t('interests.careers.scaleLow')}</span>
        <span>{t('interests.careers.scaleHigh')} · 100</span>
      </div>
    </div>
  );
}

const EDGE_COUNT = 3;

function AreaList({ title, areas }: { title: string; areas: AreaStat[] }) {
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  return (
    <div className="min-w-0">
      <SubHeading className="mb-1.5">{title}</SubHeading>
      <ul className="space-y-1 text-[0.8rem]">
        {areas.map((a) => (
          <li key={a.id} className="flex items-baseline justify-between gap-3">
            <span className="truncate">{areaName(a.id, { short: true, fallback: a.name })}</span>
            <span className="shrink-0 font-semibold tabular-nums">{fmt.value('careerReadiness', a.value)}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Eng yuqori va eng past indeksli bo'linmalar (xarita bilan bir xil ma'lumot). */
function ReadinessEdges({ metric }: { metric: AreaMetric }) {
  const { t } = useI18n();
  const sorted = metric.areas.filter((a) => a.value !== null).sort((a, b) => (b.value as number) - (a.value as number));
  if (sorted.length < EDGE_COUNT * 2) return null;
  return (
    <div className="grid gap-4 border-t border-border/50 pt-4 sm:grid-cols-2">
      <AreaList title={t('map.top')} areas={sorted.slice(0, EDGE_COUNT)} />
      <AreaList title={t('map.bottom')} areas={sorted.slice(-EDGE_COUNT).reverse()} />
    </div>
  );
}

/** Kasbga tayyorgarlik indeksi: qiymat, yillik o'zgarish, respublika bilan taqqoslash, shkala va chekka bo'linmalar. */
export function ReadinessSection({ data, metric, regionScope }: { data: Interests | undefined; metric: AreaMetric | undefined; regionScope: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const stat = data?.careerReadiness;
  const national = regionScope ? (metric?.national.value ?? null) : null;
  return (
    <Section id="interests-readiness" icon={<Gauge />} title={t('interests.sections.readiness')} subtitle={t('interests.sections.readinessSub')}>
      {!stat ? (
        <Skeleton className="h-[320px] w-full rounded-xl" />
      ) : (
        <div className="space-y-5">
          <div className="flex flex-wrap items-end gap-x-3 gap-y-2">
            <span className="font-display text-[2.6rem] font-semibold leading-none tracking-[-0.02em] tabular-nums">{fmt.value('careerReadiness', stat.value)}</span>
            <span className="pb-1 text-[0.8rem] text-muted-foreground">/ 100</span>
            <DeltaChip metric="careerReadiness" delta={stat.delta} title={t('common.vsLastYear')} className="mb-1" />
            {national !== null && <span className="pb-1 text-[0.75rem] text-muted-foreground">{t('interests.careers.vsNational', { value: fmt.value('careerReadiness', national) })}</span>}
          </div>
          <ReadinessScale value={stat.value} national={national} />
          <div className="space-y-1">
            <Note>{t('metrics.careerReadiness.description')}</Note>
            <Note>{t('interests.careers.fromGrade7')}</Note>
          </div>
          {metric && <ReadinessEdges metric={metric} />}
        </div>
      )}
    </Section>
  );
}

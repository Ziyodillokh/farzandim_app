'use client';

import { BookOpenCheck, Brain, Compass } from 'lucide-react';
import { useRouter } from 'next/navigation';

import { useCan } from '@/auth/use-session';
import { Donut } from '@/components/charts/donut';
import { HeatTable } from '@/components/charts/heat-table';
import { Radar } from '@/components/charts/radar';
import { ShareBars } from '@/components/charts/share-bars';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Scope } from '@/data/contracts';
import { IQ_DISPLAY_BANDS, type IqDisplayBand, RIASEC, SUBJECT_KEYS } from '@/data/reference/domains';
import { useInterests, useIq, useMastery } from '@/features/filters/use-monitoring';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';

export const IQ_BAND_COLORS: Record<IqDisplayBand, string> = {
  VERY_HIGH: 'hsl(186 90% 46%)',
  HIGH: 'hsl(197 88% 54%)',
  ABOVE_AVERAGE: 'hsl(210 85% 62%)',
  AVERAGE: 'hsl(222 42% 60%)',
  BELOW_AVERAGE: 'hsl(42 86% 64%)',
  GROWTH_ZONE: 'hsl(32 92% 56%)',
};

export function MasterySection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const router = useRouter();
  const can = useCan();
  const { data } = useMastery(scope);
  const columns = SUBJECT_KEYS.map((s) => ({ key: s, label: t(`enums.subject.${s}`) }));
  const rows = (data?.heat ?? []).map((r) => ({
    id: r.id,
    label: areaName(r.id, { short: true, fallback: r.name }),
    values: { ...r.values, overall: r.overall },
  }));
  return (
    <Section
      id="sec-mastery"
      icon={<BookOpenCheck />}
      title={t('dashboard.sections.mastery')}
      subtitle={t('dashboard.masterySub')}
      href="/mastery"
      hrefLabel={t('dashboard.openSection')}
    >
      {!data ? (
        <Skeleton className="h-[420px] w-full rounded-xl" />
      ) : (
        <>
          <div className="mb-4 flex flex-wrap gap-2">
            {data.bySubject
              .filter((s) => s.value !== null)
              .sort((a, b) => (b.value as number) - (a.value as number))
              .map((s) => (
                <span key={s.subject} className="inline-flex items-center gap-1.5 rounded-full bg-primary/[0.06] px-2.5 py-1 text-[0.75rem] ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]">
                  {t(`enums.subject.${s.subject}`)}
                  <b className="tabular-nums">{fmt.value('mastery', s.value)}</b>
                </span>
              ))}
          </div>
          <HeatTable
            columns={[{ key: 'overall', label: t('metrics.mastery.label') }, ...columns]}
            rows={rows}
            format={(v) => (v === null ? '—' : fmt.num(v, 0))}
            firstHeader={scope.kind === 'NATIONAL' ? t('nav.regions') : t('common.districtsTitle')}
            onRowClick={scope.kind === 'NATIONAL' && can('regions.view') ? (id) => router.push(`/regions/view?id=${id}`) : undefined}
          />
          <p className="mt-2 text-[0.7rem] text-muted-foreground">{t('dashboard.heatHint')}</p>
        </>
      )}
    </Section>
  );
}

export function IqSection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { data } = useIq(scope);
  return (
    <Section id="sec-iq" icon={<Brain />} title={t('dashboard.sections.iq')} subtitle={t('dashboard.iqSub')} href="/iq" hrefLabel={t('dashboard.openSection')}>
      {!data ? (
        <Skeleton className="h-[300px] w-full rounded-xl" />
      ) : (
        <div className="space-y-5">
          <div className="grid gap-3 sm:grid-cols-3">
            <MiniStat label={t('metrics.iqMean.label')} value={fmt.value('iqMean', data.mean.value)} />
            <MiniStat label={t('metrics.iqParticipation.label')} value={fmt.value('iqParticipation', data.participation.value)} />
            <MiniStat label={t('dashboard.participants')} value={fmt.compact(data.participants)} />
          </div>
          <Donut
            slices={IQ_DISPLAY_BANDS.map((b) => ({ key: b, label: t(`enums.iqBand.${b}`), value: data.bands.find((x) => x.key === b)?.share ?? 0, color: IQ_BAND_COLORS[b] }))}
            centerValue={fmt.value('iqMean', data.mean.value)}
            centerLabel={t('dashboard.iqCenter')}
          />
          <div>
            <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('dashboard.iqDomains')}</p>
            <ShareBars
              rows={data.domains.map((d) => ({ key: d.domain, label: t(`enums.iqDomain.${d.domain}`), share: d.value ?? 0, secondary: scope.kind === 'REGION' ? d.national : undefined }))}
              max={100}
              secondaryLabel={t('common.nationalAvg')}
            />
          </div>
          <ScreeningDisclaimer withIq />
        </div>
      )}
    </Section>
  );
}

export function InterestsSection({ scope }: { scope: Scope }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const { data } = useInterests(scope);
  return (
    <Section id="sec-interests" icon={<Compass />} title={t('dashboard.sections.interests')} subtitle={t('dashboard.interestsSub')} href="/interests" hrefLabel={t('dashboard.openSection')}>
      {!data ? (
        <Skeleton className="h-[300px] w-full rounded-xl" />
      ) : (
        <div className="grid gap-6 md:grid-cols-2">
          <div>
            <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('dashboard.topSubjects')}</p>
            <ShareBars
              rows={data.subjects.slice(0, 6).map((s) => ({
                key: s.key,
                label: t(`enums.subject.${s.key}`),
                share: s.share,
                hint: t('dashboard.masteryOfSubject', { value: fmt.value('mastery', s.mastery) }),
              }))}
            />
          </div>
          <div>
            <p className="mb-2 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('dashboard.careerFields')}</p>
            <ShareBars
              rows={data.careerFields.slice(0, 6).map((f) => ({ key: f.key, label: t(`enums.careerField.${f.key}`), share: f.share }))}
              barClassName="bg-gradient-to-r from-cyan-500 to-sky-400"
            />
            <Radar
              className="mt-4"
              size={260}
              axes={RIASEC.map((code) => ({ key: code, label: t(`enums.riasec.${code}`) }))}
              series={[
                { key: 'scope', label: t('common.value'), values: Object.fromEntries(data.riasec.map((r) => [r.code, r.score])), color: 'hsl(199 90% 55%)' },
                ...(scope.kind === 'REGION'
                  ? [{ key: 'nat', label: t('common.nationalAvg'), values: Object.fromEntries(data.riasec.map((r) => [r.code, r.national])), color: 'hsl(220 20% 65%)', dashed: true }]
                  : []),
              ]}
            />
          </div>
        </div>
      )}
    </Section>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-primary/[0.05] px-3 py-2.5 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
      <p className="text-[0.7rem] text-muted-foreground">{label}</p>
      <p className="mt-0.5 font-display text-lg font-semibold tabular-nums">{value}</p>
    </div>
  );
}

export { MiniStat };

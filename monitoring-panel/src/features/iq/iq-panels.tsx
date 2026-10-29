'use client';

import { GraduationCap, Puzzle, TrendingUp, UsersRound } from 'lucide-react';

import { TrendChart } from '@/components/charts/trend-chart';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Iq, Scope } from '@/data/contracts';
import { CompareBars, Meter } from '@/features/mastery/kit/bars';
import { GENDER_COLORS } from '@/features/mastery/kit/colors';
import { Inset, Note } from '@/features/mastery/kit/layout';
import { niceScale } from '@/features/mastery/kit/num';
import { GenderGapNote } from '@/features/mastery/mastery-groups';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

/** IQ yo'nalishlari: to'g'ri javoblar ulushi, hudud doirasida — respublika belgisi bilan. */
export function IqDomainsSection({ scope, data }: { scope: Scope; data: Iq | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const region = scope.kind === 'REGION';
  return (
    <Section id="iq-domains" icon={<Puzzle />} title={t('iq.sections.domains')} subtitle={t('iq.sections.domainsSub')}>
      {!data ? (
        <Skeleton className="h-[260px] w-full rounded-xl" />
      ) : (
        <div className="space-y-4">
          <CompareBars
            rows={data.domains.map((d) => ({
              key: d.domain,
              label: t(`enums.iqDomain.${d.domain}`),
              value: d.value,
              marker: region ? d.national : null,
              hint: region ? t('iq.domains.vsNational', { value: fmt.pct(d.national) }) : undefined,
            }))}
            format={(v) => fmt.pct(v)}
            markerLabel={t('common.nationalAvg')}
          />
          <Note>
            {t('iq.domains.note')} {region ? t('iq.domains.markerNote') : ''}
          </Note>
        </div>
      )}
    </Section>
  );
}

/** Qamrov dinamikasi (oxirgi 12 o'quv oyi). */
export function IqTrendSection({ scope, data }: { scope: Scope; data: Iq | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const label = scope.kind === 'NATIONAL' ? t('common.national') : t('metrics.iqParticipation.label');
  return (
    <Section id="iq-trend" icon={<TrendingUp />} title={t('iq.sections.trend')} subtitle={t('iq.sections.trendSub')}>
      {!data ? (
        <Skeleton className="h-[260px] w-full rounded-xl" />
      ) : (
        <TrendChart
          series={[{ key: 'participation', label, points: data.trend }]}
          format={(v) => fmt.pct(v, Number.isInteger(v) ? 0 : 1)}
          height={250}
          domain={niceScale(data.trend.map((p) => p.value), { intervals: 4 }).domain}
        />
      )}
    </Section>
  );
}

/** Sinf guruhlari: o'rtacha ball (norma tasdiqlangan bo'lsa) va qamrov. */
export function IqGradeBandsSection({ data }: { data: Iq | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <Section id="iq-grades" icon={<GraduationCap />} title={t('iq.sections.grades')} subtitle={t('iq.sections.gradesSub')}>
      {!data ? (
        <Skeleton className="h-[200px] w-full rounded-xl" />
      ) : (
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-3">
            {data.byGradeBand.map((g) => (
              <Inset key={g.band}>
                <p className="text-[0.75rem] font-medium text-muted-foreground">{t(`enums.gradeBand.${g.band}`)}</p>
                <p className="mt-1 font-display text-[1.45rem] font-semibold leading-none tabular-nums">{data.normed ? fmt.value('iqMean', g.mean) : '—'}</p>
                <p className="mt-3 flex items-baseline justify-between gap-2 text-[0.72rem] text-muted-foreground">
                  <span>{t('iq.areas.colParticipation')}</span>
                  <span className="font-semibold tabular-nums text-foreground">{fmt.value('iqParticipation', g.participation)}</span>
                </p>
                <Meter value={g.participation} className="mt-1.5" />
              </Inset>
            ))}
          </div>
          <Note>
            {t('iq.groups.fromGrade3')} {data.normed ? '' : t('iq.groups.notNormed')}
          </Note>
        </div>
      )}
    </Section>
  );
}

/** Jins bo'yicha o'rtacha ball. Bolalar bir-biriga qarshi qo'yilmaydi — faqat umumlashgan farq. */
export function IqGenderSection({ data }: { data: Iq | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const mean = (g: 'M' | 'F') => (data?.normed ? (data.byGender.find((x) => x.gender === g)?.mean ?? null) : null);
  return (
    <Section id="iq-gender" icon={<UsersRound />} title={t('iq.sections.gender')} subtitle={t('iq.sections.genderSub')}>
      {!data ? (
        <Skeleton className="h-[200px] w-full rounded-xl" />
      ) : (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            {(['M', 'F'] as const).map((g) => (
              <Inset key={g}>
                <p className="flex items-center gap-2 text-[0.75rem] font-medium text-muted-foreground">
                  <span aria-hidden className="h-2.5 w-2.5 rounded-sm" style={{ background: GENDER_COLORS[g] }} />
                  {g === 'M' ? t('common.boys') : t('common.girls')}
                </p>
                <p className="mt-1 font-display text-[1.45rem] font-semibold leading-none tabular-nums">{fmt.value('iqMean', mean(g))}</p>
              </Inset>
            ))}
          </div>
          {data.normed ? <GenderGapNote boys={mean('M')} girls={mean('F')} unit={t('iq.groups.pointsUnit')} threshold={3} /> : <Note>{t('iq.groups.notNormed')}</Note>}
          <Note>{t('iq.groups.genderNote')}</Note>
        </div>
      )}
    </Section>
  );
}

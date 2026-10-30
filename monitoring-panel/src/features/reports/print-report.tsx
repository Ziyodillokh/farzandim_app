'use client';

import { ArrowLeft, Printer } from 'lucide-react';
import Link from 'next/link';

import { Forbidden } from '@/auth/guards';
import { useCan, useSession } from '@/auth/use-session';
import { IQ_BAND_COLORS } from '@/lib/color-scale';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { Scope } from '@/data/contracts';
import { isRegionId, regionName } from '@/data/reference/regions';
import { usePeriodText } from '@/features/dashboard/hero';
import { useFilters } from '@/features/filters/store';
import { useAreaMatrix, useAttendance, useDigital, useInsights, useInterests, useIq, useMastery, useOverview, useWellbeing } from '@/features/filters/use-monitoring';
import { useInsightText } from '@/features/insights/insight-list';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { deltaTone, useMetricFormat } from '@/lib/format';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import type { MetricKey } from '@/data/contracts';
import { K_MIN } from '@/data/mock/model/engine';
import { NATIONAL_REPORT_ID } from './print-card';
import { DeltaText, DocBar, DocLabel, DocSection, DocTable } from './print-parts';

const AREA_METRICS: readonly MetricKey[] = ['coverage', 'mastery', 'iqParticipation', 'wellbeing', 'bullying', 'attendance', 'screenTime'];
const WELLBEING_KEYS = ['wellbeing', 'bullying', 'anxiety', 'support', 'sleep', 'careRequests', 'safetyGap'] as const;
const LIFE_KEYS = ['attendance', 'late', 'chronic', 'screenTime', 'night', 'schoolMode'] as const;

function Report({ scope }: { scope: Scope }) {
  const { t, locale } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const insightText = useInsightText();
  const [filters] = useFilters();
  const overview = useOverview(scope);
  const matrix = useAreaMatrix(AREA_METRICS, scope);
  const mastery = useMastery(scope);
  const iq = useIq(scope);
  const interests = useInterests(scope);
  const wellbeing = useWellbeing(scope);
  const attendance = useAttendance(scope);
  const digital = useDigital(scope);
  const insights = useInsights(scope);
  const periodText = usePeriodText(overview.data);
  const regionTitle = scope.kind === 'REGION' ? regionName(scope.regionId, locale) : null;
  const title = regionTitle ? t('reports.print.regionTitle', { region: regionTitle }) : t('reports.print.nationalTitle');
  const ready = overview.data && matrix.data && mastery.data && iq.data && interests.data && wellbeing.data && attendance.data && digital.data && insights.data;
  const delta = (k: MetricKey, d: number | null | undefined) => <DeltaText text={fmt.delta(k, d)} tone={deltaTone(k, d)} />;
  const national = scope.kind === 'NATIONAL';

  const toolbar = (
    <div className="mx-auto mb-4 flex max-w-[960px] flex-wrap items-center justify-between gap-2 no-print">
      <Button asChild variant="ghost" size="sm" className="rounded-full ring-1 ring-inset ring-border/60">
        <Link href="/reports">
          <ArrowLeft />
          {t('reports.print.back')}
        </Link>
      </Button>
      <Button onClick={() => window.print()} disabled={!ready} className="rounded-xl">
        <Printer />
        {t('reports.print.printBtn')}
      </Button>
    </div>
  );

  if (!ready) {
    return (
      <>
        {toolbar}
        <h1 className="sr-only">{title}</h1>
        <div className="mx-auto max-w-[960px] space-y-3" aria-busy>
          <p className="text-sm text-muted-foreground">{t('reports.print.loading')}</p>
          <Skeleton className="h-[900px] w-full rounded-2xl" />
        </div>
      </>
    );
  }

  const o = overview.data!;
  const wb = wellbeing.data!;
  const lifeStats = { attendance: attendance.data!.rate, late: attendance.data!.late, chronic: attendance.data!.chronic, screenTime: digital.data!.screenTime, night: digital.data!.night, schoolMode: digital.data!.schoolMode };
  const wbStats = { wellbeing: wb.index, bullying: wb.bullying, anxiety: wb.anxiety, support: wb.support, sleep: wb.sleep, careRequests: wb.careRequests, safetyGap: wb.safetyGap };
  const areas = [...matrix.data!.rows].sort((a, b) => (b.values.mastery?.value ?? -1) - (a.values.mastery?.value ?? -1));

  return (
    <>
      {toolbar}
      <article
        className="mx-auto max-w-[960px] rounded-2xl bg-white px-8 py-9 text-slate-900 shadow-glass-lg ring-1 ring-slate-200 print:max-w-none print:rounded-none print:p-0 print:shadow-none print:ring-0 md:px-12"
        // Qog'oz har doim yorug': mavzu tokenlari (wordmark va h.k.) shu yerda yorug' qiymatga qaytariladi.
        style={{ printColorAdjust: 'exact', WebkitPrintColorAdjust: 'exact', ['--foreground' as string]: '224 36% 12%', ['--primary' as string]: '217 91% 50%' }}
      >
        <header className="grid gap-4 border-b-2 border-slate-900 pb-5 sm:grid-cols-[minmax(0,1fr)_auto]">
          <div className="min-w-0">
            <div className="text-slate-900">
              <ParvozWordmark size="sm" sub="MONITORING" />
            </div>
            <p className="mt-4 text-[0.72rem] font-semibold uppercase tracking-[0.14em] text-sky-700">{t('reports.print.docTitle')}</p>
            <h1 className="mt-1 font-display text-[1.6rem] font-semibold leading-tight">{title}</h1>
          </div>
          <dl className="grid content-start gap-1 text-[0.74rem] text-slate-600 sm:text-right">
            <div><dt className="inline font-semibold">{t('reports.print.period')}: </dt><dd className="inline">{periodText}</dd></div>
            <div><dt className="inline font-semibold">{t('reports.print.filters')}: </dt><dd className="inline">{[t(`enums.gradeBand.${filters.grades}`), t(`enums.gender.${filters.gender}`), t(`enums.schoolType.${filters.schoolType}`)].join(' · ')}</dd></div>
            <div><dt className="inline font-semibold">{t('reports.print.generated')}: </dt><dd className="inline">{new Date().toLocaleDateString('ru-RU')}</dd></div>
            <div className="mt-1"><span className="rounded-full bg-amber-100 px-2 py-0.5 text-[0.66rem] font-bold uppercase tracking-[0.08em] text-amber-800">{t('common.demoBadge')}</span></div>
          </dl>
        </header>

        <div className="mt-5 grid grid-cols-3 gap-3">
          <Stat label={t('dashboard.hero.statCovered')} value={fmt.count(o.counts.covered)} hint={t('dashboard.hero.coveredOf', { official: fmt.count(o.counts.official) })} />
          <Stat label={t('dashboard.hero.statSchools')} value={fmt.count(o.counts.schoolsConnected)} hint={t('dashboard.hero.schools', { connected: fmt.count(o.counts.schoolsConnected), schools: fmt.count(o.counts.schools) })} />
          <Stat label={national ? t('dashboard.hero.statRegions') : t('dashboard.hero.statDistricts')} value={national ? '14' : fmt.count(o.counts.districts)} hint={national ? t('dashboard.hero.districts', { districts: o.counts.districts }) : ''} />
        </div>

        <DocSection n={1} title={t('reports.print.s1')}>
          <DocTable
            head={[t('reports.print.indicator'), t('reports.print.value'), t('reports.print.change'), ...(national ? [] : [t('reports.print.national')])]}
            rows={o.kpis.map((k) => [t(`metrics.${k.key}.title`), fmt.value(k.key, k.value), delta(k.key, k.delta), ...(national ? [] : [fmt.value(k.key, k.national)])])}
          />
        </DocSection>

        <DocSection n={2} title={national ? t('reports.print.s2Regions') : t('reports.print.s2Districts')} note={t('reports.print.sortedBy')}>
          <DocTable
            head={['№', national ? t('reports.col.region') : t('reports.col.district'), ...AREA_METRICS.map((k) => t(`metrics.${k}.label`))]}
            align={['left', 'left']}
            rows={areas.map((r, i) => [String(i + 1), areaName(r.id, { short: true, fallback: r.name }), ...AREA_METRICS.map((k) => fmt.value(k, r.values[k]?.value))])}
          />
        </DocSection>

        <DocSection n={3} title={t('reports.print.s3')} className="print-break">
          <DocTable
            head={[t('reports.print.subject'), t('reports.print.value'), t('reports.print.change'), t('reports.print.interest'), ...(national ? [] : [t('reports.print.national')])]}
            rows={[...mastery.data!.bySubject]
              .sort((a, b) => (b.value ?? -1) - (a.value ?? -1))
              .map((s) => [t(`enums.subject.${s.subject}`), fmt.value('mastery', s.value), delta('mastery', s.delta), fmt.pct(s.interest), ...(national ? [] : [fmt.value('mastery', s.national)])])}
          />
        </DocSection>

        <div className="grid gap-x-10 md:grid-cols-2 print:grid-cols-2">
          <DocSection n={4} title={t('reports.print.s4')}>
            <p className="mb-3 text-[0.74rem] text-slate-600">{t('reports.print.iqMeta', { value: fmt.value('iqParticipation', iq.data!.participation.value), count: fmt.count(iq.data!.participants) })}</p>
            <div className="space-y-2">
              {iq.data!.bands.map((b) => (
                <DocBar key={b.key} label={t(`enums.iqBand.${b.key}`)} value={fmt.pct(b.share)} share={b.share * 2} color={IQ_BAND_COLORS[b.key]} />
              ))}
            </div>
            <p className="mt-3 text-[0.68rem] leading-relaxed text-slate-500">{t('common.screening.notIq')}</p>
          </DocSection>
          <DocSection n={5} title={t('reports.print.s5')}>
            <DocLabel>{t('reports.print.topSubjects')}</DocLabel>
            <div className="space-y-2">
              {interests.data!.subjects.flatMap((s) => (s.share === null ? [] : [{ key: s.key, share: s.share }])).slice(0, 5).map((s) => (
                <DocBar key={s.key} label={t(`enums.subject.${s.key}`)} value={fmt.pct(s.share)} share={s.share} />
              ))}
            </div>
            <div className="mt-4"><DocLabel>{t('reports.print.careerFields')}</DocLabel></div>
            <div className="space-y-2">
              {interests.data!.careerFields.slice(0, 4).map((f) => (
                <DocBar key={f.key} label={t(`enums.careerField.${f.key}`)} value={fmt.pct(f.share)} share={f.share * 3} color="#0891b2" />
              ))}
            </div>
          </DocSection>
        </div>

        <DocSection n={6} title={t('reports.print.s6')} className="print-break">
          <div className="grid gap-x-10 gap-y-4 md:grid-cols-[1.3fr_1fr] print:grid-cols-[1.3fr_1fr]">
            <DocTable
              head={[t('reports.print.indicator'), t('reports.print.value'), t('reports.print.change')]}
              rows={WELLBEING_KEYS.map((k) => [t(`metrics.${k}.title`), fmt.value(k, wbStats[k].value), delta(k, wbStats[k].delta)])}
            />
            <div>
              <DocLabel>{t('reports.print.careTopics')}</DocLabel>
              <div className="space-y-2">
                {wb.careTopics.slice(0, 5).map((c) => (
                  <DocBar key={c.key} label={t(`enums.careTopic.${c.key}`)} value={fmt.pct(c.share)} share={c.share * 2.5} color="#0ea5e9" />
                ))}
              </div>
            </div>
          </div>
          <p className="mt-3 text-[0.68rem] leading-relaxed text-slate-500">
            <b>{t('common.screening.title')}.</b> {t('common.screening.text')}
          </p>
        </DocSection>

        <DocSection n={7} title={t('reports.print.s7')}>
          <DocTable
            head={[t('reports.print.indicator'), t('reports.print.value'), t('reports.print.change')]}
            rows={LIFE_KEYS.map((k) => [t(`metrics.${k}.title`), fmt.value(k, lifeStats[k].value), delta(k, lifeStats[k].delta)])}
          />
        </DocSection>

        <DocSection n={8} title={t('reports.print.s8')}>
          <ol className="space-y-2 text-[0.8rem] leading-snug text-slate-800">
            {insights.data!.map((i, idx) => (
              <li key={i.id} className="flex gap-2.5 break-inside-avoid">
                <span className="mt-[1px] flex h-5 w-5 shrink-0 items-center justify-center rounded-md bg-slate-100 text-[0.66rem] font-semibold text-slate-600">{idx + 1}</span>
                <span>
                  <b className={i.severity === 'attention' ? 'text-amber-700' : i.severity === 'positive' ? 'text-emerald-700' : 'text-sky-700'}>{t(`enums.severity.${i.severity}`)}:</b> {insightText(i)}
                </span>
              </li>
            ))}
          </ol>
        </DocSection>

        <footer className="mt-8 space-y-1 border-t border-slate-200 pt-4 text-[0.68rem] leading-relaxed text-slate-500">
          <p><b className="text-slate-700">{t('common.privacy.title')}.</b> {t('common.privacy.text', { k: K_MIN })}</p>
          <p>{t('common.screening.regionsNote')}</p>
          <p>{t('reports.print.sources')}</p>
          <p className="font-semibold text-amber-700">{t('reports.print.demo')}</p>
        </footer>
      </article>
    </>
  );
}

function Stat({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="rounded-xl border border-slate-200 px-3 py-2.5">
      <p className="text-[0.64rem] font-semibold uppercase tracking-[0.08em] text-slate-500">{label}</p>
      <p className="mt-0.5 font-display text-[1.25rem] font-semibold tabular-nums">{value}</p>
      {hint && <p className="text-[0.66rem] text-slate-500">{hint}</p>}
    </div>
  );
}

/** `/reports/print?id=UZ|UZ-SA`: ruxsat — respublika hisoboti faqat respublika hisobiga, viloyat — o'z hududiga. */
export function PrintReport({ id }: { id: string | null }) {
  const session = useSession();
  const can = useCan();
  const target = id ?? (session?.role === 'REGIONAL' ? session.regionId : NATIONAL_REPORT_ID);
  if (target === NATIONAL_REPORT_ID) {
    if (!can('regions.view')) return <Forbidden />;
    return <Report scope={{ kind: 'NATIONAL' }} />;
  }
  if (!isRegionId(target)) return <Forbidden />;
  if (session?.role === 'REGIONAL' && session.regionId !== target) return <Forbidden />;
  return <Report scope={{ kind: 'REGION', regionId: target }} />;
}

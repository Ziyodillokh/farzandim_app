'use client';

import { Building2, Filter, GraduationCap, Landmark, Shapes } from 'lucide-react';
import { useCallback, useMemo, type ReactNode } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Filters, SchoolTypeStat } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import type { SchoolType } from '@/data/reference/domains';
import { CompareLegend, CompareMetric, type CompareRowData } from '@/features/regions/kit/compare-bars';
import { isNum } from '@/features/regions/kit/heat';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

const TYPE_ICON: Record<SchoolType, ReactNode> = {
  STATE: <Landmark />,
  PRIVATE: <Building2 />,
  SPECIAL: <GraduationCap />,
};

const TYPE_METRICS = ['mastery', 'attendance', 'wellbeing', 'iqMean'] as const;
type TypeMetric = (typeof TYPE_METRICS)[number];

/**
 * Faqat 3 tur taqqoslanadi: mayda farq (masalan, farovonlikda 1 ball) "keskin"
 * ko'rinmasin — rang va shkala uchun markaz atrofida eng kichik yoyilish.
 */
const MIN_SPREAD: Record<TypeMetric, number> = { mastery: 3, attendance: 1, wellbeing: 3, iqMean: 3 };

/** Barcha maktablar o'rtachasi: turlar qiymati monitoringdagi o'quvchilar soni bilan tortilgan. */
function weightedMean(types: readonly SchoolTypeStat[], metric: TypeMetric): number | null {
  let sum = 0;
  let weight = 0;
  for (const ty of types) {
    const v = ty[metric];
    if (!isNum(v) || ty.pupils <= 0) continue;
    sum += v * ty.pupils;
    weight += ty.pupils;
  }
  if (weight === 0) return null;
  const k = 10 ** METRICS[metric].decimals;
  return Math.round((sum / weight) * k) / k;
}

function TypeTile({ stat, total, active }: { stat: SchoolTypeStat; total: number; active: boolean }) {
  const { t, tc } = useI18n();
  const fmt = useMetricFormat();
  const pct = total > 0 ? (stat.schools / total) * 100 : 0;
  return (
    <li
      className={cn(
        'rounded-2xl bg-primary/[0.04] p-4 ring-1 ring-inset ring-border/50 dark:bg-white/[0.025]',
        active && 'bg-primary/[0.08] ring-2 ring-primary/55 dark:bg-primary/[0.08]',
      )}
    >
      <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
        <h3 className="flex min-w-0 items-center gap-2.5 font-semibold">
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15 [&_svg]:size-4">
            {TYPE_ICON[stat.type]}
          </span>
          <span className="min-w-0 break-words">{t(`enums.schoolType.${stat.type}`)}</span>
        </h3>
        <span className="ml-auto shrink-0 font-display text-[0.95rem] font-semibold">
          {tc('schools.types.schoolsCount', stat.schools, { count: fmt.count(stat.schools) })}
        </span>
      </div>
      <div aria-hidden className="mt-3 h-1.5 overflow-hidden rounded-full bg-primary/15">
        <span className="block h-full rounded-full bg-brand-gradient" style={{ width: `${Math.max(1.5, pct)}%` }} />
      </div>
      <p className="mt-2 text-[0.72rem] leading-snug text-muted-foreground">
        <span className="block font-semibold text-foreground/80">{t('schools.types.share', { share: fmt.pct(pct) })}</span>
        <span className="block">{tc('schools.types.pupilsCount', stat.pupils, { count: fmt.count(stat.pupils) })}</span>
      </p>
    </li>
  );
}

/** Maktab turlari: soni va ulushi (chapda), natijalar — barcha maktablar o'rtachasiga nisbatan (o'ngda). */
export function SchoolTypesSection({
  types,
  activeType,
  scopeReference,
  error,
  onRetry,
}: {
  types: SchoolTypeStat[] | undefined;
  activeType: Filters['schoolType'];
  /** Doira KPI'lari: tur filtri yo'q bo'lsa — aynan "barcha maktablar" qiymati. */
  scopeReference: Readonly<Record<TypeMetric, number | null>>;
  error: unknown;
  onRetry: () => void;
}) {
  const { t } = useI18n();
  const referenceText = useCallback((v: string) => t('schools.types.referenceValue', { value: v }), [t]);
  const gapText = useCallback((v: string) => t('schools.types.vsReference', { value: v }), [t]);

  const model = useMemo(() => {
    if (!types) return null;
    const series = types.map((ty) => ({ id: ty.type, label: t(`enums.schoolType.${ty.type}`) }));
    const rows: CompareRowData[] = TYPE_METRICS.map((metric) => {
      // Tur filtri tanlangan bo'lsa KPI faqat o'sha tur bo'yicha — unda turlardan tortilgan o'rtacha olinadi.
      const official = activeType === 'ALL' ? scopeReference[metric] : null;
      const reference = isNum(official) ? official : weightedMean(types, metric);
      const values = types.map((ty) => ty[metric]);
      const pad = isNum(reference) ? [reference - MIN_SPREAD[metric], reference + MIN_SPREAD[metric]] : [];
      return {
        metric,
        reference,
        context: [...values, ...pad],
        values: Object.fromEntries(types.map((ty) => [ty.type, { value: ty[metric] }])),
      };
    });
    return { series, rows, total: types.reduce((s, ty) => s + ty.schools, 0) };
  }, [types, t, activeType, scopeReference]);

  return (
    <Section id="sec-types" icon={<Shapes />} title={t('schools.types.title')} subtitle={t('schools.types.subtitle')}>
      {error ? (
        <ErrorState error={error} onRetry={onRetry} />
      ) : !model || !types ? (
        <div className="grid gap-6 xl:grid-cols-[minmax(0,0.85fr)_minmax(0,1.5fr)]">
          <Skeleton className="h-[300px] rounded-2xl" />
          <Skeleton className="h-[300px] rounded-2xl" />
        </div>
      ) : (
        <>
          {activeType !== 'ALL' && (
            <p className="mb-4 flex items-start gap-2 rounded-xl bg-primary/[0.06] px-3 py-2 text-[0.75rem] ring-1 ring-inset ring-primary/20">
              <Filter aria-hidden className="mt-0.5 h-3.5 w-3.5 shrink-0 text-primary" />
              {t('schools.types.filterNote', { type: t(`enums.schoolType.${activeType}`) })}
            </p>
          )}
          <div className="grid gap-6 xl:grid-cols-[minmax(0,0.8fr)_minmax(0,1.6fr)]">
            <ul className="grid content-start gap-3 sm:grid-cols-3 xl:grid-cols-1">
              {types.map((ty) => (
                <TypeTile key={ty.type} stat={ty} total={model.total} active={activeType === ty.type} />
              ))}
            </ul>
            <div className="min-w-0">
              <h3 className="mb-3 text-[0.72rem] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('schools.types.results')}</h3>
              <div className="grid gap-x-8 gap-y-5 md:grid-cols-2">
                {model.rows.map((row) => (
                  <CompareMetric
                    key={row.metric}
                    row={row}
                    label={t(`metrics.${row.metric}.label`)}
                    series={model.series}
                    referenceText={referenceText}
                    gapText={gapText}
                    bestLabel={t('schools.types.best')}
                    labelWidth="8.75rem"
                  />
                ))}
              </div>
              <CompareLegend
                className="mt-5"
                worse={t('schools.types.legendWorse')}
                better={t('schools.types.legendBetter')}
                reference={t('schools.types.legendReference')}
                best={t('schools.types.legendBest')}
              />
              <p className="mt-2 text-[0.7rem] text-muted-foreground">{t('schools.types.scaleNote')}</p>
            </div>
          </div>
        </>
      )}
    </Section>
  );
}

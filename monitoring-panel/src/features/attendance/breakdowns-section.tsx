'use client';

import { ChartColumn } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Attendance, Scope } from '@/data/contracts';
import { distinctExtremeGrades, extremeAllBy, gradeRangeKeys, metricScale, type NiceScale, PERCENT_MAX } from '@/features/wellbeing/kit/analysis';
import { BarList, type BarRow } from '@/features/wellbeing/kit/bar-list';
import { ChartBlock } from '@/features/wellbeing/kit/chart-block';
import { ComparedTrend } from '@/features/wellbeing/kit/compared-trend';
import { MiniColumns } from '@/features/wellbeing/kit/mini-columns';
import { useGradeLabel } from '@/features/wellbeing/kit/use-labels';
import { useI18n } from '@/i18n';
import { deltaTone, TONE_TEXT, useMetricFormat, useMonthLabel } from '@/lib/format';
import { cn } from '@/lib/utils';

/**
 * Davomat 95–97% atrofida: 0 dan boshlangan ustunlarda 1 p.p. farq ko'rinmaydi,
 * shuning uchun hafta kunlari va sinflar ustunlarida o'q kesilgan (kamida 4 p.p.
 * oraliq, 100% dan oshmaydi) — bu diagramma ustida ochiq yoziladi.
 */
const RATE_MIN_SPAN = 4;
/** Oylik trend (chiziq) o'qi kamida 3 p.p. oraliqda. */
const TREND_MIN_SPAN = 3;
const CHART_HEIGHT = 210;
/** Maktab turi nomlari ("Специализированные") kenglikda to'liq sig'sin, mobilda ustunga joy qolsin. */
const TYPE_LABEL_WIDTH = 'clamp(6.5rem, 32%, 8.75rem)';

type BlockProps = { data: Attendance; rate: number | null };

/** O'q 0 dan boshlanmasa — ko'rinadigan belgi: ustun uzunliklari qiymatlar nisbatini bildirmaydi. */
function AxisCutNote({ scale }: { scale: NiceScale | null }) {
  const { t } = useI18n();
  if (!scale || scale.domain[0] <= 0) return null;
  return <span className="rounded-md bg-muted/70 px-1.5 py-0.5 text-[0.68rem] font-medium leading-none text-muted-foreground">{t('attendance.breakdowns.axisNote')}</span>;
}

function MonthBlock({ scope, data, national }: { scope: Scope; data: Attendance; national: Attendance | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const monthLabel = useMonthLabel();
  const low = extremeAllBy(data.byMonth, (p) => p.value, 'min');
  return (
    <ChartBlock
      title={t('attendance.breakdowns.byMonth')}
      caption={low && t('wellbeing.kit.lowest', { label: low.items.map((p) => monthLabel(p.key, true)).join(', '), value: fmt.value('attendance', low.value) })}
    >
      <ComparedTrend scope={scope} metric="attendance" points={data.byMonth} nationalPoints={national?.byMonth} minSpan={TREND_MIN_SPAN} height={CHART_HEIGHT} />
    </ChartBlock>
  );
}

function WeekdayBlock({ data, rate }: BlockProps) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const format = (v: number) => fmt.value('attendance', v);
  const low = extremeAllBy(data.byWeekday, (d) => d.value, 'min');
  const scale = metricScale('attendance', [...data.byWeekday.map((d) => d.value), rate], { minSpan: RATE_MIN_SPAN });
  return (
    <ChartBlock
      title={t('attendance.breakdowns.byWeekday')}
      aside={<AxisCutNote scale={scale} />}
      caption={low && t('wellbeing.kit.lowest', { label: low.items.map((d) => t(`attendance.breakdowns.weekday.d${d.day}`)).join(', '), value: format(low.value) })}
    >
      <MiniColumns
        name={t('metrics.attendance.label')}
        data={data.byWeekday.map((d) => ({ key: String(d.day), label: t(`common.weekdays.d${d.day}`), value: d.value, tooltipLabel: t(`attendance.breakdowns.weekday.d${d.day}`) }))}
        format={format}
        scale={scale}
        reference={rate}
        highlight={new Set(low ? low.items.map((d) => String(d.day)) : [])}
        labels="all"
        height={CHART_HEIGHT}
      />
    </ChartBlock>
  );
}

function GradeBlock({ data, rate }: BlockProps) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const gradeLabel = useGradeLabel();
  const format = (v: number) => fmt.value('attendance', v);
  const points = data.byGrade.map((g) => ({ grade: g.grade, value: g.value }));
  const low = distinctExtremeGrades(points, 'min');
  const scale = metricScale('attendance', [...points.map((p) => p.value), rate], { minSpan: RATE_MIN_SPAN });
  return (
    <ChartBlock
      title={t('attendance.breakdowns.byGrade')}
      aside={<AxisCutNote scale={scale} />}
      caption={low && t('wellbeing.kit.lowest', { label: gradeLabel(low), value: format(low.value) })}
    >
      <MiniColumns
        name={t('metrics.attendance.label')}
        data={data.byGrade.map((g) => ({ key: String(g.grade), label: String(g.grade), value: g.value, tooltipLabel: t('common.grade', { grade: g.grade }) }))}
        format={format}
        scale={scale}
        reference={rate}
        highlight={gradeRangeKeys(low)}
        height={CHART_HEIGHT}
      />
    </ChartBlock>
  );
}

/** Maktab turlari: ustunlar 0–100% shkalada (uzunlik — haqiqiy ulush), farq — umumiy davomatdan. */
function SchoolTypeBlock({ data, rate }: BlockProps) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const format = (v: number | null) => fmt.value('attendance', v);
  const top = extremeAllBy(data.bySchoolType, (s) => s.value, 'max');
  const rows: BarRow[] = data.bySchoolType.map((s) => {
    const diff = s.value !== null && rate !== null ? s.value - rate : null;
    return {
      key: s.type,
      label: t(`enums.schoolType.${s.type}`),
      value: s.value,
      note: diff !== null && (
        <span className={cn('w-[3.75rem] text-right text-[0.7rem] tabular-nums', TONE_TEXT[deltaTone('attendance', diff)])}>{fmt.delta('attendance', diff)}</span>
      ),
    };
  });
  return (
    <ChartBlock
      title={t('attendance.breakdowns.bySchoolType')}
      caption={top && t('wellbeing.kit.highest', { label: top.items.map((s) => t(`enums.schoolType.${s.type}`)).join(', '), value: format(top.value) })}
    >
      <BarList
        className="pt-2"
        labelWidth={TYPE_LABEL_WIDTH}
        rows={rows}
        format={format}
        max={PERCENT_MAX}
        reference={rate}
        referenceLabel={rate !== null ? t('attendance.breakdowns.overall', { value: format(rate) }) : undefined}
      />
    </ChartBlock>
  );
}

/** Oylar, hafta kunlari, sinflar va maktab turlari bo'yicha davomat (eng past guruh ajratiladi). */
export function BreakdownsSection({ id, scope, data, national }: { id: string; scope: Scope; data: Attendance | undefined; national: Attendance | undefined }) {
  const { t } = useI18n();
  const rate = data?.rate.value ?? null;
  return (
    <Section id={id} className="scroll-mt-32" icon={<ChartColumn />} title={t('attendance.breakdowns.title')} subtitle={t('attendance.breakdowns.subtitle')}>
      {!data ? (
        <Skeleton className="h-[560px] w-full rounded-xl" />
      ) : (
        <>
          <div className="grid gap-x-8 gap-y-7 lg:grid-cols-2">
            <MonthBlock scope={scope} data={data} national={national} />
            <WeekdayBlock data={data} rate={rate} />
            <GradeBlock data={data} rate={rate} />
            <SchoolTypeBlock data={data} rate={rate} />
          </div>
          <p className="mt-4 text-[0.7rem] text-muted-foreground">{t('attendance.breakdowns.columnsNote')}</p>
        </>
      )}
    </Section>
  );
}

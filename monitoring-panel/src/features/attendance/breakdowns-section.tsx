'use client';

import { ChartColumn } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Attendance, Scope } from '@/data/contracts';
import { distinctExtremeGrades, extremeAllBy, gradeRangeKeys, niceScale } from '@/features/wellbeing/kit/analysis';
import { BarList } from '@/features/wellbeing/kit/bar-list';
import { ChartBlock } from '@/features/wellbeing/kit/chart-block';
import { ComparedTrend } from '@/features/wellbeing/kit/compared-trend';
import { MiniColumns } from '@/features/wellbeing/kit/mini-columns';
import { useGradeLabel } from '@/features/wellbeing/kit/use-labels';
import { useI18n } from '@/i18n';
import { deltaTone, TONE_TEXT, useMetricFormat, useMonthLabel } from '@/lib/format';
import { cn } from '@/lib/utils';

/** Davomat (95–97%) o'qi kamida 4 p.p. oraliqda — 1 p.p. farq ko'rinadi, lekin bo'rttirilmaydi. */
const RATE_MIN_SPAN = 4;
const TREND_MIN_SPAN = 3;

/** Oylar, hafta kunlari, sinflar va maktab turlari bo'yicha davomat (eng past guruh ajratiladi). */
export function BreakdownsSection({ id, scope, data, national }: { id: string; scope: Scope; data: Attendance | undefined; national: Attendance | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const monthLabel = useMonthLabel();
  const gradeLabel = useGradeLabel();
  const rate = data?.rate.value ?? null;
  const format = (v: number) => fmt.value('attendance', v);

  if (!data) {
    return (
      <Section id={id} className="scroll-mt-32" icon={<ChartColumn />} title={t('attendance.breakdowns.title')} subtitle={t('attendance.breakdowns.subtitle')}>
        <Skeleton className="h-[560px] w-full rounded-xl" />
      </Section>
    );
  }

  const lowMonths = extremeAllBy(data.byMonth, (p) => p.value, 'min');
  const lowDays = extremeAllBy(data.byWeekday, (d) => d.value, 'min');
  const gradePoints = data.byGrade.map((g) => ({ grade: g.grade, value: g.value }));
  const lowGrades = distinctExtremeGrades(gradePoints, 'min');
  const gradeHighlight = gradeRangeKeys(lowGrades);
  const typeScale = niceScale([...data.bySchoolType.map((s) => s.value), rate], { minSpan: RATE_MIN_SPAN });
  const topTypes = extremeAllBy(data.bySchoolType, (s) => s.value, 'max');

  return (
    <Section id={id} className="scroll-mt-32" icon={<ChartColumn />} title={t('attendance.breakdowns.title')} subtitle={t('attendance.breakdowns.subtitle')}>
      <div className="grid gap-x-8 gap-y-7 lg:grid-cols-2">
        <ChartBlock
          title={t('attendance.breakdowns.byMonth')}
          caption={lowMonths && t('wellbeing.kit.lowest', { label: lowMonths.items.map((p) => monthLabel(p.key, true)).join(', '), value: format(lowMonths.value) })}
        >
          <ComparedTrend scope={scope} metric="attendance" points={data.byMonth} nationalPoints={national?.byMonth} minSpan={TREND_MIN_SPAN} height={210} />
        </ChartBlock>
        <ChartBlock
          title={t('attendance.breakdowns.byWeekday')}
          caption={lowDays && t('wellbeing.kit.lowest', { label: lowDays.items.map((d) => t(`attendance.breakdowns.weekday.d${d.day}`)).join(', '), value: format(lowDays.value) })}
        >
          <MiniColumns
            name={t('metrics.attendance.label')}
            data={data.byWeekday.map((d) => ({ key: String(d.day), label: t(`common.weekdays.d${d.day}`), value: d.value, tooltipLabel: t(`attendance.breakdowns.weekday.d${d.day}`) }))}
            format={format}
            scale={niceScale(data.byWeekday.map((d) => d.value), { minSpan: RATE_MIN_SPAN })}
            reference={rate}
            highlight={new Set(lowDays ? lowDays.items.map((d) => String(d.day)) : [])}
            labels="all"
            height={210}
          />
        </ChartBlock>
        <ChartBlock
          title={t('attendance.breakdowns.byGrade')}
          caption={lowGrades && t('wellbeing.kit.lowest', { label: gradeLabel(lowGrades), value: format(lowGrades.value) })}
        >
          <MiniColumns
            name={t('metrics.attendance.label')}
            data={data.byGrade.map((g) => ({ key: String(g.grade), label: String(g.grade), value: g.value, tooltipLabel: t('common.grade', { grade: g.grade }) }))}
            format={format}
            scale={niceScale(gradePoints.map((p) => p.value), { minSpan: RATE_MIN_SPAN })}
            reference={rate}
            highlight={gradeHighlight}
            height={210}
          />
        </ChartBlock>
        <ChartBlock
          title={t('attendance.breakdowns.bySchoolType')}
          caption={topTypes && t('wellbeing.kit.highest', { label: topTypes.items.map((s) => t(`enums.schoolType.${s.type}`)).join(', '), value: format(topTypes.value) })}
        >
          <BarList
            className="pt-2"
            labelWidth="7.25rem"
            rows={data.bySchoolType.map((s) => {
              const diff = s.value !== null && rate !== null ? s.value - rate : null;
              return {
                key: s.type,
                label: t(`enums.schoolType.${s.type}`),
                value: s.value,
                note: diff !== null && (
                  <span className={cn('w-[3.75rem] text-right text-[0.7rem] tabular-nums', TONE_TEXT[deltaTone('attendance', diff)])}>{fmt.delta('attendance', diff)}</span>
                ),
              };
            })}
            format={(v) => fmt.value('attendance', v)}
            domain={typeScale?.domain}
            reference={rate}
            referenceLabel={t('common.value')}
          />
        </ChartBlock>
      </div>
      <p className="mt-4 text-[0.7rem] text-muted-foreground">{t('attendance.breakdowns.columnsNote')}</p>
    </Section>
  );
}

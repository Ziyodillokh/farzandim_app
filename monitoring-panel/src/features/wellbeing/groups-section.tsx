'use client';

import { Users } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Wellbeing } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { distinctExtremeGrades, gradeRangeKeys, niceScale } from './kit/analysis';
import { BarList } from './kit/bar-list';
import { BlockTitle, ChartBlock } from './kit/chart-block';
import { MiniColumns } from './kit/mini-columns';
import { GENDER_COLORS } from './kit/palette';
import { useGapFormat, useGradeLabel } from './kit/use-labels';

type GroupMetric = 'wellbeing' | 'bullying' | 'anxiety';

/** Har ko'rsatkich uchun "e'tibor" tomoni: farovonlikda — eng past, signallarda — eng yuqori. */
const GROUP_METRICS: ReadonlyArray<{ key: GroupMetric; attention: 'min' | 'max' }> = [
  { key: 'wellbeing', attention: 'min' },
  { key: 'bullying', attention: 'max' },
  { key: 'anxiety', attention: 'max' },
];

/** Farovonlik indeksi (0–100) o'qi kamida 10 ball oraliqda — kichik farq bo'rttirilmaydi. */
const WELLBEING_MIN_SPAN = 10;

/** Sinflar (kichik ko'paytmalar) va jins kesimi: farovonlik, bulling, xavotir. */
export function GroupsSection({ id, data }: { id: string; data: Wellbeing | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const gradeLabel = useGradeLabel();
  const gap = useGapFormat();
  const statValue = (key: GroupMetric) => (key === 'wellbeing' ? data?.index.value : data?.[key].value) ?? null;

  return (
    <Section id={id} className="scroll-mt-32" icon={<Users />} title={t('wellbeing.groups.title')} subtitle={t('wellbeing.groups.subtitle')}>
      {!data ? (
        <Skeleton className="h-[460px] w-full rounded-xl" />
      ) : (
        <div className="space-y-7">
          <div>
            <BlockTitle className="mb-3">{t('wellbeing.groups.byGrade')}</BlockTitle>
            <div className="grid gap-6 md:grid-cols-3">
              {GROUP_METRICS.map(({ key, attention }) => {
                const points = data.byGrade.map((g) => ({ grade: g.grade, value: g[key] }));
                const ext = distinctExtremeGrades(points, attention);
                const highlight = gradeRangeKeys(ext);
                return (
                  <ChartBlock
                    key={key}
                    title={t(`metrics.${key}.label`)}
                    caption={
                      ext &&
                      t(attention === 'max' ? 'wellbeing.kit.highest' : 'wellbeing.kit.lowest', {
                        label: gradeLabel(ext),
                        value: fmt.value(key, ext.value),
                      })
                    }
                  >
                    <MiniColumns
                      name={t(`metrics.${key}.label`)}
                      data={data.byGrade.map((g) => ({ key: String(g.grade), label: String(g.grade), value: g[key], tooltipLabel: t('common.grade', { grade: g.grade }) }))}
                      format={(v) => fmt.value(key, v)}
                      scale={key === 'wellbeing' ? niceScale(points.map((p) => p.value), { minSpan: WELLBEING_MIN_SPAN, integer: true }) : niceScale(points.map((p) => p.value), { zero: true })}
                      reference={statValue(key)}
                      highlight={highlight}
                    />
                  </ChartBlock>
                );
              })}
            </div>
            <p className="mt-2 text-[0.7rem] text-muted-foreground">{t('wellbeing.kit.gradesNote')}</p>
          </div>
          <div>
            <BlockTitle className="mb-3">{t('wellbeing.groups.byGender')}</BlockTitle>
            <div className="grid gap-6 md:grid-cols-3">
              {GROUP_METRICS.map(({ key }) => {
                const m = data.byGender.find((g) => g.gender === 'M')?.[key] ?? null;
                const f = data.byGender.find((g) => g.gender === 'F')?.[key] ?? null;
                const diff = m !== null && f !== null ? Math.abs(m - f) : null;
                return (
                  <ChartBlock
                    key={key}
                    title={t(`metrics.${key}.label`)}
                    caption={diff !== null ? t('wellbeing.kit.difference', { value: gap(key, diff) }) : undefined}
                  >
                    <BarList
                      rows={[
                        { key: 'M', label: t('common.boys'), value: m, color: GENDER_COLORS.M },
                        { key: 'F', label: t('common.girls'), value: f, color: GENDER_COLORS.F },
                      ]}
                      format={(v) => fmt.value(key, v)}
                      domain={key === 'wellbeing' ? [0, 100] : undefined}
                    />
                  </ChartBlock>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </Section>
  );
}

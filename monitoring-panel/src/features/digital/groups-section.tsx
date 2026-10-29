'use client';

import { Users } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Digital } from '@/data/contracts';
import { distinctExtremeGrades, gradeRangeKeys, niceScale } from '@/features/wellbeing/kit/analysis';
import { BarList } from '@/features/wellbeing/kit/bar-list';
import { BlockTitle, ChartBlock } from '@/features/wellbeing/kit/chart-block';
import { MiniColumns } from '@/features/wellbeing/kit/mini-columns';
import { GENDER_COLORS } from '@/features/wellbeing/kit/palette';
import { useGapFormat, useGradeLabel } from '@/features/wellbeing/kit/use-labels';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

type GradeMetric = 'screenTime' | 'night';

/** Ekran vaqti va tungi foydalanish sinflar bo'yicha; o'g'il/qiz bolalar: ekran vaqti va o'yinlar ulushi. */
export function DigitalGroupsSection({ id, data }: { id: string; data: Digital | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const gradeLabel = useGradeLabel();
  const gap = useGapFormat();

  if (!data) {
    return (
      <Section id={id} className="scroll-mt-32" icon={<Users />} title={t('digital.groups.title')} subtitle={t('digital.groups.subtitle')}>
        <Skeleton className="h-[420px] w-full rounded-xl" />
      </Section>
    );
  }

  const gradeChart = (key: GradeMetric) => {
    const points = data.byGrade.map((g) => ({ grade: g.grade, value: g[key] }));
    const ext = distinctExtremeGrades(points, 'max');
    const highlight = gradeRangeKeys(ext);
    const scope = key === 'screenTime' ? data.screenTime.value : data.night.value;
    return (
      <ChartBlock key={key} title={t(`metrics.${key}.label`)} caption={ext && t('wellbeing.kit.highest', { label: gradeLabel(ext), value: fmt.value(key, ext.value) })}>
        <MiniColumns
          name={t(`metrics.${key}.label`)}
          data={data.byGrade.map((g) => ({ key: String(g.grade), label: String(g.grade), value: g[key], tooltipLabel: t('common.grade', { grade: g.grade }) }))}
          format={(v) => fmt.value(key, v)}
          axisFormat={key === 'screenTime' ? (v) => fmt.num(v, 0) : undefined}
          scale={niceScale(points.map((p) => p.value), { zero: true, integer: key === 'screenTime' })}
          reference={scope}
          highlight={highlight}
        />
      </ChartBlock>
    );
  };

  const boys = data.byGender.find((g) => g.gender === 'M');
  const girls = data.byGender.find((g) => g.gender === 'F');
  const genderBlock = (key: 'screenTime' | 'game', title: string, format: (v: number | null) => string) => {
    const m = boys?.[key] ?? null;
    const f = girls?.[key] ?? null;
    const diff = m !== null && f !== null ? m - f : null;
    return (
      <ChartBlock key={key} title={title} caption={diff !== null ? t('wellbeing.kit.difference', { value: gap(key === 'game' ? 'share' : 'screenTime', diff) }) : undefined}>
        <BarList
          rows={[
            { key: 'M', label: t('common.boys'), value: m, color: GENDER_COLORS.M },
            { key: 'F', label: t('common.girls'), value: f, color: GENDER_COLORS.F },
          ]}
          format={format}
        />
      </ChartBlock>
    );
  };

  return (
    <Section id={id} className="scroll-mt-32" icon={<Users />} title={t('digital.groups.title')} subtitle={t('digital.groups.subtitle')}>
      <div className="space-y-7">
        <div>
          <BlockTitle className="mb-3">{t('digital.groups.byGrade')}</BlockTitle>
          <div className="grid gap-6 md:grid-cols-2">{(['screenTime', 'night'] as const).map(gradeChart)}</div>
          <p className="mt-2 text-[0.7rem] text-muted-foreground">{t('digital.groups.columnsNote')}</p>
        </div>
        <div>
          <BlockTitle className="mb-3">{t('digital.groups.byGender')}</BlockTitle>
          <div className="grid gap-6 md:grid-cols-2">
            {genderBlock('screenTime', t('metrics.screenTime.label'), (v) => fmt.value('screenTime', v))}
            {genderBlock('game', t('digital.groups.games'), (v) => fmt.pct(v))}
          </div>
        </div>
      </div>
    </Section>
  );
}

'use client';

import { BookHeart, BriefcaseBusiness, Compass, Gauge, Heart } from 'lucide-react';

import type { Interests, Scope } from '@/data/contracts';
import { Meter } from '@/features/mastery/kit/bars';
import { CountUpValue, KpiRow, KpiRowSkeleton, KpiTile } from '@/features/mastery/kit/kpi-tile';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

/** Kasbga tayyorgarlik: indeks, o'zgarish, hudud doirasida — respublika qiymati. */
function ReadinessTile({ stat, national }: { stat: Interests['careerReadiness']; national: number | null }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <KpiTile
      label={t('metrics.careerReadiness.label')}
      icon={<Gauge />}
      value={<CountUpValue metric="careerReadiness" value={stat.value} />}
      metric="careerReadiness"
      delta={stat.delta}
      note={national !== null ? t('dashboard.vsNationalShort', { value: fmt.value('careerReadiness', national) }) : t('interests.kpi.readinessNote')}
      footer={<Meter value={stat.value} />}
    />
  );
}

/** Qiziqishlar KPI qatori: yetakchi fan, qiziqish, kasbiy tip, soha va kasbga tayyorgarlik. */
export function InterestsKpis({ scope, data, nationalReadiness }: { scope: Scope; data: Interests | undefined; nationalReadiness: number | null }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  if (!data) return <KpiRowSkeleton />;
  const subject = data.subjects[0];
  const interest = data.general[0];
  const code = data.riasecTop[0];
  const field = data.careerFields[0];
  return (
    <KpiRow>
      <KpiTile
        label={t('interests.kpi.topSubject')}
        icon={<BookHeart />}
        textValue
        value={subject ? t(`enums.subject.${subject.key}`) : '—'}
        note={subject ? t('interests.kpi.chosenBy', { value: fmt.pct(subject.share) }) : undefined}
        footer={<Meter value={subject?.share ?? null} />}
      />
      <KpiTile
        label={t('interests.kpi.topInterest')}
        icon={<Heart />}
        textValue
        value={interest ? t(`enums.interest.${interest.key}`) : '—'}
        note={interest ? t('interests.kpi.chosenBy', { value: fmt.pct(interest.share) }) : undefined}
        footer={<Meter value={interest?.share ?? null} />}
      />
      <KpiTile
        label={t('interests.kpi.topCode')}
        icon={<Compass />}
        textValue
        value={code ? `${t(`enums.riasec.${code.key}`)} (${code.key})` : '—'}
        note={code ? t('interests.kpi.leadsFor', { value: fmt.pct(code.share) }) : undefined}
        footer={code ? <p className="text-[0.72rem] text-muted-foreground">{t(`enums.riasecHint.${code.key}`)}</p> : undefined}
      />
      <KpiTile
        label={t('interests.kpi.topField')}
        icon={<BriefcaseBusiness />}
        textValue
        value={field ? t(`enums.careerField.${field.key}`) : '—'}
        note={field ? t('interests.kpi.fieldShare', { value: fmt.pct(field.share) }) : undefined}
        footer={<Meter value={field?.share ?? null} barClassName="bg-gradient-to-r from-cyan-500 to-sky-400" />}
      />
      <ReadinessTile stat={data.careerReadiness} national={scope.kind === 'REGION' ? nationalReadiness : null} />
    </KpiRow>
  );
}

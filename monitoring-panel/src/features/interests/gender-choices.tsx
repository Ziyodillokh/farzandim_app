'use client';

import { UsersRound } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Interests } from '@/data/contracts';
import type { Subject } from '@/data/reference/domains';
import { SwatchLegend } from '@/features/mastery/kit/bars';
import { GENDER_COLORS } from '@/features/mastery/kit/colors';
import { Inset, Note } from '@/features/mastery/kit/layout';
import { gap } from '@/features/mastery/kit/num';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

type Pair = { key: Subject; boys: number; girls: number; diff: number | null };

/** Fanlar bo'yicha o'g'il / qiz tanlovi: umumiy ommaboplik tartibida. */
function pairs(data: Interests): Pair[] {
  const share = (g: 'M' | 'F', s: Subject) => data.byGender.find((x) => x.gender === g)?.subjects.find((x) => x.key === s)?.share ?? 0;
  return data.subjects
    .map((s) => {
      const boys = share('M', s.key);
      const girls = share('F', s.key);
      return { key: s.key, boys, girls, diff: gap(girls, boys) };
    })
    .filter((p) => p.boys > 0 || p.girls > 0);
}

function HalfBar({ value, max, color, side }: { value: number; max: number; color: string; side: 'left' | 'right' }) {
  const fmt = useMetricFormat();
  const bar = <span className="h-2.5 rounded-full transition-[width] duration-700" style={{ width: `${(value / max) * 100}%`, background: color }} />;
  const label = <span className="w-11 shrink-0 text-[0.72rem] font-semibold tabular-nums">{fmt.pct(value)}</span>;
  return (
    <span className={side === 'left' ? 'flex min-w-0 items-center justify-end gap-1.5 text-right' : 'flex min-w-0 items-center gap-1.5'}>
      {side === 'left' ? label : null}
      <span className={side === 'left' ? 'flex min-w-0 flex-1 justify-end' : 'flex min-w-0 flex-1'}>{bar}</span>
      {side === 'right' ? label : null}
    </span>
  );
}

/** "Kapalak" diagramma: chapda o'g'il bolalar, o'ngda qiz bolalar. */
export function GenderChoicesSection({ data, className }: { data: Interests | undefined; className?: string }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const rows = data ? pairs(data) : [];
  const max = Math.max(1, ...rows.flatMap((r) => [r.boys, r.girls]));
  const withDiff = rows.filter((r): r is Pair & { diff: number } => r.diff !== null);
  const boysLean = [...withDiff].sort((a, b) => a.diff - b.diff)[0];
  const girlsLean = [...withDiff].sort((a, b) => b.diff - a.diff)[0];
  const pp = (v: number) => `+${fmt.num(Math.abs(v), 1)} ${t('common.units.pp')}`;
  return (
    <Section id="interests-gender" icon={<UsersRound />} title={t('interests.sections.gender')} subtitle={t('interests.sections.genderSub')} className={className}>
      {!data ? (
        <Skeleton className="h-[360px] w-full rounded-xl" />
      ) : (
        <div className="space-y-4">
          <SwatchLegend
            className="justify-center"
            items={[
              { key: 'M', label: t('common.boys'), color: GENDER_COLORS.M },
              { key: 'F', label: t('common.girls'), color: GENDER_COLORS.F },
            ]}
          />
          <ul className="space-y-1.5">
            {rows.map((r) => (
              <li key={r.key} className="grid grid-cols-[minmax(0,1fr)_6.5rem_minmax(0,1fr)] items-center gap-2 sm:grid-cols-[minmax(0,1fr)_8rem_minmax(0,1fr)]">
                <HalfBar value={r.boys} max={max} color={GENDER_COLORS.M} side="left" />
                <span className="truncate text-center text-[0.76rem] font-medium">{t(`enums.subject.${r.key}`)}</span>
                <HalfBar value={r.girls} max={max} color={GENDER_COLORS.F} side="right" />
              </li>
            ))}
          </ul>
          {boysLean && girlsLean && boysLean.diff < 0 && girlsLean.diff > 0 && (
            <Inset className="space-y-0.5 py-2.5 text-[0.78rem]">
              <p>{t('interests.gender.boysLean', { subject: t(`enums.subject.${boysLean.key}`), value: pp(boysLean.diff) })}</p>
              <p>{t('interests.gender.girlsLean', { subject: t(`enums.subject.${girlsLean.key}`), value: pp(girlsLean.diff) })}</p>
            </Inset>
          )}
          <Note>{t('interests.gender.note')}</Note>
        </div>
      )}
    </Section>
  );
}

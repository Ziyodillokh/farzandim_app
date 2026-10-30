'use client';

import { Layers3, UsersRound } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Mastery } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { DIFFICULTY_COLORS, DIFFICULTY_LEVELS, hasDifficulty } from './difficulty';
import { CompareBars, StackBar } from './kit/bars';
import { GENDER_COLORS } from './kit/colors';
import { GenderGapNote } from './kit/gender-gap';
import { Note, SubHeading } from './kit/layout';

function GenderBlock({ data }: { data: Mastery }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const value = (g: 'M' | 'F') => data.byGender.find((x) => x.gender === g)?.value ?? null;
  return (
    <div>
      <SubHeading>{t('mastery.sections.gender')}</SubHeading>
      <div className="space-y-4">
        <CompareBars
          rows={[
            { key: 'M', label: t('common.boys'), value: value('M'), color: GENDER_COLORS.M },
            { key: 'F', label: t('common.girls'), value: value('F'), color: GENDER_COLORS.F },
          ]}
          format={(v) => fmt.value('mastery', v)}
        />
        <GenderGapNote boys={value('M')} girls={value('F')} unit={t('common.units.pp')} />
      </div>
    </div>
  );
}

function SchoolTypeBlock({ data }: { data: Mastery }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const average = t('mastery.groups.avgMarker', { value: fmt.value('mastery', data.overall.value) });
  return (
    <div>
      <SubHeading>{t('mastery.sections.schoolType')}</SubHeading>
      <div className="space-y-3">
        <CompareBars
          rows={data.bySchoolType.map((s) => ({ key: s.type, label: t(`enums.schoolType.${s.type}`), value: s.value, marker: data.overall.value }))}
          format={(v) => fmt.value('mastery', v)}
          markerLabel={average}
        />
        <Note>
          {average}. {t('mastery.groups.schoolNote')}
        </Note>
      </div>
    </div>
  );
}

/** Guruhlar kesimi: jins va maktab turi bo'yicha o'rtacha o'zlashtirish. */
export function GroupsSection({ data }: { data: Mastery | undefined }) {
  const { t } = useI18n();
  return (
    <Section id="mastery-groups" icon={<UsersRound />} title={t('mastery.sections.groups')} subtitle={t('mastery.sections.groupsSub')}>
      {!data ? (
        <Skeleton className="h-[260px] w-full rounded-xl" />
      ) : (
        <div className="grid gap-6 md:grid-cols-2">
          <GenderBlock data={data} />
          <SchoolTypeBlock data={data} />
        </div>
      )}
    </Section>
  );
}

/** Adaptiv qiyinlik: 100% yig'ma ustun va har darajaning izohi. */
export function DifficultySection({ data, className }: { data: Mastery | undefined; className?: string }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const ok = data ? hasDifficulty(data.difficulty) : false;
  return (
    <Section id="mastery-difficulty" icon={<Layers3 />} title={t('mastery.sections.difficulty')} subtitle={t('mastery.sections.difficultySub')} className={className}>
      {!data ? (
        <Skeleton className="h-[200px] w-full rounded-xl" />
      ) : !ok ? (
        <Note>{t('common.noData')}</Note>
      ) : (
        <div className="space-y-4">
          <StackBar
            className="h-3.5"
            parts={DIFFICULTY_LEVELS.map((k) => ({ key: k, label: t(`enums.difficulty.${k}`), value: data.difficulty[k], color: DIFFICULTY_COLORS[k] }))}
          />
          <ul className="space-y-2.5">
            {DIFFICULTY_LEVELS.map((k) => (
              <li key={k} className="flex items-start gap-2.5 text-[0.8rem]">
                <span aria-hidden className="mt-1 h-2.5 w-2.5 shrink-0 rounded-sm" style={{ background: DIFFICULTY_COLORS[k] }} />
                <span className="min-w-0 flex-1">
                  <span className="flex items-baseline justify-between gap-3">
                    <span className="font-medium">{t(`enums.difficulty.${k}`)}</span>
                    <span className="font-semibold tabular-nums">{fmt.pct(data.difficulty[k])}</span>
                  </span>
                  <span className="block text-[0.72rem] text-muted-foreground">{t(`mastery.difficulty.${k}`)}</span>
                </span>
              </li>
            ))}
          </ul>
          <Note>{t('mastery.difficulty.hint')}</Note>
        </div>
      )}
    </Section>
  );
}

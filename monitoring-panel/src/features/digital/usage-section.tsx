'use client';

import { ChartPie } from 'lucide-react';

import { Donut } from '@/components/charts/donut';
import { ShareBars } from '@/components/charts/share-bars';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Digital } from '@/data/contracts';
import type { Mood } from '@/data/reference/domains';
import { ChartBlock } from '@/features/wellbeing/kit/chart-block';
import { StackedShare } from '@/features/wellbeing/kit/stacked-share';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { HourProfile } from './hour-profile';

type MoodGroup = 'positive' | 'neutral' | 'low';

/** Kayfiyat guruhlari: ijobiy, o'ychan va charchoq/xafalik/jahl (yumshoq, qizilsiz ranglar). */
const MOOD_GROUP: Record<Mood, MoodGroup> = {
  HAPPY: 'positive',
  EXCITED: 'positive',
  LOVE: 'positive',
  WINKING: 'positive',
  THINKING: 'neutral',
  TIRED: 'low',
  SAD: 'low',
  ANGRY: 'low',
};

const GROUP_COLORS: Record<MoodGroup, string> = {
  positive: 'hsl(160 64% 42%)',
  neutral: 'hsl(220 22% 70%)',
  low: 'hsl(40 92% 54%)',
};

function MoodPanel({ moods }: { moods: Digital['moods'] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const groupShare = (g: MoodGroup) => moods.filter((m) => MOOD_GROUP[m.key] === g).reduce((s, m) => s + m.share, 0);
  const sorted = [...moods].sort((a, b) => b.share - a.share);
  const half = Math.ceil(sorted.length / 2);
  const top = Math.max(1, ...sorted.map((m) => m.share));
  const toRows = (list: typeof sorted) => list.map((m) => ({ key: m.key, label: t(`enums.mood.${m.key}`), share: m.share, color: GROUP_COLORS[MOOD_GROUP[m.key]] }));
  return (
    <ChartBlock title={t('digital.usage.moods')} aside={<span className="text-[0.7rem] text-muted-foreground">{t('digital.usage.moodNote')}</span>}>
      <StackedShare
        segments={[
          { key: 'positive', label: t('digital.usage.moodPositive'), value: groupShare('positive'), color: GROUP_COLORS.positive },
          { key: 'neutral', label: t('digital.usage.moodNeutral'), value: groupShare('neutral'), color: GROUP_COLORS.neutral },
          { key: 'low', label: t('digital.usage.moodLow'), value: groupShare('low'), color: GROUP_COLORS.low },
        ]}
        format={(v) => fmt.pct(v)}
      />
      <div className="mt-5 grid gap-x-8 gap-y-2.5 sm:grid-cols-2">
        <ShareBars rows={toRows(sorted.slice(0, half))} max={top} />
        <ShareBars rows={toRows(sorted.slice(half))} max={top} />
      </div>
    </ChartBlock>
  );
}

/** Foydalanish tarkibi: ilova toifalari, 24 soatlik profil va kayfiyat belgilari (agregat). */
export function UsageSection({ id, data }: { id: string; data: Digital | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <Section id={id} className="scroll-mt-32" icon={<ChartPie />} title={t('digital.usage.title')} subtitle={t('digital.usage.subtitle')}>
      {!data ? (
        <Skeleton className="h-[520px] w-full rounded-xl" />
      ) : (
        <div className="space-y-8">
          <div className="grid gap-8 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.3fr)]">
            <ChartBlock title={t('digital.usage.categories')}>
              <Donut
                size={168}
                thickness={22}
                slices={data.categories.map((c) => ({ key: c.key, label: t(`enums.appCategory.${c.key}`), value: c.share }))}
                centerValue={fmt.value('screenTime', data.screenTime.value)}
                centerLabel={t('common.units.perDay')}
              />
            </ChartBlock>
            <HourProfile hourly={data.hourly} />
          </div>
          <MoodPanel moods={data.moods} />
        </div>
      )}
    </Section>
  );
}

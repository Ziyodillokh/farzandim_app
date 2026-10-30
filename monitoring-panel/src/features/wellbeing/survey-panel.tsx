'use client';

import { MessageCircleHeart } from 'lucide-react';

import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Wellbeing } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { deltaTone, TONE_TEXT, useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { LEVEL_FILL, LEVEL_GOOD, LEVEL_MIDDLE, LevelBadge } from './level';

type Topic = Wellbeing['topics'][number];

/** Mavzu shkalasi: 0–100, 60 va 72 chegaralari, respublika belgisi (hudud doirasida). */
function TopicBar({ topic, showNational }: { topic: Topic; showNational: boolean }) {
  const pct = (v: number) => `${Math.min(100, Math.max(0, v))}%`;
  return (
    <div className="relative h-2.5 rounded-full bg-muted/70">
      {topic.score !== null && topic.level && (
        <span className="absolute inset-y-0 left-0 rounded-full transition-[width] duration-700" style={{ width: pct(topic.score), background: LEVEL_FILL[topic.level] }} />
      )}
      {[LEVEL_MIDDLE, LEVEL_GOOD].map((tick) => (
        <span key={tick} aria-hidden className="absolute inset-y-0 w-px bg-card/90" style={{ left: pct(tick) }} />
      ))}
      {showNational && topic.national !== null && (
        <span aria-hidden className="absolute -top-1 h-[18px] w-0.5 -translate-x-1/2 rounded-full bg-foreground/60" style={{ left: pct(topic.national) }} />
      )}
    </div>
  );
}

/** "Bola ovozi" mavzulari: ball, daraja va (hudud doirasida) respublika bilan farq. */
export function SurveyPanel({ id, data, regionScope }: { id: string; data: Wellbeing | undefined; regionScope: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <Section id={id} className="scroll-mt-32" icon={<MessageCircleHeart />} title={t('wellbeing.survey.title')} subtitle={t('wellbeing.survey.subtitle')}>
      {!data ? (
        <Skeleton className="h-[360px] w-full rounded-xl" />
      ) : (
        <div className="space-y-5">
          <ul className="space-y-4">
            {data.topics.map((tp) => {
              const diff = tp.score !== null && tp.national !== null ? tp.score - tp.national : null;
              return (
                <li key={tp.topic}>
                  <div className="mb-1.5 flex items-center justify-between gap-3 text-[0.84rem]">
                    <span className="min-w-0 font-medium">{t(`enums.wellbeingTopic.${tp.topic}`)}</span>
                    <span className="flex shrink-0 items-center gap-2">
                      <b className="font-display text-[1.02rem] font-semibold tabular-nums">{tp.score ?? '—'}</b>
                      <LevelBadge level={tp.level} />
                    </span>
                  </div>
                  <TopicBar topic={tp} showNational={regionScope} />
                  {regionScope && tp.national !== null && (
                    <p className="mt-1 flex gap-1.5 text-[0.7rem] text-muted-foreground">
                      <span className="tabular-nums">{t('dashboard.vsNationalShort', { value: tp.national })}</span>
                      {diff !== null && <span className={cn('tabular-nums', TONE_TEXT[deltaTone('wellbeing', diff, 0.5)])}>({fmt.delta('wellbeing', diff)})</span>}
                    </p>
                  )}
                </li>
              );
            })}
          </ul>
          <p className="text-[0.72rem] text-muted-foreground">{t('wellbeing.survey.thresholds')}</p>
          <ScreeningDisclaimer />
        </div>
      )}
    </Section>
  );
}

'use client';

import { ArrowRight, Info, Lightbulb, Sparkles, TrendingDown } from 'lucide-react';
import type { ReactNode } from 'react';

import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { CareAggregate, CareTopic } from '@/data/contracts';
import type { CareBreakdown } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { type CareInsight, computeInsights } from '../lib/insights';
import { groupLabel } from '../lib/labels';

const STYLES: Record<CareInsight['kind'], { icon: ReactNode; tone: string }> = {
  BELOW: { icon: <TrendingDown />, tone: 'bg-warning/15 text-warning' },
  ABOVE: { icon: <Sparkles />, tone: 'bg-success/10 text-success' },
  LOWEST_TOPIC: { icon: <Lightbulb />, tone: 'bg-primary/10 text-primary' },
};

/** Xulosalar — faqat ko'rinadigan guruhlar asosida (yashirin guruh haqida xulosa yo'q). */
export function InsightsCard({
  aggregate,
  loading,
  breakdown,
  onSelectTopic,
}: {
  aggregate: CareAggregate | undefined;
  loading?: boolean;
  breakdown: CareBreakdown;
  onSelectTopic: (topic: CareTopic) => void;
}) {
  const { t } = useI18n();
  const insights = aggregate ? computeInsights(aggregate) : [];

  const text = (insight: CareInsight): string => {
    const topic = t(`enums.careTopic.${insight.topic}`);
    if (insight.kind === 'LOWEST_TOPIC') return t('care.overview.insightLowestTopic', { topic, score: insight.score });
    const group = groupLabel(t, breakdown, insight.group);
    return insight.kind === 'BELOW'
      ? t('care.overview.insightBelow', { group, topic, delta: insight.delta })
      : t('care.overview.insightAbove', { group, topic, delta: insight.delta });
  };

  const hasComparisons = insights.some((i) => i.kind !== 'LOWEST_TOPIC');

  return (
    <SectionCard title={t('care.overview.insightsTitle')} description={t('care.overview.insightsHint')} className="flex flex-col" bodyClassName="flex flex-1 flex-col">
      {loading && !aggregate ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }, (_, i) => (
            <Skeleton key={i} className="h-14 w-full rounded-lg" />
          ))}
        </div>
      ) : (
        <ul className="space-y-2.5">
          {insights.map((insight) => (
            <li key={`${insight.kind}-${insight.kind === 'LOWEST_TOPIC' ? '' : insight.group.key}-${insight.topic}`}>
              <button
                type="button"
                onClick={() => onSelectTopic(insight.topic)}
                className="group flex w-full items-start gap-3 rounded-lg border border-transparent bg-muted/40 p-3 text-left transition-colors hover:border-primary/20 hover:bg-primary/[0.04]"
                title={t('care.overview.showOnChart')}
              >
                <span className={cn('flex h-8 w-8 shrink-0 items-center justify-center rounded-lg [&_svg]:size-4', STYLES[insight.kind].tone)}>
                  {STYLES[insight.kind].icon}
                </span>
                <span className="flex-1 text-sm leading-snug">{text(insight)}</span>
                <ArrowRight className="mt-1 h-3.5 w-3.5 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
              </button>
            </li>
          ))}
          {!hasComparisons && (
            <li className="rounded-lg border border-dashed p-3 text-sm text-muted-foreground">
              {breakdown === 'SCHOOL' ? t('care.overview.insightSchoolOnly') : t('care.overview.insightNone')}
            </li>
          )}
        </ul>
      )}
      <p className="mt-auto flex items-start gap-2 pt-4 text-xs text-muted-foreground">
        <Info className="mt-0.5 h-3.5 w-3.5 shrink-0" />
        {t('care.overview.insightDisclaimer')}
      </p>
    </SectionCard>
  );
}

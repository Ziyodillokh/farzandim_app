'use client';

import type { CareTopic } from '@/data/contracts';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { CARE_TOPICS } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { scoreLevel, type ScoreLevel } from '../lib/insights';
import { TOPIC_ICONS } from '../lib/labels';

const LEVEL_STYLES: Record<ScoreLevel, { chip: string; bar: string; icon: string }> = {
  GOOD: { chip: 'bg-success/10 text-success', bar: 'bg-success', icon: 'bg-success/10 text-success' },
  MIDDLE: { chip: 'bg-primary/10 text-primary', bar: 'bg-primary', icon: 'bg-primary/10 text-primary' },
  LOW: { chip: 'bg-warning/15 text-warning', bar: 'bg-warning', icon: 'bg-warning/15 text-warning' },
};

/** Mavzular bo'yicha 0..100 ko'rsatkichlar (maktab bo'yicha, k ≥ 5). */
export function TopicScoreCards({
  overall,
  loading,
}: {
  overall: Partial<Record<CareTopic, number>> | undefined;
  loading?: boolean;
}) {
  const { t } = useI18n();
  if (loading) {
    return (
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        {Array.from({ length: 5 }, (_, i) => (
          <Skeleton key={i} className="h-32 rounded-xl" />
        ))}
      </div>
    );
  }
  const topics = CARE_TOPICS.filter((topic) => overall?.[topic] !== undefined);
  if (topics.length === 0) return null;
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
      {topics.map((topic) => {
        const score = overall?.[topic] ?? 0;
        const level = scoreLevel(score);
        const styles = LEVEL_STYLES[level];
        const Icon = TOPIC_ICONS[topic];
        return (
          <Card key={topic} className="card-glow flex flex-col gap-3 p-4 animate-fade-in">
            <div className="flex items-start justify-between gap-2">
              <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl', styles.icon)}>
                <Icon className="h-4 w-4" />
              </span>
              <span className={cn('rounded-full px-2 py-0.5 text-2xs font-semibold', styles.chip)}>
                {t(`care.overview.level.${level}`)}
              </span>
            </div>
            <p className="min-h-[2.5rem] text-sm font-medium leading-snug text-muted-foreground">{t(`enums.careTopic.${topic}`)}</p>
            <div>
              <p className="font-display text-2xl font-semibold tabular-nums">
                {score}
                <span className="ml-0.5 text-sm font-normal text-muted-foreground">/100</span>
              </p>
              <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-muted" aria-hidden>
                <div className={cn('h-full rounded-full transition-all duration-700', styles.bar)} style={{ width: `${score}%` }} />
              </div>
            </div>
          </Card>
        );
      })}
    </div>
  );
}

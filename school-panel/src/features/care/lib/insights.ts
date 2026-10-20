import type { CareAggregate, CareAggregateGroup, CareTopic } from '@/data/contracts';
import { CARE_TOPICS } from '@/data/schemas/care';

/**
 * Insight'lar FAQAT ko'rinadigan (k ≥ 5) guruhlardan va maktab o'rtachasidan
 * hisoblanadi — yashirilgan guruh haqida hech qanday xulosa chiqarilmaydi.
 */
export type CareInsight =
  | { kind: 'BELOW'; group: CareAggregateGroup; topic: CareTopic; delta: number }
  | { kind: 'ABOVE'; group: CareAggregateGroup; topic: CareTopic; delta: number }
  | { kind: 'LOWEST_TOPIC'; topic: CareTopic; score: number };

export const INSIGHT_THRESHOLD = 8;
const MAX_BELOW = 3;

export type ScoreLevel = 'GOOD' | 'MIDDLE' | 'LOW';

export function scoreLevel(score: number): ScoreLevel {
  if (score >= 72) return 'GOOD';
  if (score >= 60) return 'MIDDLE';
  return 'LOW';
}

/** Tanlangan mavzu (yoki o'rtacha) bo'yicha guruh qiymati. */
export function groupScore(scores: Partial<Record<CareTopic, number>> | null, topic: CareTopic | 'AVERAGE'): number | null {
  if (!scores) return null;
  if (topic !== 'AVERAGE') return scores[topic] ?? null;
  const values = Object.values(scores);
  return values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : null;
}

export function computeInsights(aggregate: CareAggregate): CareInsight[] {
  const visible = aggregate.groups.filter((g) => !g.hidden && g.topicScores);
  const deltas = visible.flatMap((group) =>
    CARE_TOPICS.flatMap((topic) => {
      const value = group.topicScores?.[topic];
      const base = aggregate.overall[topic];
      return value === undefined || base === undefined ? [] : [{ group, topic, delta: value - base }];
    }),
  );
  const below: CareInsight[] = visible.length > 1
    ? deltas
        .filter((d) => d.delta <= -INSIGHT_THRESHOLD)
        .sort((a, b) => a.delta - b.delta)
        .slice(0, MAX_BELOW)
        .map((d) => ({ kind: 'BELOW', group: d.group, topic: d.topic, delta: Math.abs(d.delta) }))
    : [];
  const best = visible.length > 1 ? [...deltas].sort((a, b) => b.delta - a.delta)[0] : undefined;
  const above: CareInsight[] = best && best.delta >= INSIGHT_THRESHOLD ? [{ kind: 'ABOVE', group: best.group, topic: best.topic, delta: best.delta }] : [];
  const lowest = (Object.entries(aggregate.overall) as Array<[CareTopic, number]>).sort((a, b) => a[1] - b[1])[0];
  const lowestTopic: CareInsight[] = lowest ? [{ kind: 'LOWEST_TOPIC', topic: lowest[0], score: lowest[1] }] : [];
  return [...below, ...above, ...lowestTopic];
}

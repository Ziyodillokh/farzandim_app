import type { MetricKey } from '@/data/contracts';

/**
 * Hududlar jadvali va solishtirish uchun ko'rsatkich guruhlari (yagona manba).
 * Qamrov (coverage) guruhlarga kirmaydi — jadvalda doimiy ustun, solishtirishda kartada.
 */
export const METRIC_GROUPS = [
  { key: 'learning', metrics: ['mastery', 'success', 'iqMean', 'iqParticipation'] },
  { key: 'wellbeing', metrics: ['wellbeing', 'bullying', 'anxiety'] },
  { key: 'attendance', metrics: ['attendance', 'chronic', 'screenTime', 'night'] },
] as const satisfies ReadonlyArray<{ key: string; metrics: readonly MetricKey[] }>;

export type MetricGroupKey = (typeof METRIC_GROUPS)[number]['key'];

export function groupMetrics(key: MetricGroupKey): readonly MetricKey[] {
  return METRIC_GROUPS.find((g) => g.key === key)?.metrics ?? METRIC_GROUPS[0].metrics;
}

/** Solishtirishdagi barcha ko'rsatkichlar (guruhlar tartibida). */
export const COMPARE_METRICS: readonly MetricKey[] = METRIC_GROUPS.flatMap((g) => [...g.metrics]);

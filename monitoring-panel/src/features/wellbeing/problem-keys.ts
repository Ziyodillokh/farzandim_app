import type { MetricKey } from '@/data/contracts';
import { PROBLEM_METRICS } from '@/data/mock/services/overview';
import type { TKey } from '@/i18n';

/** `enums.problem.*` kalitlari bor signallar (PROBLEM_METRICS bilan bir xil). */
export type ProblemKey = 'bullying' | 'anxiety' | 'support' | 'sleep' | 'safetyGap' | 'chronic' | 'night';

const PROBLEM_KEYS: ReadonlySet<string> = new Set<ProblemKey>(['bullying', 'anxiety', 'support', 'sleep', 'safetyGap', 'chronic', 'night']);

export function isProblemKey(metric: MetricKey): metric is ProblemKey {
  return PROBLEM_KEYS.has(metric);
}

/** Signal nomi: muammo lug'atidan, bo'lmasa — ko'rsatkich qisqa nomi. */
export function problemLabelKey(metric: MetricKey): TKey {
  return isProblemKey(metric) ? `enums.problem.${metric}` : `metrics.${metric}.label`;
}

/** Xaritada tanlanadigan farovonlik ko'rsatkichlari. */
export const WELLBEING_MAP_METRICS: readonly MetricKey[] = ['bullying', 'anxiety', 'support', 'sleep', 'safetyGap', 'wellbeing'];

export { PROBLEM_METRICS };

import type { PsychNorms, PsychResult, PsychTest, ScoredResult, TemplateId, TemplateState } from '@/data/contracts';
import { scoreResult } from '@/lib/psych/scoring';
import { PSYCH_TEMPLATES } from '../seed/psych-templates';
import { TEMPLATE_IDS } from '../seed/psych-templates/specs';
import type { Tables } from '../tables';

/** Shablonlar kodda; maktab holati (status, me'yor o'zgarishi) jadvalda. */
export function defaultTemplateState(): Record<TemplateId, TemplateState> {
  return Object.fromEntries(TEMPLATE_IDS.map((id) => [id, { status: 'PUBLISHED', norms: null }])) as Record<TemplateId, TemplateState>;
}

export function isTemplateId(id: string): id is TemplateId {
  return (TEMPLATE_IDS as string[]).includes(id);
}

function templateWithState(id: TemplateId, state: TemplateState | undefined): PsychTest {
  const base = PSYCH_TEMPLATES[id];
  return { ...base, status: state?.status ?? base.status, norms: state?.norms ?? base.norms };
}

/** Barcha testlar: shablonlar (holat qo'llangan) + maktabning o'z / import qilingan testlari. */
export function allTests(t: Pick<Tables, 'psychTests' | 'psychTemplateState'>): PsychTest[] {
  return [...TEMPLATE_IDS.map((id) => templateWithState(id, t.psychTemplateState?.[id])), ...(t.psychTests ?? [])];
}

export function findTest(t: Pick<Tables, 'psychTests' | 'psychTemplateState'>, id: string): PsychTest | undefined {
  if (isTemplateId(id)) return templateWithState(id, t.psychTemplateState?.[id]);
  return t.psychTests?.find((x) => x.id === id);
}

export function effectiveNorms(t: Pick<Tables, 'psychTests' | 'psychTemplateState'>, test: PsychTest): PsychNorms {
  return findTest(t, test.id)?.norms ?? test.norms;
}

/** Saqlangan natija → hisoblangan (standart ball, persentil, daraja — o'qishda). */
export function scoreStored(t: Pick<Tables, 'psychTests' | 'psychTemplateState'>, r: PsychResult): ScoredResult | null {
  const test = findTest(t, r.testId);
  if (!test) return null;
  return { ...r, ...scoreResult(test, r) };
}

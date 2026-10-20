import type { IsoDate } from '@/data/contracts';
import type { Tables } from '../tables';
import { defaultTemplateState } from './catalog';
import { buildHistoryConfig } from './history-config';
import { seedAssessments } from './seed-assessments';

type PsychTables = Pick<Tables, 'psychTests' | 'psychTemplateState' | 'psychAssignments' | 'psychResults' | 'psychHistory'>;

/** Psixologik testlar seed'i — saqlangan sinf/o'quvchilardan (migratsiyada ham ishlaydi). */
export function buildPsychSeed(t: Pick<Tables, 'classes' | 'students'>, anchor: IsoDate, seed: number): PsychTables {
  return {
    psychTests: [],
    psychTemplateState: defaultTemplateState(),
    ...seedAssessments(t, anchor, seed),
    psychHistory: buildHistoryConfig(anchor, seed),
  };
}

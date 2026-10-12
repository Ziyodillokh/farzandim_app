import type { IsoDate } from '@/data/contracts';
import type { Tables } from '../tables';

/** Jonli seed-tayinlashlar va ilovadagi natijalar (agent A to'ldiradi). */
export function seedAssessments(
  _t: Pick<Tables, 'classes' | 'students'>,
  _anchor: IsoDate,
  _seed: number,
): Pick<Tables, 'psychAssignments' | 'psychResults'> {
  void _t;
  void _anchor;
  void _seed;
  return { psychAssignments: [], psychResults: [] };
}

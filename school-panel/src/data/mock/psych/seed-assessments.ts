import type { AssignmentTarget, IsoDate, PsychAssignment, PsychResult, TemplateId } from '@/data/contracts';
import { unitHash } from '@/lib/rng';
import { addDays } from '../calendar';
import { PSYCH_TEMPLATES } from '../seed/psych-templates';
import type { Tables } from '../tables';
import { buildAppResult, hhmm, takeChance, targetStudents } from './sim';

/**
 * Jonli seed-tayinlashlar (deterministik: qat'iy ID'lar, `Date.now()`/`Math.random` yo'q).
 * pa-1 — mantiqiy fikrlash (7-A, 7-B), ~55% yakunlagan; pa-2 — hissiy holat, ~45%;
 * pa-3 — kasbiy qiziqish (9–11-sinflar), keyingi haftaga rejalashtirilgan.
 * Seed'dagi yakunlaganlar — simulyatordagi qatnashuvchilarning (~85%) bir qismi.
 */
const PSYCHOLOGIST = 'stf-psychologist';
const FIRST_MINUTE = 9 * 60;
const MINUTE_SPAN = 10 * 60;
const SEED_DAYS = 3;

type SeedSpec = { id: string; testId: TemplateId; target: AssignmentTarget; opensDay: number; closesDay: number; share: number };

const SPECS: readonly SeedSpec[] = [
  { id: 'pa-1', testId: 'tpl-logic', target: { kind: 'CLASSES', classIds: ['cls-7a', 'cls-7b'] }, opensDay: -3, closesDay: 4, share: 0.55 },
  { id: 'pa-2', testId: 'tpl-emotion', target: { kind: 'CLASSES', classIds: ['cls-7a', 'cls-7b'] }, opensDay: -3, closesDay: 4, share: 0.45 },
  { id: 'pa-3', testId: 'tpl-career', target: { kind: 'GRADES', grades: [9, 10, 11] }, opensDay: 7, closesDay: 14, share: 0 },
];

function classIdsFor(t: Pick<Tables, 'classes'>, spec: SeedSpec): string[] {
  const grades = PSYCH_TEMPLATES[spec.testId].grades;
  return t.classes
    .filter((c) => grades.includes(c.grade))
    .filter((c) => (spec.target.kind === 'CLASSES' ? spec.target.classIds.includes(c.id) : spec.target.grades.includes(c.grade)))
    .map((c) => c.id);
}

function buildAssignment(t: Pick<Tables, 'classes' | 'students'>, spec: SeedSpec, anchor: IsoDate): PsychAssignment {
  const classIds = classIdsFor(t, spec);
  const invited = t.students.filter((s) => !s.archived && classIds.includes(s.classId)).length;
  return {
    id: spec.id,
    testId: spec.testId,
    testVersion: PSYCH_TEMPLATES[spec.testId].version,
    target: spec.target,
    classIds,
    opensAt: `${addDays(anchor, spec.opensDay)}T08:00:00`,
    closesAt: `${addDays(anchor, spec.closesDay)}T18:00:00`,
    status: 'OPEN',
    invited,
    consent: 'PARENTS_INFORMED',
    createdBy: PSYCHOLOGIST,
    createdAt: `${addDays(anchor, spec.opensDay - 1)}T15:00:00`,
  };
}

/** Langar kunidan oldingi 3 kunda (09:00–19:00) yakunlangan natijalar. */
function seedResults(t: Pick<Tables, 'classes' | 'students'>, a: PsychAssignment, spec: SeedSpec, anchor: IsoDate, seed: number): PsychResult[] {
  const test = PSYCH_TEMPLATES[spec.testId];
  return targetStudents(t, a)
    .filter(({ student }) => takeChance(a.id, student.id) < spec.share)
    .map(({ student, cls }) => {
      const day = addDays(anchor, -SEED_DAYS + Math.floor(unitHash(a.id, student.id, 'seed-day') * SEED_DAYS));
      const minute = FIRST_MINUTE + Math.floor(unitHash(a.id, student.id, 'seed-minute') * MINUTE_SPAN);
      return buildAppResult(test, student, cls, a, `${day}T${hhmm(minute)}:00`, `${a.id}:${seed}`);
    });
}

export function seedAssessments(
  t: Pick<Tables, 'classes' | 'students'>,
  anchor: IsoDate,
  seed: number,
): Pick<Tables, 'psychAssignments' | 'psychResults'> {
  const assignments = SPECS.map((spec) => buildAssignment(t, spec, anchor));
  const results = SPECS.flatMap((spec, i) => {
    const a = assignments[i];
    return a && spec.share > 0 ? seedResults(t, a, spec, anchor, seed) : [];
  });
  return { psychAssignments: assignments, psychResults: results };
}

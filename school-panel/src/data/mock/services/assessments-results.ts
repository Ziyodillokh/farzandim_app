import { roleHas } from '@/auth/permissions';
import type {
  AgeBand,
  AssignmentState,
  Localized,
  PsychAssignment,
  PsychResult,
  PsychResultOrigin,
  PsychTest,
  PsychTestKind,
  ScaleScore,
  ScoreBand,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { CAREER_ORDER } from '@/lib/psych/scoring';
import { unitHash } from '@/lib/rng';
import { toLocalIso, toIsoDate } from '../calendar';
import { clockNow } from '../clock';
import { type Actor, assertCan, assertClassInScope, currentActor, inScope, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { findTest, scoreStored } from '../psych/catalog';
import { allResults } from '../psych/results';
import { buildAppResult, resultId, targetStudents, upsertTestCompleted } from '../psych/sim';
import type { Tables } from '../tables';

/**
 * Natijalar va tayinlash holati. Natijalar o'qishda hisoblanadi (standart ball, daraja).
 * Sinf rahbari (development.individual) — faqat o'z sinfi va faqat darajalar (xom ball,
 * javoblar yo'q). Auditda o'quvchi ismi, ball yoki javob YO'Q.
 */
export const ABILITY_BANDS: readonly ScoreBand[] = ['VERY_LOW', 'LOW', 'AVERAGE', 'HIGH', 'VERY_HIGH'];
export const CONCERN_BANDS: readonly ScoreBand[] = ['TYPICAL', 'WATCH', 'SUPPORT'];

export type AssignmentRow = PsychAssignment & {
  state: AssignmentState;
  completed: number;
  testTitle: Localized;
  testKind: PsychTestKind | null;
  classNames: string[];
};
export type ResultScale = Pick<ScaleScore, 'key' | 'band'> & Partial<Omit<ScaleScore, 'key' | 'band'>>;
export type ResultRow = {
  id: string;
  studentId: string;
  studentName: string;
  classId: string;
  className: string;
  takenAt: string;
  origin: PsychResultOrigin;
  assignmentId: string | null;
  ageBand: AgeBand;
  scales: ResultScale[];
  topCodes: string | null;
  durationSec?: number;
  answers?: string;
};
export type BandBucket = { band: string; count: number };
export type ResultsByTest = {
  rows: ResultRow[];
  distribution: BandBucket[];
  /** Taqsimot qaysi shkala bo'yicha (`null` — shkala yo'q yoki me'yor kiritilmagan). */
  scaleKey: string | null;
  needsNorms: boolean;
  participation: { invited: number; completed: number };
  bandsOnly: boolean;
};
export type ResultsFilter = { classId?: string; assignmentId?: string; scale?: string };

export function nowIso(): string {
  return toLocalIso(clockNow());
}

/** Holat oynadan va statusdan: bekor → CANCELLED, yopilgan/o'tgan → ENDED. */
export function assignmentState(a: Pick<PsychAssignment, 'status' | 'opensAt' | 'closesAt'>, nowMs: number): AssignmentState {
  if (a.status === 'CANCELLED') return 'CANCELLED';
  if (a.status === 'CLOSED' || nowMs > Date.parse(a.closesAt)) return 'ENDED';
  return nowMs < Date.parse(a.opensAt) ? 'SCHEDULED' : 'ACTIVE';
}

export function completedByAssignment(t: Pick<Tables, 'psychResults'>): Map<string, number> {
  const counts = new Map<string, number>();
  for (const r of t.psychResults ?? []) if (r.assignmentId) counts.set(r.assignmentId, (counts.get(r.assignmentId) ?? 0) + 1);
  return counts;
}

export function toAssignmentRow(t: Tables, a: PsychAssignment, nowMs: number, completed: ReadonlyMap<string, number>): AssignmentRow {
  const test = findTest(t, a.testId);
  const names = new Map(t.classes.map((c) => [c.id, c.name]));
  return {
    ...a,
    state: assignmentState(a, nowMs),
    completed: completed.get(a.id) ?? 0,
    testTitle: test?.title ?? { uz: a.testId, ru: a.testId },
    testKind: test?.kind ?? null,
    classNames: a.classIds.map((id) => names.get(id) ?? id),
  };
}

/** Har o'quvchining eng so'nggi natijasi. */
function latestPerStudent(results: readonly PsychResult[]): PsychResult[] {
  const latest = new Map<string, PsychResult>();
  for (const r of results) {
    const prev = latest.get(r.studentId);
    if (!prev || Date.parse(r.takenAt) >= Date.parse(prev.takenAt)) latest.set(r.studentId, r);
  }
  return [...latest.values()].sort((a, b) => Date.parse(b.takenAt) - Date.parse(a.takenAt));
}

function distributionScale(test: PsychTest, wanted: string | undefined): string | null {
  const scored = test.scales.filter((s) => s.display !== 'RAW');
  return (scored.find((s) => s.key === wanted) ?? scored[0])?.key ?? null;
}

function buildDistribution(test: PsychTest, rows: readonly ResultRow[], scaleKey: string | null): BandBucket[] {
  if (test.kind === 'CAREER') {
    return CAREER_ORDER.map((code) => ({ band: code, count: rows.filter((r) => r.topCodes?.startsWith(code)).length }));
  }
  const scale = test.scales.find((s) => s.key === scaleKey);
  if (!scale) return [];
  const order = scale.polarity === 'HIGHER_CONCERN' ? CONCERN_BANDS : ABILITY_BANDS;
  const bands = rows.map((r) => r.scales.find((s) => s.key === scale.key)?.band ?? null);
  if (bands.every((b) => b === null)) return [];
  return order.map((band) => ({ band, count: bands.filter((b) => b === band).length }));
}

function toRow(t: Tables, r: PsychResult, bandsOnly: boolean, names: Map<string, string>, classNames: Map<string, string>): ResultRow | null {
  const scored = scoreStored(t, r);
  if (!scored) return null;
  const base: ResultRow = {
    id: r.id,
    studentId: r.studentId,
    studentName: names.get(r.studentId) ?? '—',
    classId: r.classId,
    className: classNames.get(r.classId) ?? r.classId,
    takenAt: r.takenAt,
    origin: r.origin,
    assignmentId: r.assignmentId,
    ageBand: r.ageBand,
    scales: bandsOnly ? scored.scales.map((s) => ({ key: s.key, band: s.band })) : scored.scales,
    topCodes: bandsOnly ? null : scored.topCodes,
  };
  if (bandsOnly) return base;
  return { ...base, ...(r.durationSec !== undefined ? { durationSec: r.durationSec } : {}), ...(r.answers ? { answers: r.answers } : {}) };
}

/** Psixolog — to'liq; sinf rahbari — `development.individual` + o'z sinfi, faqat darajalar. */
function resultsActor(classId: string | undefined): { actor: Actor; bandsOnly: boolean } {
  const actor = currentActor();
  const manage = roleHas(actor.role, 'assessments.manage');
  if (!manage) assertCan(actor, 'development.individual');
  if (classId) assertClassInScope(actor, classId);
  return { actor, bandsOnly: !manage };
}

function participation(t: Tables, actor: Actor, test: PsychTest, f: ResultsFilter, completed: number): { invited: number; completed: number } {
  const a = f.assignmentId ? t.psychAssignments.find((x) => x.id === f.assignmentId) : undefined;
  const classIds = new Set(
    t.classes.filter((c) => (a ? a.classIds.includes(c.id) : test.grades.includes(c.grade)) && (!f.classId || c.id === f.classId)).map((c) => c.id),
  );
  const invited = inScope(actor, t.students.filter((s) => !s.archived && classIds.has(s.classId))).length;
  return { invited, completed };
}

export const assessmentsResultsService = {
  async resultsByTest(testId: string, f: ResultsFilter = {}): Promise<ResultsByTest> {
    await latency(60, 160);
    const { actor, bandsOnly } = resultsActor(f.classId);
    const t = getTables();
    const test = findTest(t, testId);
    if (!test) throw new ServiceError('NOT_FOUND', testId);
    const filtered = allResults(t).filter(
      (r) => r.testId === testId && (!f.assignmentId || r.assignmentId === f.assignmentId) && (!f.classId || r.classId === f.classId),
    );
    const names = new Map(t.students.map((s) => [s.id, `${s.lastName} ${s.firstName}`]));
    const classNames = new Map(t.classes.map((c) => [c.id, c.name]));
    const rows = latestPerStudent(inScope(actor, filtered)).flatMap((r) => toRow(t, r, bandsOnly, names, classNames) ?? []);
    const scaleKey = distributionScale(test, f.scale);
    const needsNorms = scaleKey !== null && !(test.norms[scaleKey]?.length);
    return {
      rows,
      distribution: buildDistribution(test, rows, scaleKey),
      scaleKey,
      needsNorms,
      participation: participation(t, actor, test, f, rows.length),
      bandsOnly,
    };
  },

  /** Demo: faol tayinlashda qolgan o'quvchilarning `share` qismi testni "ilovada" yechadi. */
  async simulateCompletion(assignmentId: string, share = 0.8): Promise<{ created: number }> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'assessments.manage');
    if (!(share > 0 && share <= 1)) throw new ServiceError('VALIDATION', 'share');
    return transact((t) => {
      const a = t.psychAssignments.find((x) => x.id === assignmentId);
      if (!a) throw new ServiceError('NOT_FOUND', assignmentId);
      const now = clockNow();
      if (assignmentState(a, now.getTime()) !== 'ACTIVE') throw new ServiceError('CONFLICT', 'assignment not active');
      const test = findTest(t, a.testId);
      if (!test || test.items.length === 0) throw new ServiceError('CONFLICT', 'test has no items');
      const done = new Set(t.psychResults.map((r) => r.id));
      const remaining = targetStudents(t, a)
        .filter(({ student }) => !done.has(resultId(a.id, student.id)))
        .sort((x, y) => unitHash(a.id, x.student.id, 'sim') - unitHash(a.id, y.student.id, 'sim'));
      const picked = remaining.slice(0, Math.ceil(remaining.length * share));
      const opens = Date.parse(a.opensAt);
      const fresh = picked.map(({ student, cls }, i) => {
        const at = Math.max(opens, now.getTime() - Math.floor(unitHash(a.id, student.id, 'ago') * 40) * 60_000 - i * 1000);
        return buildAppResult(test, student, cls, a, toLocalIso(new Date(at)), `${a.id}:sim`);
      });
      if (fresh.length === 0) return { created: 0 };
      t.psychResults = [...t.psychResults, ...fresh];
      upsertTestCompleted(t, a, test, toIsoDate(now), toLocalIso(now));
      writeAudit(t, actor, 'ASSESSMENTS', 'assessments.simulate', `Demo: ${fresh.length} ta natija (${test.title.uz})`, a.id, null, null, { count: fresh.length, title: test.title.uz });
      return { created: fresh.length };
    });
  },
};

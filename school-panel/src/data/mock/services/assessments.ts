import type {
  AssignmentState,
  PsychAssignment,
  PsychNorms,
  PsychTest,
  PsychTestKind,
  PsychTestSource,
  PsychTestStatus,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  assignInputSchema,
  normsSchema,
  psychTestInputSchema,
  refineNorms,
  type AssignInput,
  type PsychNormsInput,
  type PsychTestInput,
} from '@/data/schemas/assessments';
import { parseOrThrow } from '@/data/schemas/validate';
import { normalizeSearch } from '@/lib/normalize-search';
import { clockNow } from '../clock';
import { assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { allTests, findTest, isTemplateId } from '../psych/catalog';
import { allResults } from '../psych/results';
import { PSYCH_TEMPLATES } from '../seed/psych-templates';
import type { Tables } from '../tables';
import { assessmentsImportService, portableTest } from './assessments-import';
import { type AssignmentRow, assessmentsResultsService, assignmentState, completedByAssignment, nowIso, toAssignmentRow } from './assessments-results';

/**
 * Psixologik testlar servisi — barcha amallar `assessments.manage` (faqat psixolog),
 * `resultsByTest` bundan mustasno (sinf rahbari — o'z sinfi, faqat darajalar).
 * Auditda o'quvchi ismi, ball yoki javoblar YO'Q — faqat amal, obyekt ID va sonlar.
 */
export type { AssignmentRow, BandBucket, ResultRow, ResultsByTest, ResultsFilter } from './assessments-results';
export type { CsvImportResult, CsvPreview, CsvPreviewRow, CsvReason, CsvRowStatus } from './assessments-import';

export type PsychTestRow = PsychTest & { itemCount: number; assignmentsActive: number; resultsCount: number };
export type PsychTestDetail = PsychTestRow & { readOnly: boolean; normsOverridden: boolean; defaultNorms: PsychNorms | null };
export type PsychTestFilter = { kind?: PsychTestKind; status?: PsychTestStatus; source?: PsychTestSource; search?: string };
export type AssignmentFilter = { testId?: string; state?: AssignmentState };
export type ClassOption = { id: string; name: string; grade: number; size: number };

const COPY_SUFFIX = { uz: ' (nusxa)', ru: ' (копия)' } as const;
const TITLE_MAX = 120;

function requireManage() {
  const actor = currentActor();
  assertCan(actor, 'assessments.manage');
  return actor;
}

function rowsContext(t: Tables) {
  const nowMs = clockNow().getTime();
  const active = new Map<string, number>();
  for (const a of t.psychAssignments) {
    if (assignmentState(a, nowMs) === 'ACTIVE') active.set(a.testId, (active.get(a.testId) ?? 0) + 1);
  }
  const results = new Map<string, number>();
  for (const r of allResults(t)) results.set(r.testId, (results.get(r.testId) ?? 0) + 1);
  return { active, results };
}

function toRow(test: PsychTest, ctx: ReturnType<typeof rowsContext>): PsychTestRow {
  return { ...test, itemCount: test.items.length, assignmentsActive: ctx.active.get(test.id) ?? 0, resultsCount: ctx.results.get(test.id) ?? 0 };
}

function matches(test: PsychTest, f: PsychTestFilter): boolean {
  if (f.kind && test.kind !== f.kind) return false;
  if (f.status && test.status !== f.status) return false;
  if (f.source && test.source !== f.source) return false;
  const q = f.search ? normalizeSearch(f.search) : '';
  return !q || normalizeSearch(`${test.title.uz} ${test.title.ru}`).includes(q);
}

/** Maktabning o'z testi (shablon emas). */
function ownTest(t: Tables, id: string): { index: number; test: PsychTest } {
  const index = t.psychTests.findIndex((x) => x.id === id);
  const test = t.psychTests[index];
  if (!test) throw new ServiceError(isTemplateId(id) ? 'CONFLICT' : 'NOT_FOUND', id);
  return { index, test };
}

function parseNorms(test: PsychTest, norms: PsychNormsInput): PsychNorms {
  const keys = new Set(test.scales.map((s) => s.key));
  return parseOrThrow(
    normsSchema.superRefine((v, ctx) => refineNorms(v, keys, ctx, [])),
    norms,
  );
}

const sameJson = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

const OPEN_ASSIGNMENTS = 'assessments.validation.openAssignments';
/** Muddat tugagach ham shuncha daqiqa "jonli": oxirgi daqiqada boshlagan bola testni tugatib yuborsin. */
const DEFAULT_GRACE_MIN = 30;
const MINUTE_MS = 60_000;

/** Kechikish oynasi (daqiqa): test vaqti, u bo'lmasa — 30. */
const graceMinOf = (test: Pick<PsychTest, 'timeLimitMin'>): number => test.timeLimitMin ?? DEFAULT_GRACE_MIN;

/**
 * Backend bilan bir xil (LOW 6): status OPEN va hozir ≤ closesAt + grace bo'lgan tayinlash — "jonli",
 * bola hali yechayotgan bo'lishi mumkin: savol / shkala o'zgarmaydi, test arxivlanmaydi (holati
 * ENDED ko'rinsa ham). Psixolog tayinlashni istalgan payt yopib (OPEN → CLOSED) qulfni ochadi.
 */
function hasLiveAssignments(t: Tables, testId: string, graceMin: number): boolean {
  const nowMs = clockNow().getTime();
  return t.psychAssignments.some((a) => a.testId === testId && a.status === 'OPEN' && nowMs <= Date.parse(a.closesAt) + graceMin * MINUTE_MS);
}

function setStatus(id: string, to: PsychTestStatus, from: readonly PsychTestStatus[], action: string): PsychTest {
  const actor = requireManage();
  return transact((t) => {
    const test = findTest(t, id);
    if (!test) throw new ServiceError('NOT_FOUND', id);
    if (!from.includes(test.status)) throw new ServiceError('CONFLICT', `status ${test.status}`);
    if (to === 'PUBLISHED' && test.source !== 'EXTERNAL' && test.items.length === 0) throw new ServiceError('VALIDATION', 'items: assessments.validation.noItems');
    if (to === 'ARCHIVED' && hasLiveAssignments(t, id, graceMinOf(test))) throw new ServiceError('CONFLICT', OPEN_ASSIGNMENTS);
    if (isTemplateId(id)) {
      t.psychTemplateState = { ...t.psychTemplateState, [id]: { ...t.psychTemplateState[id], status: to, norms: t.psychTemplateState[id]?.norms ?? null } };
    } else {
      const { index } = ownTest(t, id);
      t.psychTests[index] = { ...test, status: to, updatedAt: nowIso() };
    }
    writeAudit(t, actor, 'ASSESSMENTS', action, `Test holati: ${test.title.uz}`, id, { status: test.status }, { status: to }, { title: test.title.uz });
    return { ...test, status: to };
  });
}

/** Tayinlash maqsadi → sinflar (test parallellari bilan kesishma). */
function resolveClasses(t: Tables, input: AssignInput, test: PsychTest): string[] {
  const target = input.target;
  return t.classes
    .filter((c) => test.grades.includes(c.grade))
    .filter((c) => (target.kind === 'CLASSES' ? target.classIds.includes(c.id) : target.grades.includes(c.grade)))
    .map((c) => c.id);
}

function closeOrCancel(id: string, mode: 'unassign' | 'close'): PsychAssignment {
  const actor = requireManage();
  return transact((t) => {
    const index = t.psychAssignments.findIndex((a) => a.id === id);
    const a = t.psychAssignments[index];
    if (!a) throw new ServiceError('NOT_FOUND', id);
    if (a.status !== 'OPEN') throw new ServiceError('CONFLICT', `status ${a.status}`);
    const hasResults = t.psychResults.some((r) => r.assignmentId === id);
    const status = mode === 'close' || hasResults ? 'CLOSED' : 'CANCELLED';
    const next: PsychAssignment = { ...a, status };
    t.psychAssignments[index] = next;
    writeAudit(t, actor, 'ASSESSMENTS', mode === 'close' ? 'assessments.assignment.close' : 'assessments.unassign', `Tayinlash: ${status}`, id, { status: a.status }, { status });
    return next;
  });
}

export const assessmentsService = {
  async listTests(f: PsychTestFilter = {}): Promise<PsychTestRow[]> {
    await latency(60, 160);
    requireManage();
    const t = getTables();
    const ctx = rowsContext(t);
    return allTests(t)
      .filter((x) => matches(x, f))
      .map((x) => toRow(x, ctx));
  },

  async getTest(id: string): Promise<PsychTestDetail> {
    await latency(60, 140);
    requireManage();
    const t = getTables();
    const test = findTest(t, id);
    if (!test) throw new ServiceError('NOT_FOUND', id);
    const template = isTemplateId(id);
    return {
      ...toRow(test, rowsContext(t)),
      readOnly: template || test.source === 'EXTERNAL' || test.status === 'ARCHIVED',
      normsOverridden: template && Boolean(t.psychTemplateState[id]?.norms),
      defaultNorms: template ? PSYCH_TEMPLATES[id].norms : null,
    };
  },

  async createTest(input: PsychTestInput): Promise<PsychTest> {
    await latency();
    const actor = requireManage();
    const data = parseOrThrow(psychTestInputSchema, input);
    return transact((t) => {
      const test: PsychTest = { ...data, id: newId('pt'), source: 'CUSTOM', status: 'DRAFT', version: 1, createdBy: actor.staffId, updatedAt: nowIso(), basedOn: null };
      t.psychTests = [...t.psychTests, test];
      writeAudit(t, actor, 'ASSESSMENTS', 'assessments.test.create', `Test yaratildi: ${test.title.uz}`, test.id, null, null, { count: test.items.length, title: test.title.uz });
      return test;
    });
  },

  /** Nashr etilgan testda savol/shkala o'zgarsa — yangi versiya (eski natijalar o'z versiyasida). */
  async updateTest(id: string, input: PsychTestInput): Promise<PsychTest> {
    await latency();
    const actor = requireManage();
    if (isTemplateId(id)) throw new ServiceError('CONFLICT', 'templates are read-only');
    const data = parseOrThrow(psychTestInputSchema, input);
    return transact((t) => {
      const { index, test } = ownTest(t, id);
      if (test.status === 'ARCHIVED' || test.source === 'EXTERNAL') throw new ServiceError('CONFLICT', `${test.source}/${test.status}`);
      const changed = !sameJson(test.items, data.items) || !sameJson(test.scales, data.scales);
      // Backend bilan bir xil: faol tayinlashda savol / shkala (kechikish — eski va yangi oynaning
      // kattasi) va vaqt chegarasi o'zgarmaydi (qisqartirib keyingi tahrirda chetlab o'tilmasin).
      const limitChanged = (data.timeLimitMin ?? null) !== (test.timeLimitMin ?? null);
      const graceMin = changed ? Math.max(graceMinOf(test), graceMinOf(data)) : graceMinOf(test);
      if (test.status === 'PUBLISHED' && (changed || limitChanged) && hasLiveAssignments(t, id, graceMin)) {
        throw new ServiceError('CONFLICT', OPEN_ASSIGNMENTS);
      }
      const version = test.status === 'PUBLISHED' && changed ? test.version + 1 : test.version;
      const next: PsychTest = { ...test, ...data, version, updatedAt: nowIso() };
      t.psychTests[index] = next;
      writeAudit(t, actor, 'ASSESSMENTS', 'assessments.test.update', `Test tahrirlandi: ${next.title.uz}`, id, { version: test.version }, { version }, { version, title: next.title.uz });
      return next;
    });
  },

  /** Shablon: maktab me'yori (`null` — standart demo me'yorlar tiklanadi). */
  async updateNorms(id: string, norms: PsychNormsInput | null): Promise<void> {
    await latency();
    const actor = requireManage();
    transact((t) => {
      const test = findTest(t, id);
      if (!test) throw new ServiceError('NOT_FOUND', id);
      const parsed = norms === null ? null : parseNorms(test, norms);
      if (isTemplateId(id)) {
        const state = t.psychTemplateState[id] ?? { status: 'PUBLISHED', norms: null };
        t.psychTemplateState = { ...t.psychTemplateState, [id]: { ...state, norms: parsed } };
      } else {
        const { index } = ownTest(t, id);
        t.psychTests[index] = { ...test, norms: parsed ?? {}, updatedAt: nowIso() };
      }
      writeAudit(t, actor, 'ASSESSMENTS', parsed ? 'assessments.norms.update' : 'assessments.norms.restore', `Me'yorlar: ${test.title.uz}`, id, null, null, { title: test.title.uz });
    });
  },

  async publishTest(id: string): Promise<PsychTest> {
    await latency();
    return setStatus(id, 'PUBLISHED', ['DRAFT', 'ARCHIVED'], 'assessments.test.publish');
  },

  async archiveTest(id: string): Promise<PsychTest> {
    await latency();
    return setStatus(id, 'ARCHIVED', ['DRAFT', 'PUBLISHED'], 'assessments.test.archive');
  },

  async duplicateTest(id: string): Promise<PsychTest> {
    await latency();
    const actor = requireManage();
    return transact((t) => {
      const source = findTest(t, id);
      if (!source) throw new ServiceError('NOT_FOUND', id);
      const title = { uz: `${source.title.uz}${COPY_SUFFIX.uz}`.slice(0, TITLE_MAX), ru: `${source.title.ru}${COPY_SUFFIX.ru}`.slice(0, TITLE_MAX) };
      const copy: PsychTest = {
        ...portableTest(source),
        title,
        id: newId('pt'),
        source: 'CUSTOM',
        status: 'DRAFT',
        version: 1,
        createdBy: actor.staffId,
        updatedAt: nowIso(),
        basedOn: source.id,
      };
      t.psychTests = [...t.psychTests, copy];
      writeAudit(t, actor, 'ASSESSMENTS', 'assessments.test.duplicate', `Test nusxalandi: ${source.title.uz}`, copy.id, null, null, { title: source.title.uz });
      return copy;
    });
  },

  /** Tayinlash va filtrlar uchun sinflar (psixologda `classes.view` yo'q). */
  async classOptions(): Promise<ClassOption[]> {
    await latency(40, 100);
    requireManage();
    const t = getTables();
    const sizes = new Map<string, number>();
    for (const s of t.students) if (!s.archived) sizes.set(s.classId, (sizes.get(s.classId) ?? 0) + 1);
    return [...t.classes]
      .sort((a, b) => a.grade - b.grade || a.letter.localeCompare(b.letter))
      .map((c) => ({ id: c.id, name: c.name, grade: c.grade, size: sizes.get(c.id) ?? 0 }));
  },

  async listAssignments(f: AssignmentFilter = {}): Promise<AssignmentRow[]> {
    await latency(60, 160);
    requireManage();
    const t = getTables();
    const nowMs = clockNow().getTime();
    const completed = completedByAssignment(t);
    return t.psychAssignments
      .filter((a) => !f.testId || a.testId === f.testId)
      .map((a) => toAssignmentRow(t, a, nowMs, completed))
      .filter((a) => !f.state || a.state === f.state)
      .sort((a, b) => Date.parse(b.opensAt) - Date.parse(a.opensAt));
  },

  async assign(input: AssignInput): Promise<PsychAssignment> {
    await latency();
    const actor = requireManage();
    const data = parseOrThrow(assignInputSchema, input);
    return transact((t) => {
      const test = findTest(t, data.testId);
      if (!test) throw new ServiceError('NOT_FOUND', data.testId);
      if (test.status !== 'PUBLISHED' || test.items.length === 0) throw new ServiceError('CONFLICT', 'test not assignable');
      const classIds = resolveClasses(t, data, test);
      if (classIds.length === 0) throw new ServiceError('VALIDATION', 'target: assessments.validation.noClasses');
      const invited = t.students.filter((s) => !s.archived && classIds.includes(s.classId)).length;
      const a: PsychAssignment = {
        id: newId('pa'),
        testId: test.id,
        testVersion: test.version,
        target: data.target,
        classIds,
        opensAt: data.opensAt,
        closesAt: data.closesAt,
        status: 'OPEN',
        invited,
        consent: 'PARENTS_INFORMED',
        createdBy: actor.staffId,
        createdAt: nowIso(),
      };
      t.psychAssignments = [...t.psychAssignments, a];
      writeAudit(t, actor, 'ASSESSMENTS', 'assessments.assign', `Test tayinlandi: ${test.title.uz}`, a.id, null, null, { classes: classIds.length, count: invited, title: test.title.uz });
      return a;
    });
  },

  /** Natija yo'q — bekor qilinadi; natija bor — yopiladi (natijalar saqlanadi). */
  async unassign(id: string): Promise<PsychAssignment> {
    await latency();
    return closeOrCancel(id, 'unassign');
  },

  async closeAssignment(id: string): Promise<PsychAssignment> {
    await latency();
    return closeOrCancel(id, 'close');
  },

  ...assessmentsImportService,
  ...assessmentsResultsService,
};

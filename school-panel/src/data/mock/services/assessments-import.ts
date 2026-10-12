import type { IsoDate, PsychResult, PsychTest, Student } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { PSYCH_EXPORT_FORMAT, PSYCH_EXPORT_VERSION, PSYCH_LIMITS, psychTestFileSchema, type PsychTestInput } from '@/data/schemas/assessments';
import { parseOrThrow } from '@/data/schemas/validate';
import { parseCsv } from '@/lib/csv';
import { ageBandOf, ageOn, maxRaw, minRaw } from '@/lib/psych/scoring';
import { addDays } from '../calendar';
import { clockToday } from '../clock';
import { assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { allTests, findTest } from '../psych/catalog';
import { allResults } from '../psych/results';
import type { Tables } from '../tables';
import { nowIso } from './assessments-results';

/**
 * JSON test eksport/import va natijalarni CSV'dan import qilish.
 * CSV: `studentCode;test;date;raw[;scale:<key>...]`. Noma'lum test nomi — tashqi (EXTERNAL) test.
 */
export type CsvRowStatus = 'OK' | 'ERROR' | 'DUPLICATE';
export type CsvReason =
  | 'STUDENT_NOT_FOUND'
  | 'TEST_EMPTY'
  | 'TEST_NAME'
  | 'TEST_NO_RESULTS'
  | 'BAD_DATE'
  | 'DATE_RANGE'
  | 'BAD_RAW'
  | 'RAW_RANGE'
  | 'UNKNOWN_SCALE'
  | 'MISSING_SCALE'
  | 'DUPLICATE_FILE'
  | 'DUPLICATE_EXISTING';
export type CsvPreviewRow = {
  line: number;
  studentCode: string;
  studentName: string | null;
  className: string | null;
  test: string;
  testTitle: string | null;
  newExternal: boolean;
  date: IsoDate | null;
  raw: Record<string, number>;
  status: CsvRowStatus;
  reason: CsvReason | null;
};
export type CsvPreview = { rows: CsvPreviewRow[]; counts: Record<CsvRowStatus, number>; newTests: string[] };
export type CsvImportResult = { created: number; skipped: Array<{ line: number; reason: CsvReason }> };

const BASE_HEADERS = ['studentcode', 'test', 'date', 'raw'];
const SCALE_HEADER = /^scale:([A-Za-z][A-Za-z0-9_]{0,23})$/;
const HISTORY_DAYS = 730;
const IMPORT_TIME = 'T09:00:00';

function requireManage() {
  const actor = currentActor();
  assertCan(actor, 'assessments.manage');
  return actor;
}

const byteLength = (text: string) => new TextEncoder().encode(text).length;

/** Testning ko'chma qismi (eksport/import, nusxa). */
export function portableTest(test: PsychTest): PsychTestInput {
  return {
    title: test.title,
    description: test.description,
    instructions: test.instructions,
    kind: test.kind,
    grades: test.grades,
    timeLimitMin: test.timeLimitMin,
    scales: test.scales,
    items: test.items,
    scoring: test.scoring,
    norms: test.norms,
  };
}

function parseJson(json: string): unknown {
  if (typeof json !== 'string' || byteLength(json) > PSYCH_LIMITS.jsonBytes) throw new ServiceError('VALIDATION', 'file: assessments.validation.jsonTooLarge');
  try {
    return JSON.parse(json) as unknown;
  } catch {
    throw new ServiceError('VALIDATION', 'file: assessments.validation.jsonParse');
  }
}

/** "2026-10-12" yoki "12.10.2026" → ISO (haqiqiy sana bo'lsa). */
export function parseCsvDate(value: string): IsoDate | null {
  const v = value.trim();
  const dotted = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(v);
  const iso = dotted ? `${dotted[3]}-${dotted[2]}-${dotted[1]}` : v;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(iso)) return null;
  const [y, m, d] = iso.split('-').map(Number) as [number, number, number];
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d ? iso : null;
}

function parseNumber(cell: string, integer: boolean): number | null {
  const v = cell.trim().replace(',', '.');
  if (!/^-?\d+(\.\d+)?$/.test(v)) return null;
  const n = Number(v);
  return Number.isFinite(n) && (!integer || Number.isInteger(n)) ? n : null;
}

type Header = { scaleColumns: Array<{ index: number; key: string }> };

function readHeader(row: readonly string[] | undefined): Header {
  const cells = (row ?? []).map((c) => c.trim());
  const ok = BASE_HEADERS.every((h, i) => cells[i]?.toLowerCase() === h);
  if (!ok) throw new ServiceError('VALIDATION', 'header: assessments.validation.csvHeader');
  const scaleColumns = cells.slice(BASE_HEADERS.length).map((cell, i) => {
    const m = SCALE_HEADER.exec(cell);
    if (!m?.[1]) throw new ServiceError('VALIDATION', 'header: assessments.validation.csvHeader');
    return { index: BASE_HEADERS.length + i, key: m[1] };
  });
  return { scaleColumns };
}

type Resolved = { test: PsychTest | null; key: string; title: string; newName: string | null };

/** Test ID → mavjud test; aks holda nomi bo'yicha tashqi test (bor bo'lsa — qayta ishlatiladi). */
function resolveTest(t: Tables, cell: string): Resolved | CsvReason {
  const name = cell.trim();
  if (!name) return 'TEST_EMPTY';
  const known = findTest(t, name);
  if (known) return { test: known, key: known.id, title: known.title.uz, newName: null };
  const lower = name.toLowerCase();
  const external = allTests(t).find((x) => x.source === 'EXTERNAL' && (x.title.uz.toLowerCase() === lower || x.title.ru.toLowerCase() === lower));
  if (external) return { test: external, key: external.id, title: external.title.uz, newName: null };
  if (name.length > PSYCH_LIMITS.title) return 'TEST_NAME';
  return { test: null, key: `new:${lower}`, title: name, newName: name };
}

function scaleRange(test: PsychTest | null, key: string): { min: number; max: number; integer: boolean } {
  if (!test || test.items.length === 0) return { min: 0, max: PSYCH_LIMITS.externalRawMax, integer: false };
  return { min: minRaw(test, key), max: maxRaw(test, key), integer: true };
}

function readRaw(cells: readonly string[], header: Header, resolved: Resolved): Record<string, number> | CsvReason {
  const scaleKeys = resolved.test ? resolved.test.scales.map((s) => s.key) : ['total'];
  const values: Array<[string, string]> = [[scaleKeys[0] ?? 'total', cells[3] ?? '']];
  for (const col of header.scaleColumns) {
    const cell = (cells[col.index] ?? '').trim();
    if (!cell) continue;
    if (!scaleKeys.includes(col.key)) return 'UNKNOWN_SCALE';
    values.push([col.key, cell]);
  }
  const raw: Record<string, number> = {};
  for (const [key, cell] of values) {
    const range = scaleRange(resolved.test, key);
    const n = parseNumber(cell, range.integer);
    if (n === null) return 'BAD_RAW';
    if (n < range.min || n > range.max) return 'RAW_RANGE';
    raw[key] = n;
  }
  return scaleKeys.every((k) => k in raw) ? raw : 'MISSING_SCALE';
}

type Context = { t: Tables; header: Header; today: IsoDate; existing: Set<string>; seen: Set<string>; students: Map<string, Student> };

function previewRow(ctx: Context, cells: readonly string[], line: number): CsvPreviewRow {
  const code = (cells[0] ?? '').trim();
  const student = ctx.students.get(code.toUpperCase()) ?? null;
  const cls = student ? ctx.t.classes.find((c) => c.id === student.classId) : undefined;
  const row: CsvPreviewRow = {
    line,
    studentCode: code,
    studentName: student ? `${student.lastName} ${student.firstName}` : null,
    className: cls?.name ?? null,
    test: (cells[1] ?? '').trim(),
    testTitle: null,
    newExternal: false,
    date: null,
    raw: {},
    status: 'ERROR',
    reason: null,
  };
  if (!student) return { ...row, reason: 'STUDENT_NOT_FOUND' };
  const resolved = resolveTest(ctx.t, cells[1] ?? '');
  if (typeof resolved === 'string') return { ...row, reason: resolved };
  if (resolved.test && resolved.test.source !== 'EXTERNAL' && resolved.test.items.length === 0) return { ...row, reason: 'TEST_NO_RESULTS' };
  const withTest = { ...row, testTitle: resolved.title, newExternal: resolved.newName !== null };
  const date = parseCsvDate(cells[2] ?? '');
  if (!date) return { ...withTest, reason: 'BAD_DATE' };
  if (date > ctx.today || date < addDays(ctx.today, -HISTORY_DAYS)) return { ...withTest, date, reason: 'DATE_RANGE' };
  const raw = readRaw(cells, ctx.header, resolved);
  if (typeof raw === 'string') return { ...withTest, date, reason: raw };
  const dupKey = `${student.id}|${resolved.key}|${date}`;
  const ready = { ...withTest, date, raw };
  if (ctx.existing.has(dupKey)) return { ...ready, status: 'DUPLICATE', reason: 'DUPLICATE_EXISTING' };
  if (ctx.seen.has(dupKey)) return { ...ready, status: 'DUPLICATE', reason: 'DUPLICATE_FILE' };
  ctx.seen.add(dupKey);
  return { ...ready, status: 'OK' };
}

/** Faylni tahlil qilish (jadvallarni o'zgartirmaydi). */
export function buildPreview(t: Tables, text: string): CsvPreview {
  if (typeof text !== 'string' || byteLength(text) > PSYCH_LIMITS.csvBytes) throw new ServiceError('VALIDATION', 'file: assessments.validation.csvTooLarge');
  const [headerRow, ...data] = parseCsv(text);
  const header = readHeader(headerRow);
  if (data.length === 0) throw new ServiceError('VALIDATION', 'file: assessments.validation.csvEmpty');
  if (data.length > PSYCH_LIMITS.csvRows) throw new ServiceError('VALIDATION', 'file: assessments.validation.csvTooManyRows');
  const existing = new Set(allResults(t).map((r) => `${r.studentId}|${r.testId}|${r.takenAt.slice(0, 10)}`));
  const students = new Map(t.students.filter((s) => !s.archived).map((s) => [s.studentCode.toUpperCase(), s]));
  const ctx: Context = { t, header, today: clockToday(), existing, seen: new Set(), students };
  const rows = data.map((cells, i) => previewRow(ctx, cells, i + 2));
  const counts = { OK: 0, ERROR: 0, DUPLICATE: 0 } satisfies Record<CsvRowStatus, number>;
  for (const r of rows) counts[r.status] += 1;
  const newTests = [...new Set(rows.filter((r) => r.status === 'OK' && r.newExternal).map((r) => r.test))];
  return { rows, counts, newTests };
}

/** Tashqi test: bitta `total` shkala, me'yorlarsiz (UI me'yor kiritishni taklif qiladi). */
function externalTest(name: string, createdBy: string): PsychTest {
  return {
    id: newId('pt'),
    title: { uz: name, ru: name },
    description: { uz: '', ru: '' },
    instructions: { uz: '', ru: '' },
    kind: 'CUSTOM',
    source: 'EXTERNAL',
    grades: Array.from({ length: 11 }, (_, i) => i + 1),
    timeLimitMin: null,
    scales: [{ key: 'total', label: { uz: 'Umumiy ball', ru: 'Общий балл' }, domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' }],
    items: [],
    scoring: { method: 'SUM' },
    norms: {},
    version: 1,
    status: 'PUBLISHED',
    createdBy,
    updatedAt: nowIso(),
    basedOn: null,
  };
}

function importedResult(t: Tables, row: CsvPreviewRow, test: PsychTest, student: Student): PsychResult {
  const cls = t.classes.find((c) => c.id === student.classId);
  const date = row.date ?? clockToday();
  return {
    id: newId('pr'),
    studentId: student.id,
    classId: student.classId,
    grade: cls?.grade ?? 0,
    ageBand: ageBandOf(ageOn(student.birthDate, date)),
    testId: test.id,
    version: test.version,
    assignmentId: null,
    takenAt: `${date}${IMPORT_TIME}`,
    origin: 'IMPORT',
    raw: row.raw,
  };
}

export const assessmentsImportService = {
  async exportTest(id: string): Promise<string> {
    await latency(40, 100);
    requireManage();
    const test = findTest(getTables(), id);
    if (!test) throw new ServiceError('NOT_FOUND', id);
    return JSON.stringify({ format: PSYCH_EXPORT_FORMAT, formatVersion: PSYCH_EXPORT_VERSION, exportedAt: nowIso(), test: portableTest(test) }, null, 2);
  },

  async importTest(json: string): Promise<PsychTest> {
    await latency();
    const actor = requireManage();
    const file = parseOrThrow(psychTestFileSchema, parseJson(json));
    return transact((t) => {
      const test: PsychTest = {
        ...file.test,
        id: newId('pt'),
        source: 'IMPORTED',
        status: 'DRAFT',
        version: 1,
        createdBy: actor.staffId,
        updatedAt: nowIso(),
        basedOn: null,
      };
      t.psychTests = [...t.psychTests, test];
      writeAudit(t, actor, 'ASSESSMENTS', 'assessments.test.import', `Test import qilindi: ${test.title.uz}`, test.id, null, null, { count: test.items.length, title: test.title.uz });
      return test;
    });
  },

  async previewResultsCsv(text: string): Promise<CsvPreview> {
    await latency(80, 200);
    requireManage();
    return buildPreview(getTables(), text);
  },

  async importResultsCsv(text: string): Promise<CsvImportResult> {
    await latency();
    const actor = requireManage();
    return transact((t) => {
      const preview = buildPreview(t, text);
      const created = new Map<string, PsychTest>();
      const students = new Map(t.students.map((s) => [s.studentCode.toUpperCase(), s]));
      const fresh: PsychResult[] = [];
      for (const row of preview.rows) {
        const student = students.get(row.studentCode.toUpperCase());
        if (row.status !== 'OK' || !student) continue;
        const resolved = resolveTest(t, row.test);
        if (typeof resolved === 'string') continue;
        const lower = row.test.toLowerCase();
        const test = resolved.test ?? created.get(lower) ?? externalTest(row.test, actor.staffId);
        if (!resolved.test) created.set(lower, test);
        fresh.push(importedResult(t, row, test, student));
      }
      t.psychTests = [...t.psychTests, ...created.values()];
      t.psychResults = [...t.psychResults, ...fresh];
      if (created.size) writeAudit(t, actor, 'ASSESSMENTS', 'assessments.test.external', `Tashqi testlar qo'shildi: ${created.size}`, null, null, null, { count: created.size });
      writeAudit(t, actor, 'ASSESSMENTS', 'assessments.results.import', `Natijalar CSV'dan import qilindi: ${fresh.length}`, null, null, null, { count: fresh.length });
      const skipped = preview.rows.filter((r) => r.status !== 'OK').map((r) => ({ line: r.line, reason: r.reason ?? 'BAD_RAW' }));
      return { created: fresh.length, skipped };
    });
  },
};

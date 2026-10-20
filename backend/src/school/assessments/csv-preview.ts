// Natijalarni CSV'dan import qilish — tahlil (sof funksiyalar; panel
// `assessments-import.ts` `buildPreview` bilan bir xil qoidalar).
// CSV: `studentCode;test;date;raw[;scale:<key>...]`. Noma'lum test nomi — tashqi (EXTERNAL) test.

import { addDays } from '../../common/time/tashkent';
import { invalid } from '../common/school-errors';
import { PSYCH_LIMITS } from './assessments.schemas';
import { parseCsv } from './psych/csv';
import { maxRaw, minRaw } from './psych/scoring';
import type { IsoDate, PsychTest } from './psych/types';

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

export type CsvStudent = { id: string; studentCode: string; lastName: string; firstName: string; classId: string | null; birthDate: string };
export type CsvHeader = { scaleColumns: Array<{ index: number; key: string }> };
export type CsvFile = { header: CsvHeader; data: string[][] };
/** Tahlil natijasi + import uchun aniqlangan o'quvchi va test. */
export type PlannedRow = { row: CsvPreviewRow; student: CsvStudent | null; test: PsychTest | null };
export type CsvContext = {
  today: IsoDate;
  /** `${studentId}|${testId}|${Toshkent kuni}` — bazadagi natijalar. */
  existing: ReadonlySet<string>;
  /** Kod (katta harf) → faol o'quvchi. */
  students: ReadonlyMap<string, CsvStudent>;
  classNames: ReadonlyMap<string, string>;
  tests: readonly PsychTest[];
};

const BASE_HEADERS = ['studentcode', 'test', 'date', 'raw'];
const SCALE_HEADER = /^scale:([A-Za-z][A-Za-z0-9_]{0,23})$/;
export const HISTORY_DAYS = 730;
const HEADER_ERROR = 'header: assessments.validation.csvHeader';

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

function readHeader(row: readonly string[] | undefined): CsvHeader {
  const cells = (row ?? []).map((c) => c.trim());
  if (!BASE_HEADERS.every((h, i) => cells[i]?.toLowerCase() === h)) throw invalid(HEADER_ERROR);
  const scaleColumns = cells.slice(BASE_HEADERS.length).map((cell, i) => {
    const m = SCALE_HEADER.exec(cell);
    if (!m?.[1]) throw invalid(HEADER_ERROR);
    return { index: BASE_HEADERS.length + i, key: m[1] };
  });
  return { scaleColumns };
}

/** Fayl matni: hajm (512 KB) → sarlavha → qatorlar soni (1..2000). Bazaga murojaatsiz. */
export function readCsvFile(text: unknown): CsvFile {
  if (typeof text !== 'string' || Buffer.byteLength(text, 'utf8') > PSYCH_LIMITS.csvBytes) {
    throw invalid('file: assessments.validation.csvTooLarge');
  }
  const [headerRow, ...data] = parseCsv(text);
  const header = readHeader(headerRow);
  if (data.length === 0) throw invalid('file: assessments.validation.csvEmpty');
  if (data.length > PSYCH_LIMITS.csvRows) throw invalid('file: assessments.validation.csvTooManyRows');
  return { header, data };
}

type Resolved = { test: PsychTest | null; key: string; title: string; newName: string | null };

/** Test ID → mavjud test; aks holda nomi bo'yicha tashqi test (bor bo'lsa — qayta ishlatiladi). */
function resolveTest(tests: readonly PsychTest[], cell: string): Resolved | CsvReason {
  const name = cell.trim();
  if (!name) return 'TEST_EMPTY';
  const known = tests.find((x) => x.id === name);
  if (known) return { test: known, key: known.id, title: known.title.uz, newName: null };
  const lower = name.toLowerCase();
  const external = tests.find((x) => x.source === 'EXTERNAL' && (x.title.uz.toLowerCase() === lower || x.title.ru.toLowerCase() === lower));
  if (external) return { test: external, key: external.id, title: external.title.uz, newName: null };
  if (name.length > PSYCH_LIMITS.title) return 'TEST_NAME';
  return { test: null, key: `new:${lower}`, title: name, newName: name };
}

function scaleRange(test: PsychTest | null, key: string): { min: number; max: number; integer: boolean } {
  if (!test || test.items.length === 0) return { min: 0, max: PSYCH_LIMITS.externalRawMax, integer: false };
  return { min: minRaw(test, key), max: maxRaw(test, key), integer: true };
}

function readRaw(cells: readonly string[], header: CsvHeader, resolved: Resolved): Record<string, number> | CsvReason {
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

function planRow(ctx: CsvContext, header: CsvHeader, seen: Set<string>, cells: readonly string[], line: number): PlannedRow {
  const code = (cells[0] ?? '').trim();
  const student = ctx.students.get(code.toUpperCase()) ?? null;
  const row: CsvPreviewRow = {
    line,
    studentCode: code,
    studentName: student ? `${student.lastName} ${student.firstName}` : null,
    className: student?.classId ? (ctx.classNames.get(student.classId) ?? null) : null,
    test: (cells[1] ?? '').trim(),
    testTitle: null,
    newExternal: false,
    date: null,
    raw: {},
    status: 'ERROR',
    reason: null,
  };
  const fail = (r: CsvPreviewRow): PlannedRow => ({ row: r, student, test: null });
  if (!student) return fail({ ...row, reason: 'STUDENT_NOT_FOUND' });
  const resolved = resolveTest(ctx.tests, cells[1] ?? '');
  if (typeof resolved === 'string') return fail({ ...row, reason: resolved });
  if (resolved.test && resolved.test.source !== 'EXTERNAL' && resolved.test.items.length === 0) return fail({ ...row, reason: 'TEST_NO_RESULTS' });
  const withTest = { ...row, testTitle: resolved.title, newExternal: resolved.newName !== null };
  const date = parseCsvDate(cells[2] ?? '');
  if (!date) return fail({ ...withTest, reason: 'BAD_DATE' });
  if (date > ctx.today || date < addDays(ctx.today, -HISTORY_DAYS)) return fail({ ...withTest, date, reason: 'DATE_RANGE' });
  const raw = readRaw(cells, header, resolved);
  if (typeof raw === 'string') return fail({ ...withTest, date, reason: raw });
  const dupKey = `${student.id}|${resolved.key}|${date}`;
  const ready = { ...withTest, date, raw };
  if (ctx.existing.has(dupKey)) return fail({ ...ready, status: 'DUPLICATE', reason: 'DUPLICATE_EXISTING' });
  if (seen.has(dupKey)) return fail({ ...ready, status: 'DUPLICATE', reason: 'DUPLICATE_FILE' });
  seen.add(dupKey);
  return { row: { ...ready, status: 'OK' }, student, test: resolved.test };
}

/** Har qator tahlili (bazani o'zgartirmaydi). */
export function planRows(ctx: CsvContext, file: CsvFile): PlannedRow[] {
  const seen = new Set<string>();
  return file.data.map((cells, i) => planRow(ctx, file.header, seen, cells, i + 2));
}

export function toPreview(planned: readonly PlannedRow[]): CsvPreview {
  const rows = planned.map((p) => p.row);
  const counts: Record<CsvRowStatus, number> = { OK: 0, ERROR: 0, DUPLICATE: 0 };
  for (const r of rows) counts[r.status] += 1;
  const newTests = [...new Set(rows.filter((r) => r.status === 'OK' && r.newExternal).map((r) => r.test))];
  return { rows, counts, newTests };
}

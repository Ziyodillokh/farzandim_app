import type { BellPeriod, TimetableLesson, TimetableWeekday } from '@/data/contracts';
import {
  TIMETABLE_ROOM_MAX,
  TIMETABLE_SUBJECT_KEYS,
  TIMETABLE_SUBJECT_MAX,
  TIMETABLE_TEACHER_MAX,
  TIMETABLE_WEEKDAYS,
  type TimetableSubjectKey,
} from '@/data/schemas/timetable';

/**
 * Dars jadvali «to'r» modeli: API ro'yxati (`lessons[]`) ↔ katakchalar xaritasi.
 * Hammasi sof funksiyalar va o'zgarmas (immutable) — UI holati va testlar uchun qulay.
 */

/** Bitta katakcha: fan (kalit yoki erkin matn), xona, o'qituvchi (tahrir uchun hammasi satr). */
export type CellValue = { subject: string; room: string; teacherName: string };

/** Faqat TO'LDIRILGAN kataklar saqlanadi: kalit — `"kun:davr"`. */
export type Grid = Readonly<Record<string, CellValue>>;

export const WEEKDAYS: readonly TimetableWeekday[] = TIMETABLE_WEEKDAYS;
export const EMPTY_CELL: CellValue = { subject: '', room: '', teacherName: '' };

export function cellKey(weekday: number, periodNo: number): string {
  return `${weekday}:${periodNo}`;
}

export function isWeekday(value: number): value is TimetableWeekday {
  return Number.isInteger(value) && value >= 1 && value <= WEEKDAYS.length;
}

/** Smenaning DARS davrlari (tanaffuslarsiz), raqam bo'yicha tartiblangan, takrorsiz. */
export function lessonPeriods(periods: readonly BellPeriod[]): BellPeriod[] {
  const byNo = new Map<number, BellPeriod>();
  for (const p of periods) if (p.kind === 'LESSON' && !byNo.has(p.no)) byNo.set(p.no, p);
  return [...byNo.values()].sort((a, b) => a.no - b.no);
}

function normalize(value: Partial<CellValue>): CellValue {
  return { subject: (value.subject ?? '').trim(), room: (value.room ?? '').trim(), teacherName: (value.teacherName ?? '').trim() };
}

export function isCellEmpty(value: CellValue | undefined): boolean {
  return !value || (!value.subject.trim() && !value.room.trim() && !value.teacherName.trim());
}

/** API darslari → to'r. Noto'g'ri kun e'tiborsiz; bir katakka ikki dars kelsa — oxirgisi. */
export function toGrid(lessons: readonly TimetableLesson[]): Grid {
  const grid: Record<string, CellValue> = {};
  for (const lesson of lessons) {
    if (!isWeekday(lesson.weekday)) continue;
    const value = normalize({ subject: lesson.subject, room: lesson.room ?? '', teacherName: lesson.teacherName ?? '' });
    if (!isCellEmpty(value)) grid[cellKey(lesson.weekday, lesson.periodNo)] = value;
  }
  return grid;
}

/**
 * To'r → API darslari (kun, davr bo'yicha tartiblangan). Faqat smenaning DARS davrlariga tegishli,
 * fani bor kataklar; bo'sh xona/o'qituvchi umuman yuborilmaydi.
 */
export function toLessons(grid: Grid, periods: readonly BellPeriod[]): TimetableLesson[] {
  const lessons: TimetableLesson[] = [];
  for (const weekday of WEEKDAYS) {
    for (const period of lessonPeriods(periods)) {
      const cell = grid[cellKey(weekday, period.no)];
      if (!cell || !cell.subject.trim()) continue;
      const { subject, room, teacherName } = normalize(cell);
      lessons.push({ weekday, periodNo: period.no, subject, ...(room && { room }), ...(teacherName && { teacherName }) });
    }
  }
  return lessons;
}

/** Smena davrlariga to'g'ri kelmaydigan (ko'rsatib bo'lmaydigan) darslar — saqlashda tushib qoladi. */
export function orphanLessons(lessons: readonly TimetableLesson[], periods: readonly BellPeriod[]): TimetableLesson[] {
  const known = new Set(lessonPeriods(periods).map((p) => p.no));
  return lessons.filter((l) => !isWeekday(l.weekday) || !known.has(l.periodNo));
}

/** Bitta katakni qo'yish/olib tashlash (bo'sh qiymat = olib tashlash). */
export function setCell(grid: Grid, weekday: number, periodNo: number, value: CellValue | null): Grid {
  const key = cellKey(weekday, periodNo);
  const rest = Object.fromEntries(Object.entries(grid).filter(([k]) => k !== key));
  if (!value) return rest;
  const next = normalize(value);
  return isCellEmpty(next) ? rest : { ...rest, [key]: next };
}

export function clearDay(grid: Grid, weekday: number): Grid {
  return Object.fromEntries(Object.entries(grid).filter(([key]) => !key.startsWith(`${weekday}:`)));
}

/**
 * Kunni nusxalash: `targets` kunlari butunlay `from` kuni bilan almashadi
 * (manba kunda bo'sh bo'lgan davrlar maqsad kunda ham bo'shaydi). Faqat `periodNos` davrlari ko'riladi.
 */
export function copyDay(grid: Grid, from: number, targets: readonly number[], periodNos: readonly number[]): Grid {
  const next: Record<string, CellValue> = { ...grid };
  for (const target of targets) {
    if (target === from) continue;
    for (const no of periodNos) {
      const source = grid[cellKey(from, no)];
      if (source) next[cellKey(target, no)] = { ...source };
      else delete next[cellKey(target, no)];
    }
  }
  return next;
}

/** Nusxalash natijasida o'zgaradigan (ustiga yoziladigan) to'ldirilgan kataklar soni. */
export function overwriteCount(grid: Grid, from: number, targets: readonly number[], periodNos: readonly number[]): number {
  let count = 0;
  for (const target of targets) {
    if (target === from) continue;
    for (const no of periodNos) {
      const existing = grid[cellKey(target, no)];
      if (existing && !sameCell(existing, grid[cellKey(from, no)])) count += 1;
    }
  }
  return count;
}

export function filledCount(grid: Grid): number {
  return Object.values(grid).filter((c) => !isCellEmpty(c)).length;
}

function sameCell(a: CellValue | undefined, b: CellValue | undefined): boolean {
  if (!a || !b) return !a && !b;
  return a.subject === b.subject && a.room === b.room && a.teacherName === b.teacherName;
}

export function gridsEqual(a: Grid, b: Grid): boolean {
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const key of keys) if (!sameCell(a[key], b[key])) return false;
  return true;
}

/* ── Klaviatura bilan yurish ────────────────────────────────────────────── */

export type Direction = 'up' | 'down' | 'left' | 'right';

/**
 * Strelka tugmasi bilan qo'shni katak kaliti (to'rning chetida to'xtaydi — aylanmaydi).
 * Ustunlar — hafta kunlari, qatorlar — `periodNos` tartibida.
 */
export function neighborCell(key: string, direction: Direction, periodNos: readonly number[]): string | null {
  const [weekday, periodNo] = key.split(':').map(Number);
  if (weekday === undefined || periodNo === undefined) return null;
  const row = periodNos.indexOf(periodNo);
  if (row < 0 || !isWeekday(weekday)) return null;
  const nextDay = direction === 'left' ? weekday - 1 : direction === 'right' ? weekday + 1 : weekday;
  const nextRow = direction === 'up' ? row - 1 : direction === 'down' ? row + 1 : row;
  const nextNo = periodNos[nextRow];
  if (nextNo === undefined || !isWeekday(nextDay)) return null;
  return cellKey(nextDay, nextNo);
}

/* ── Fan tanlovi ────────────────────────────────────────────────────────── */

export function isKnownSubject(subject: string): subject is TimetableSubjectKey {
  return (TIMETABLE_SUBJECT_KEYS as readonly string[]).includes(subject);
}

/** Tahrir oynasi uchun: ma'lum fan kaliti yoki «Boshqa…» + erkin matn. */
export type SubjectChoice = { kind: 'known'; key: TimetableSubjectKey } | { kind: 'custom'; text: string } | { kind: 'none' };

export function subjectChoice(subject: string): SubjectChoice {
  const text = subject.trim();
  if (!text) return { kind: 'none' };
  return isKnownSubject(text) ? { kind: 'known', key: text } : { kind: 'custom', text };
}

/* ── Tekshiruv ──────────────────────────────────────────────────────────── */

export type CellErrorKind =
  | 'subjectRequired'
  | 'subjectTooLong'
  | 'roomTooLong'
  | 'teacherTooLong'
  | 'duplicate'
  | 'invalidPeriod'
  | 'invalidWeekday'
  | 'invalid';

/** Bitta katakcha tekshiruvi: bo'sh emas, lekin fani yo'q yoki chegaradan uzun bo'lsa — xato. */
export function validateCell(value: CellValue | undefined): CellErrorKind | null {
  if (!value || isCellEmpty(value)) return null;
  const cell = normalize(value);
  if (!cell.subject) return 'subjectRequired';
  if (cell.subject.length > TIMETABLE_SUBJECT_MAX) return 'subjectTooLong';
  if (cell.room.length > TIMETABLE_ROOM_MAX) return 'roomTooLong';
  if (cell.teacherName.length > TIMETABLE_TEACHER_MAX) return 'teacherTooLong';
  return null;
}

/** Barcha kataklar tekshiruvi (faqat smena davrlaridagilar); kalit → xato turi. */
export function validateGrid(grid: Grid, periods: readonly BellPeriod[]): Record<string, CellErrorKind> {
  const errors: Record<string, CellErrorKind> = {};
  for (const weekday of WEEKDAYS) {
    for (const period of lessonPeriods(periods)) {
      const key = cellKey(weekday, period.no);
      const error = validateCell(grid[key]);
      if (error) errors[key] = error;
    }
  }
  return errors;
}

/* ── Backend 400 xatosini kataklarga bog'lash ──────────────────────────── */

export type SaveErrorMap = {
  /** Katak kaliti → xato turi. */
  cells: Record<string, CellErrorKind>;
  /** Hech bir katakka bog'lanmagan xabar bor — umumiy xato ko'rsatiladi. */
  hasUnmapped: boolean;
};

const INDEX_RE = /lessons?(?:\.|\[)(\d+)\]?/i;
const PAIR_RE = /weekday\D{0,4}([1-9])\D{1,60}?period(?:\s*no)?\D{0,4}(\d{1,2})/i;
const REVERSED_PAIR_RE = /period(?:\s*no)?\D{0,4}(\d{1,2})\D{1,60}?weekday\D{0,4}([1-9])/i;

function kindOf(segment: string): CellErrorKind {
  if (/duplic|takror|unique|already/i.test(segment)) return 'duplicate';
  if (/period|davr/i.test(segment)) return 'invalidPeriod';
  if (/weekday|hafta kun/i.test(segment)) return 'invalidWeekday';
  if (/subject|fan/i.test(segment)) return /empty|required|majburiy|bo'sh/i.test(segment) ? 'subjectRequired' : 'subjectTooLong';
  return 'invalid';
}

function cellOf(segment: string, sent: readonly TimetableLesson[]): string | null {
  const index = INDEX_RE.exec(segment);
  if (index) {
    const lesson = sent[Number(index[1])];
    return lesson ? cellKey(lesson.weekday, lesson.periodNo) : null;
  }
  const pair = PAIR_RE.exec(segment);
  if (pair) return cellKey(Number(pair[1]), Number(pair[2]));
  const reversed = REVERSED_PAIR_RE.exec(segment);
  return reversed ? cellKey(Number(reversed[2]), Number(reversed[1])) : null;
}

/**
 * `ServiceError.message` (400, xabarlar `; ` bilan birlashtirilgan) → katakchalar.
 * Backend yo'li `lessons.3.subject` / `lessons[3]` (yuborilgan ro'yxat indeksi) yoki matnda
 * «weekday 2 … period 3» ko'rinishida kelsa, katakka bog'lanadi; qolgani — umumiy xato.
 */
export function mapSaveError(message: string, sent: readonly TimetableLesson[]): SaveErrorMap {
  const cells: Record<string, CellErrorKind> = {};
  let hasUnmapped = false;
  for (const segment of message.split(';').map((s) => s.trim()).filter(Boolean)) {
    const key = cellOf(segment, sent);
    if (!key) {
      hasUnmapped = true;
      continue;
    }
    cells[key] ??= kindOf(segment);
  }
  return { cells, hasUnmapped: hasUnmapped || Object.keys(cells).length === 0 };
}

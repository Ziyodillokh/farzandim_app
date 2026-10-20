// Natijalar ko'rinishi (sof funksiyalar; panel `assessments-results.ts` bilan bir
// xil qoidalar). Standart ball, persentil va daraja O'QISHDA hisoblanadi —
// me'yor o'zgarsa natijalar darhol qayta baholanadi. Sinf rahbari (`bandsOnly`)
// — faqat darajalar: xom ball, javoblar va vaqt YO'Q.

import { CAREER_ORDER, scoreResult } from './psych/scoring';
import type { AgeBand, PsychResultOrigin, PsychTest, ScaleScore, ScoreBand } from './psych/types';

export const ABILITY_BANDS: readonly ScoreBand[] = ['VERY_LOW', 'LOW', 'AVERAGE', 'HIGH', 'VERY_HIGH'];
export const CONCERN_BANDS: readonly ScoreBand[] = ['TYPICAL', 'WATCH', 'SUPPORT'];

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

/** Bazadagi natija (xom ballar; javoblar shifrlangan). */
export type StoredResult = {
  id: string;
  studentId: string;
  classId: string | null;
  takenAt: Date;
  origin: string;
  assignmentId: string | null;
  ageBand: string;
  raw: unknown;
  durationSec: number | null;
  answersEnc: string | null;
};

const ORIGINS: readonly PsychResultOrigin[] = ['SEED', 'APP', 'IMPORT', 'MANUAL'];
const AGE_BANDS: readonly AgeBand[] = ['A7_8', 'A9_10', 'A11_12', 'A13_14', 'A15_17'];

/** JSON xom ballar → faqat sonli qiymatlar. */
export function rawOf(value: unknown): Record<string, number> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).filter((e): e is [string, number] => typeof e[1] === 'number'));
}

export const ageBandValue = (value: string): AgeBand => (AGE_BANDS.includes(value as AgeBand) ? (value as AgeBand) : 'A11_12');

/** Har o'quvchining eng so'nggi natijasi (kirish `takenAt` bo'yicha eskidan yangiga). */
export function latestPerStudent<T extends { studentId: string; takenAt: Date }>(results: readonly T[]): T[] {
  const latest = new Map<string, T>();
  for (const r of results) {
    const prev = latest.get(r.studentId);
    if (!prev || r.takenAt.getTime() >= prev.takenAt.getTime()) latest.set(r.studentId, r);
  }
  return [...latest.values()].sort((a, b) => b.takenAt.getTime() - a.takenAt.getTime());
}

export function distributionScale(test: PsychTest, wanted: string | undefined): string | null {
  const scored = test.scales.filter((s) => s.display !== 'RAW');
  return (scored.find((s) => s.key === wanted) ?? scored[0])?.key ?? null;
}

export function buildDistribution(test: PsychTest, rows: readonly ResultRow[], scaleKey: string | null): BandBucket[] {
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

/** Baholangan natija (javoblarsiz) — rivojlanish bo'limi kabi o'quvchilar uchun. */
export type ScoredResult = {
  id: string;
  studentId: string;
  classId: string | null;
  grade: number;
  ageBand: AgeBand;
  testId: string;
  version: number;
  assignmentId: string | null;
  takenAt: string;
  origin: PsychResultOrigin;
  raw: Record<string, number>;
  scales: ScaleScore[];
  topCodes: string | null;
};

export type ScorableRow = Omit<StoredResult, 'answersEnc' | 'durationSec'> & { grade: number; testId: string; version: number };

/** Saqlangan xom ball → standart ball, persentil, daraja (joriy me'yorlar bo'yicha). */
export function scoreStoredResult(test: PsychTest, r: ScorableRow): ScoredResult {
  const raw = rawOf(r.raw);
  const ageBand = ageBandValue(r.ageBand);
  return {
    id: r.id,
    studentId: r.studentId,
    classId: r.classId,
    grade: r.grade,
    ageBand,
    testId: r.testId,
    version: r.version,
    assignmentId: r.assignmentId,
    takenAt: r.takenAt.toISOString(),
    origin: ORIGINS.includes(r.origin as PsychResultOrigin) ? (r.origin as PsychResultOrigin) : 'APP',
    raw,
    ...scoreResult(test, { raw, ageBand }),
  };
}

export type RowLookups = { names: ReadonlyMap<string, string>; classNames: ReadonlyMap<string, string> };

/** Saqlangan natija → jadval qatori. `answers` — faqat psixolog uchun ochilgan javoblar. */
export function toResultRow(test: PsychTest, r: StoredResult, bandsOnly: boolean, lookups: RowLookups, answers?: string): ResultRow {
  const scored = scoreResult(test, { raw: rawOf(r.raw), ageBand: ageBandValue(r.ageBand) });
  const classId = r.classId ?? '';
  const base: ResultRow = {
    id: r.id,
    studentId: r.studentId,
    studentName: lookups.names.get(r.studentId) ?? '—',
    classId,
    className: lookups.classNames.get(classId) ?? '—',
    takenAt: r.takenAt.toISOString(),
    origin: ORIGINS.includes(r.origin as PsychResultOrigin) ? (r.origin as PsychResultOrigin) : 'APP',
    assignmentId: r.assignmentId,
    ageBand: ageBandValue(r.ageBand),
    scales: bandsOnly ? scored.scales.map((s) => ({ key: s.key, band: s.band })) : scored.scales,
    topCodes: bandsOnly ? null : scored.topCodes,
  };
  if (bandsOnly) return base;
  return { ...base, ...(r.durationSec !== null ? { durationSec: r.durationSec } : {}), ...(answers ? { answers } : {}) };
}

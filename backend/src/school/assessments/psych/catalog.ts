// Testlar katalogi (sof funksiyalar): shablonlar kodda, maktab holati
// (status, me'yor o'zgarishi) `SchoolPsychTemplateState`da; maktabning o'z /
// import qilingan / tashqi testlari `SchoolPsychTest.definition`da.

import type { SchoolPsychTest } from '@prisma/client';
import { toInstant } from '../assessments-inputs.schemas';
import { PSYCH_TEMPLATES } from './templates';
import { TEMPLATE_IDS } from './templates/specs';
import type { PsychNorms, PsychTest, PsychTestInputShape, PsychTestSource, PsychTestStatus, TemplateId } from './types';

export { TEMPLATE_IDS };

const STATUSES: readonly PsychTestStatus[] = ['DRAFT', 'PUBLISHED', 'ARCHIVED'];
const SOURCES: readonly PsychTestSource[] = ['CUSTOM', 'IMPORTED', 'EXTERNAL'];

export function isTemplateId(id: string): id is TemplateId {
  return (TEMPLATE_IDS as string[]).includes(id);
}

const asStatus = (value: string | null | undefined, fallback: PsychTestStatus): PsychTestStatus =>
  STATUSES.includes(value as PsychTestStatus) ? (value as PsychTestStatus) : fallback;

/** Shablon holati: `null` — standart (nashr etilgan, demo me'yorlar). */
export type TemplateStateRow = { status: string; norms: unknown } | null | undefined;

export function templateTest(id: TemplateId, state: TemplateStateRow): PsychTest {
  const base = PSYCH_TEMPLATES[id];
  const norms = state?.norms && typeof state.norms === 'object' ? (state.norms as PsychNorms) : base.norms;
  return {
    ...base,
    status: asStatus(state?.status, base.status),
    norms,
    updatedAt: toInstant(base.updatedAt).toISOString(),
  };
}

/** `definition` JSON — saqlashda zod bilan tekshirilgan; o'qishda faqat yetishmaganlar to'ldiriladi. */
export function toPsychTest(row: SchoolPsychTest): PsychTest {
  const d = (row.definition ?? {}) as Partial<PsychTestInputShape> & { source?: string };
  const empty = { uz: '', ru: '' };
  return {
    id: row.id,
    title: d.title ?? empty,
    description: d.description ?? empty,
    instructions: d.instructions ?? empty,
    kind: d.kind ?? 'CUSTOM',
    source: SOURCES.includes(d.source as PsychTestSource) ? (d.source as PsychTestSource) : 'CUSTOM',
    grades: d.grades ?? [],
    timeLimitMin: d.timeLimitMin ?? null,
    scales: d.scales ?? [],
    items: d.items ?? [],
    scoring: d.scoring ?? { method: 'SUM' },
    norms: d.norms ?? {},
    version: row.version,
    status: asStatus(row.status, 'DRAFT'),
    createdBy: row.createdBy,
    updatedAt: row.updatedAt.toISOString(),
    basedOn: row.basedOn,
  };
}

/** Testning ko'chma qismi (eksport/import, nusxa) — panel `portableTest`. */
export function portableTest(test: PsychTest): PsychTestInputShape {
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

/** Bazaga yoziladigan `definition` (manba bilan). */
export function definitionOf(body: PsychTestInputShape, source: PsychTestSource): Record<string, unknown> {
  return { ...body, source };
}

/** Kalitlari tartiblangan JSON — JSONB kalit tartibini o'zgartiradi, solishtirish shunga bog'liq bo'lmasin. */
export function canonicalJson(value: unknown): string {
  return JSON.stringify(sortKeys(value));
}

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value === null || typeof value !== 'object') return value;
  const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  return Object.fromEntries(entries.map(([k, v]) => [k, sortKeys(v)]));
}

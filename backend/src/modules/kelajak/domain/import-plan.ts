// Import CLI rejasi (scripts/kelajak/import-bank.ts) — sof funksiya: fayldagi
// savollar + bazadagi mavjudlari → nima yaratiladi, yangilanadi yoki o'tkazib
// yuboriladi. Javob berilgan savolning `answerType`, `options`, `category`,
// `ageGroup`, `scoring` va `reverse` maydonlari `--update` bilan ham
// o'zgarmaydi (admin PATCH bilan bir xil ro'yxat) — ogohlantirish. Admin
// tahrirlagan (yoki yaratgan) savol `--overwrite-admin-edits`siz umuman
// qayta yozilmaydi — admin tuzatishlari keyingi importda yo'qolmasin.

import { KelajakQuestionData, ParsedBank } from './bank';

/**
 * Javob berilgan savolda o'zgarmaydigan maydonlar — import va admin uchun
 * YAGONA ro'yxat: profil va signal xom javoblardan joriy savol ma'lumoti
 * bilan qayta hisoblanadi, shuning uchun ballar tarixi buzilmasin.
 */
export const LOCKED_WHEN_ANSWERED = ['answerType', 'options', 'category', 'ageGroup', 'scoring', 'reverse'] as const;

export const UPDATABLE_FIELDS = [
  'category',
  'ageGroup',
  'text',
  'answerType',
  'options',
  'scoring',
  'reverse',
  'required',
  'followUp',
  'notes',
  'reviewNote',
  'sourceType',
  'sourceName',
  'sourceVersion',
  'active',
] as const satisfies ReadonlyArray<keyof KelajakQuestionData>;
export type UpdatableField = (typeof UPDATABLE_FIELDS)[number];
export type QuestionChanges = Partial<Pick<KelajakQuestionData, UpdatableField>>;

/** Bazadagi savol (JSON ustunlari xom holda), javoblar soni va admin tahriri. */
export type ExistingKelajakQuestion = Readonly<Record<UpdatableField, unknown>> & {
  id: string;
  externalId: string;
  answerCount: number;
  /** Admin yaratgan yoki tahrirlagan (audit jurnalida `kelajak.question.update`). */
  adminEdited: boolean;
};

export type SkipReason = 'exists' | 'unchanged' | 'no_external_id' | 'admin_edited';

export interface ImportPlan {
  create: Array<KelajakQuestionData & { externalId: string }>;
  update: Array<{
    id: string;
    externalId: string;
    fields: UpdatableField[];
    changes: QuestionChanges;
  }>;
  skipped: Array<{ externalId: string | null; reason: SkipReason }>;
  locked: Array<{ externalId: string; fields: UpdatableField[] }>;
  /** Admin tahrirlagan, fayldan farq qiladigan savollar (qayta yozilmadi). */
  adminEdited: Array<{ externalId: string; fields: UpdatableField[] }>;
}

/** Kalitlari saralangan JSON — JSONB ustunlarini tartibdan qat'i nazar solishtirish. */
export function stableJson(value: unknown): string {
  if (value === undefined || value === null) return 'null';
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, v]) => v !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${stableJson(v)}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

type Decision =
  | { kind: 'create'; question: KelajakQuestionData & { externalId: string } }
  | { kind: 'update'; externalId: string; entry: ImportPlan['update'][number]; locked: UpdatableField[] }
  | {
      kind: 'skip';
      externalId: string | null;
      reason: SkipReason;
      locked: UpdatableField[];
      /** `admin_edited` — fayldan farq qiladigan maydonlar. */
      differs?: UpdatableField[];
    };

const isLocked = (field: UpdatableField) => (LOCKED_WHEN_ANSWERED as readonly string[]).includes(field);

interface ImportOptions {
  update: boolean;
  overwriteAdminEdits: boolean;
}

function decide(
  question: KelajakQuestionData,
  existing: ExistingKelajakQuestion | undefined,
  options: ImportOptions,
): Decision {
  const { externalId } = question;
  if (externalId === null) return { kind: 'skip', externalId, reason: 'no_external_id', locked: [] };
  if (!existing) return { kind: 'create', question: { ...question, externalId } };
  if (!options.update) return { kind: 'skip', externalId, reason: 'exists', locked: [] };

  const changed = UPDATABLE_FIELDS.filter((f) => stableJson(existing[f]) !== stableJson(question[f]));
  if (changed.length > 0 && existing.adminEdited && !options.overwriteAdminEdits) {
    return { kind: 'skip', externalId, reason: 'admin_edited', locked: [], differs: changed };
  }
  const locked = existing.answerCount > 0 ? changed.filter(isLocked) : [];
  const fields = changed.filter((f) => !locked.includes(f));
  if (fields.length === 0) return { kind: 'skip', externalId, reason: 'unchanged', locked };
  const changes = Object.fromEntries(fields.map((f) => [f, question[f]])) as QuestionChanges;
  return { kind: 'update', externalId, entry: { id: existing.id, externalId, fields, changes }, locked };
}

export function planKelajakImport(params: {
  questions: readonly KelajakQuestionData[];
  existing: readonly ExistingKelajakQuestion[];
  update: boolean;
  /** Admin tahrirlagan savollarni ham fayl bo'yicha yozish (aniq ruxsat). */
  overwriteAdminEdits?: boolean;
}): ImportPlan {
  const options: ImportOptions = { update: params.update, overwriteAdminEdits: params.overwriteAdminEdits ?? false };
  const byExternalId = new Map(params.existing.map((e) => [e.externalId, e]));
  const decisions = params.questions.map((q) =>
    decide(q, q.externalId === null ? undefined : byExternalId.get(q.externalId), options),
  );
  return {
    create: decisions.flatMap((d) => (d.kind === 'create' ? [d.question] : [])),
    update: decisions.flatMap((d) => (d.kind === 'update' ? [d.entry] : [])),
    skipped: decisions.flatMap((d) =>
      d.kind === 'skip' ? [{ externalId: d.externalId, reason: d.reason }] : [],
    ),
    locked: decisions.flatMap((d) =>
      d.kind !== 'create' && d.locked.length > 0 && d.externalId !== null
        ? [{ externalId: d.externalId, fields: d.locked }]
        : [],
    ),
    adminEdited: decisions.flatMap((d) =>
      d.kind === 'skip' && d.reason === 'admin_edited' && d.externalId !== null
        ? [{ externalId: d.externalId, fields: d.differs ?? [] }]
        : [],
    ),
  };
}

const SKIP_LABELS: Readonly<Record<SkipReason, string>> = {
  exists: 'mavjud',
  unchanged: 'o\'zgarishsiz',
  no_external_id: 'externalId yo\'q',
  admin_edited: 'admin tahrirlagan',
};

/** CLI hisoboti (o'qildi, valid, xato, dublikat, yaratildi, yangilandi, ...). */
export function formatImportReport(input: {
  file: string;
  parsed: ParsedBank;
  plan: ImportPlan;
  dryRun: boolean;
}): string {
  const { file, parsed, plan, dryRun } = input;
  const skippedBy = (reason: SkipReason) => plan.skipped.filter((s) => s.reason === reason).length;
  const row = (label: string, value: string | number) => `  ${label.padEnd(24)}${value}`;
  const section = (title: string, lines: string[]) =>
    lines.length > 0 ? [title, ...lines.map((l) => `  ${l}`)] : [];

  return [
    `Kelajak savollar banki importi: ${file}${dryRun ? ' (dry-run — bazaga yozilmadi)' : ''}`,
    row('O\'qildi:', parsed.read),
    row('Valid:', parsed.valid.length),
    row('Xato:', parsed.invalid.length),
    row('Fayldagi dublikat:', parsed.duplicates.length),
    row('Yaratildi:', plan.create.length),
    row('Yangilandi:', plan.update.length),
    row(
      'O\'tkazib yuborildi:',
      `${plan.skipped.length} (${(Object.keys(SKIP_LABELS) as SkipReason[])
        .map((r) => `${SKIP_LABELS[r]}: ${skippedBy(r)}`)
        .join(', ')})`,
    ),
    row('Bloklangan (javob bor):', plan.locked.length),
    row('Admin tahrirlagan:', plan.adminEdited.length),
    ...section(
      'Xatolar:',
      parsed.invalid.map((e) => `#${e.index} ${e.externalId ?? '?'}: ${e.error}`),
    ),
    ...section(
      'Dublikatlar (birinchisi olindi):',
      parsed.duplicates.map((d) => `${d.externalId}: ${d.indexes.map((i) => `#${i}`).join(', ')}`),
    ),
    ...section(
      'Yangilangan maydonlar:',
      plan.update.map((u) => `${u.externalId}: ${u.fields.join(', ')}`),
    ),
    ...section(
      'Javob berilgan savol — o\'zgartirilmadi:',
      plan.locked.map((l) => `${l.externalId}: ${l.fields.join(', ')}`),
    ),
    ...section('Ogohlantirishlar:', [
      ...parsed.warnings,
      ...plan.adminEdited.map(
        (a) => `${a.externalId}: admin tahrirlagan — qayta yozilmadi (${a.fields.join(', ')}); kerak bo'lsa --overwrite-admin-edits`,
      ),
    ]),
    '',
  ].join('\n');
}

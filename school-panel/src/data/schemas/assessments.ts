import { z } from 'zod';
import { msg } from './common';

/**
 * Psixologik testlar sxemalari — test konstruktori (forma), servis va JSON import
 * BIR XIL sxemadan foydalanadi. `.strict()` — noma'lum maydonlar rad etiladi.
 * Xabarlar — i18n kalitlari (`errors.form.*` yoki `assessments.validation.*`).
 */
export const PSYCH_KINDS = ['COGNITIVE', 'ATTENTION', 'EMOTIONAL', 'SELF_ESTEEM', 'CAREER', 'SOCIAL', 'CUSTOM'] as const;
export const DEV_DOMAINS = ['REASONING', 'ATTENTION', 'MEMORY', 'EMOTIONAL', 'SELF_ESTEEM', 'SOCIAL'] as const;
export const AGE_BAND_KEYS = ['A7_8', 'A9_10', 'A11_12', 'A13_14', 'A15_17'] as const;
export const POLARITIES = ['HIGHER_BETTER', 'HIGHER_CONCERN'] as const;
export const DISPLAYS = ['STANDARD', 'PERCENTILE', 'LEVEL', 'RAW'] as const;
export const ITEM_TYPES = ['SINGLE', 'LIKERT', 'MULTI'] as const;
export const SCORING_METHODS = ['SUM', 'PERCENT_CORRECT', 'PER_SCALE'] as const;

export const PSYCH_LIMITS = {
  text: 300,
  title: 120,
  items: 60,
  options: 8,
  /** MULTI javobi bitta belgida (5 bitli niqob) kodlanadi. */
  multiOptions: 5,
  scales: 8,
  jsonBytes: 200 * 1024,
  csvBytes: 512 * 1024,
  csvRows: 2000,
  externalRawMax: 1000,
} as const;

/** Kalitlar: harf bilan boshlanadi, 24 belgigacha (`__proto__` kabi kalitlar ham rad etiladi). */
export const KEY_RE = /^[A-Za-z][A-Za-z0-9_]{0,23}$/;

export const vmsg = {
  key: 'assessments.validation.key',
  duplicateKey: 'assessments.validation.duplicateKey',
  unknownScale: 'assessments.validation.unknownScale',
  correct: 'assessments.validation.correct',
  sd: 'assessments.validation.sd',
  duplicateBand: 'assessments.validation.duplicateBand',
  options: 'assessments.validation.options',
  consent: 'assessments.validation.consent',
} as const;

const keySchema = z.string({ required_error: msg.required }).regex(KEY_RE, vmsg.key);
const text = (max: number = PSYCH_LIMITS.text) => z.string({ required_error: msg.required }).trim().min(1, msg.required).max(max, msg.tooLong);
const optionalText = (max: number = PSYCH_LIMITS.text) => z.string().trim().max(max, msg.tooLong);

export const localizedSchema = z.object({ uz: text(), ru: text() }).strict();
const titleSchema = z.object({ uz: text(PSYCH_LIMITS.title), ru: text(PSYCH_LIMITS.title) }).strict();
const optionalLocalized = z.object({ uz: optionalText(), ru: optionalText() }).strict();

export const scaleSchema = z
  .object({
    key: keySchema,
    label: localizedSchema,
    domain: z.enum(DEV_DOMAINS).nullable(),
    polarity: z.enum(POLARITIES),
    display: z.enum(DISPLAYS),
  })
  .strict();

const optionSchema = z.object({ key: keySchema, text: localizedSchema }).strict();
const multiOptionSchema = z.object({ key: keySchema, text: localizedSchema, scale: keySchema }).strict();
const stimulusSchema = z.object({ text: localizedSchema, showSec: z.number().int().min(1).max(60) }).strict();

const singleItemSchema = z
  .object({
    id: keySchema,
    type: z.literal('SINGLE'),
    scale: keySchema,
    text: localizedSchema,
    options: z.array(optionSchema).min(2, vmsg.options).max(PSYCH_LIMITS.options, vmsg.options),
    correct: keySchema,
    stimulus: stimulusSchema.optional(),
  })
  .strict();
const likertItemSchema = z.object({ id: keySchema, type: z.literal('LIKERT'), scale: keySchema, text: localizedSchema, reverse: z.boolean() }).strict();
const multiItemSchema = z
  .object({
    id: keySchema,
    type: z.literal('MULTI'),
    text: localizedSchema,
    options: z.array(multiOptionSchema).min(2, vmsg.options).max(PSYCH_LIMITS.multiOptions, vmsg.options),
  })
  .strict();

export const itemSchema = z.discriminatedUnion('type', [singleItemSchema, likertItemSchema, multiItemSchema]);

const normRowSchema = z
  .object({ band: z.enum(AGE_BAND_KEYS), mean: z.number().finite().min(-1000).max(1000), sd: z.number().finite().max(1000) })
  .strict();
export const normsSchema = z.record(keySchema, z.array(normRowSchema).max(AGE_BAND_KEYS.length));

type NormsValue = z.infer<typeof normsSchema>;
type Ctx = z.RefinementCtx;

function issue(ctx: Ctx, path: Array<string | number>, message: string): void {
  ctx.addIssue({ code: z.ZodIssueCode.custom, path, message });
}

/** Me'yorlar: shkala mavjud, sd > 0, yosh bandi takrorlanmaydi. */
export function refineNorms(norms: NormsValue, scaleKeys: ReadonlySet<string>, ctx: Ctx, base: Array<string | number> = ['norms']): void {
  for (const [key, rows] of Object.entries(norms)) {
    if (!scaleKeys.has(key)) issue(ctx, [...base, key], vmsg.unknownScale);
    const seen = new Set<string>();
    rows.forEach((row, i) => {
      if (!(row.sd > 0)) issue(ctx, [...base, key, i, 'sd'], vmsg.sd);
      if (seen.has(row.band)) issue(ctx, [...base, key, i, 'band'], vmsg.duplicateBand);
      seen.add(row.band);
    });
  }
}

function uniqueKeys(keys: readonly string[], ctx: Ctx, pathOf: (i: number) => Array<string | number>): void {
  const seen = new Set<string>();
  keys.forEach((k, i) => {
    if (seen.has(k)) issue(ctx, pathOf(i), vmsg.duplicateKey);
    seen.add(k);
  });
}

type ItemValue = z.infer<typeof itemSchema>;

function refineItem(item: ItemValue, i: number, scaleKeys: ReadonlySet<string>, ctx: Ctx): void {
  if (item.type !== 'LIKERT') uniqueKeys(item.options.map((o) => o.key), ctx, (j) => ['items', i, 'options', j, 'key']);
  if (item.type === 'MULTI') {
    item.options.forEach((o, j) => {
      if (!scaleKeys.has(o.scale)) issue(ctx, ['items', i, 'options', j, 'scale'], vmsg.unknownScale);
    });
    return;
  }
  if (!scaleKeys.has(item.scale)) issue(ctx, ['items', i, 'scale'], vmsg.unknownScale);
  if (item.type === 'SINGLE' && !item.options.some((o) => o.key === item.correct)) issue(ctx, ['items', i, 'correct'], vmsg.correct);
}

const testShape = z
  .object({
    title: titleSchema,
    description: optionalLocalized,
    instructions: optionalLocalized,
    kind: z.enum(PSYCH_KINDS),
    grades: z.array(z.number().int().min(1).max(11)).min(1, msg.atLeastOne).max(11),
    timeLimitMin: z.number().int().min(1).max(120).nullable(),
    scales: z.array(scaleSchema).min(1, msg.atLeastOne).max(PSYCH_LIMITS.scales, msg.tooLong),
    items: z.array(itemSchema).max(PSYCH_LIMITS.items, msg.tooLong),
    scoring: z.object({ method: z.enum(SCORING_METHODS) }).strict(),
    norms: normsSchema,
  })
  .strict();

export const psychTestInputSchema = testShape.superRefine((v, ctx) => {
  uniqueKeys(v.scales.map((s) => s.key), ctx, (i) => ['scales', i, 'key']);
  uniqueKeys(v.items.map((it) => it.id), ctx, (i) => ['items', i, 'id']);
  const scaleKeys = new Set(v.scales.map((s) => s.key));
  v.items.forEach((item, i) => refineItem(item, i, scaleKeys, ctx));
  refineNorms(v.norms, scaleKeys, ctx);
});

export const PSYCH_EXPORT_FORMAT = 'parvoz.psych-test';
export const PSYCH_EXPORT_VERSION = 1;

/** JSON fayl konverti (eksport/import). */
export const psychTestFileSchema = z
  .object({
    format: z.literal(PSYCH_EXPORT_FORMAT),
    formatVersion: z.literal(PSYCH_EXPORT_VERSION),
    exportedAt: z.string().max(40).optional(),
    test: psychTestInputSchema,
  })
  .strict();

const dateTimeSchema = z
  .string({ required_error: msg.required })
  .min(1, msg.required)
  .refine((v) => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(v) && !Number.isNaN(Date.parse(v)), msg.date);

export const assignInputSchema = z
  .object({
    testId: z.string().min(1, msg.required),
    target: z.discriminatedUnion('kind', [
      z.object({ kind: z.literal('CLASSES'), classIds: z.array(z.string().min(1)).min(1, msg.atLeastOne).max(60) }).strict(),
      z.object({ kind: z.literal('GRADES'), grades: z.array(z.number().int().min(1).max(11)).min(1, msg.atLeastOne).max(11) }).strict(),
    ]),
    opensAt: dateTimeSchema,
    closesAt: dateTimeSchema,
    consent: z.literal(true, { errorMap: () => ({ message: vmsg.consent }) }),
  })
  .strict()
  .refine((v) => Date.parse(v.closesAt) > Date.parse(v.opensAt), { path: ['closesAt'], message: msg.endBeforeStart });

export type PsychTestInput = z.input<typeof psychTestInputSchema>;
export type PsychItemInput = z.input<typeof itemSchema>;
export type PsychScaleInput = z.input<typeof scaleSchema>;
export type PsychNormsInput = z.input<typeof normsSchema>;
export type AssignInput = z.input<typeof assignInputSchema>;

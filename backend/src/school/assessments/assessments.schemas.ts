// Psixologik test sxemalari — panel `school-panel/src/data/schemas/assessments.ts`
// bilan bir xil qoidalar (zod v4): konstruktor, servis va JSON import BIR XIL
// sxemadan foydalanadi. `strictObject` — noma'lum maydonlar rad etiladi.
// Xabarlar — i18n kalitlari (`errors.form.*` yoki `assessments.validation.*`).

import { z } from 'zod';
import { msg } from '../common/school-zod';

export const PSYCH_KINDS = ['COGNITIVE', 'ATTENTION', 'EMOTIONAL', 'SELF_ESTEEM', 'CAREER', 'SOCIAL', 'CUSTOM'] as const;
export const DEV_DOMAINS = ['REASONING', 'ATTENTION', 'MEMORY', 'EMOTIONAL', 'SELF_ESTEEM', 'SOCIAL'] as const;
export const AGE_BAND_KEYS = ['A7_8', 'A9_10', 'A11_12', 'A13_14', 'A15_17'] as const;
export const POLARITIES = ['HIGHER_BETTER', 'HIGHER_CONCERN'] as const;
export const DISPLAYS = ['STANDARD', 'PERCENTILE', 'LEVEL', 'RAW'] as const;
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
/** `constructor`, `toString` … — meros xossalar kalit bo'lolmaydi (prototip ifloslanishidan himoya). */
const RESERVED_KEYS: ReadonlySet<string> = new Set(Object.getOwnPropertyNames(Object.prototype));

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

const keySchema = z
  .string({ error: msg.required })
  .regex(KEY_RE, vmsg.key)
  .refine((k) => !RESERVED_KEYS.has(k), vmsg.key);
const text = (max: number = PSYCH_LIMITS.text) => z.string({ error: msg.required }).trim().min(1, msg.required).max(max, msg.tooLong);
const optionalText = (max: number = PSYCH_LIMITS.text) => z.string({ error: msg.required }).trim().max(max, msg.tooLong);

export const localizedSchema = z.strictObject({ uz: text(), ru: text() });
const titleSchema = z.strictObject({ uz: text(PSYCH_LIMITS.title), ru: text(PSYCH_LIMITS.title) });
const optionalLocalized = z.strictObject({ uz: optionalText(), ru: optionalText() });

export const scaleSchema = z.strictObject({
  key: keySchema,
  label: localizedSchema,
  domain: z.enum(DEV_DOMAINS).nullable(),
  polarity: z.enum(POLARITIES),
  display: z.enum(DISPLAYS),
});

const optionSchema = z.strictObject({ key: keySchema, text: localizedSchema });
const multiOptionSchema = z.strictObject({ key: keySchema, text: localizedSchema, scale: keySchema });
const stimulusSchema = z.strictObject({ text: localizedSchema, showSec: z.number().int().min(1).max(60) });

const singleItemSchema = z.strictObject({
  id: keySchema,
  type: z.literal('SINGLE'),
  scale: keySchema,
  text: localizedSchema,
  options: z.array(optionSchema).min(2, vmsg.options).max(PSYCH_LIMITS.options, vmsg.options),
  correct: keySchema,
  stimulus: stimulusSchema.optional(),
});
const likertItemSchema = z.strictObject({ id: keySchema, type: z.literal('LIKERT'), scale: keySchema, text: localizedSchema, reverse: z.boolean() });
const multiItemSchema = z.strictObject({
  id: keySchema,
  type: z.literal('MULTI'),
  text: localizedSchema,
  options: z.array(multiOptionSchema).min(2, vmsg.options).max(PSYCH_LIMITS.multiOptions, vmsg.options),
});

export const itemSchema = z.discriminatedUnion('type', [singleItemSchema, likertItemSchema, multiItemSchema]);

const normRowSchema = z.strictObject({
  band: z.enum(AGE_BAND_KEYS),
  mean: z.number().min(-1000).max(1000),
  sd: z.number().max(1000),
});
/** Noto'g'ri kalit (`1bad`, `constructor`) — panel kabi `norms.<kalit>: assessments.validation.key`. */
export const normsSchema = z.record(keySchema, z.array(normRowSchema).max(AGE_BAND_KEYS.length), {
  error: (iss) => (iss.code === 'invalid_key' ? vmsg.key : undefined),
});

type NormsValue = z.infer<typeof normsSchema>;
type ItemValue = z.infer<typeof itemSchema>;
type Ctx = z.RefinementCtx;
type Path = Array<string | number>;

function issue(ctx: Ctx, path: Path, message: string): void {
  ctx.addIssue({ code: 'custom', path, message });
}

/** Me'yorlar: shkala mavjud, sd > 0, yosh bandi takrorlanmaydi. */
export function refineNorms(norms: NormsValue, scaleKeys: ReadonlySet<string>, ctx: Ctx, base: Path = ['norms']): void {
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

function uniqueKeys(keys: readonly string[], ctx: Ctx, pathOf: (i: number) => Path): void {
  const seen = new Set<string>();
  keys.forEach((k, i) => {
    if (seen.has(k)) issue(ctx, pathOf(i), vmsg.duplicateKey);
    seen.add(k);
  });
}

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

const testShape = z.strictObject({
  title: titleSchema,
  description: optionalLocalized,
  instructions: optionalLocalized,
  kind: z.enum(PSYCH_KINDS),
  grades: z.array(z.number().int().min(1).max(11)).min(1, msg.atLeastOne).max(11),
  timeLimitMin: z.number().int().min(1).max(120).nullable(),
  scales: z.array(scaleSchema).min(1, msg.atLeastOne).max(PSYCH_LIMITS.scales, msg.tooLong),
  items: z.array(itemSchema).max(PSYCH_LIMITS.items, msg.tooLong),
  scoring: z.strictObject({ method: z.enum(SCORING_METHODS) }),
  norms: normsSchema,
});

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
export const psychTestFileSchema = z.strictObject({
  format: z.literal(PSYCH_EXPORT_FORMAT),
  formatVersion: z.literal(PSYCH_EXPORT_VERSION),
  exportedAt: z.string().max(40).optional(),
  test: psychTestInputSchema,
});

/** Bitta test uchun me'yorlar (shablon yoki o'z testi): yo'llar `total.0.sd` shaklida. */
export function testNormsSchema(scaleKeys: ReadonlySet<string>) {
  return normsSchema.superRefine((v, ctx) => refineNorms(v, scaleKeys, ctx, []));
}

export type PsychTestInput = z.output<typeof psychTestInputSchema>;
export type PsychNormsInput = z.output<typeof normsSchema>;

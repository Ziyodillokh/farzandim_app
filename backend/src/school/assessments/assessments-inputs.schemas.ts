// Tayinlash, ro'yxat filtrlari, import tanalari va bola ilovasi javoblari.
// Vaqtlar: panel `datetime-local` ("2026-10-12T08:00") — Toshkent devor soati;
// zona ko'rsatilgan bo'lsa ("…Z", "+05:00") — shu lahza.

import { z } from 'zod';
import { msg } from '../common/school-zod';
import { PSYCH_KINDS, PSYCH_LIMITS, vmsg } from './assessments.schemas';

export const TEST_STATUSES = ['DRAFT', 'PUBLISHED', 'ARCHIVED'] as const;
export const TEST_SOURCES = ['TEMPLATE', 'CUSTOM', 'IMPORTED', 'EXTERNAL'] as const;
export const ASSIGNMENT_STATES = ['SCHEDULED', 'ACTIVE', 'ENDED', 'CANCELLED'] as const;

const ID_MAX = 64;
const id = () => z.string({ error: msg.required }).trim().min(1, msg.required).max(ID_MAX, msg.tooLong);
const TASHKENT_OFFSET_MS = 5 * 3_600_000;
const HAS_ZONE = /[zZ]|[+-]\d{2}:?\d{2}$/;
const LOCAL = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?$/;

/** Zonasiz "YYYY-MM-DDTHH:MM(:SS(.sss))" — Toshkent devor soati; 31-fevral kabi sanalar rad etiladi. */
function fromLocal(value: string): Date {
  const m = LOCAL.exec(value);
  if (!m) return new Date(Number.NaN);
  const [y, mo, d, h, mi, s] = m.slice(1, 7).map((part) => (part === undefined ? 0 : Number(part))) as number[];
  const ms = m[7] === undefined ? 0 : Number(m[7].padEnd(3, '0'));
  const utc = Date.UTC(y!, mo! - 1, d!, h!, mi!, s!, ms);
  const check = new Date(utc);
  const exact =
    check.getUTCFullYear() === y && check.getUTCMonth() === mo! - 1 && check.getUTCDate() === d && check.getUTCHours() === h && check.getUTCMinutes() === mi && check.getUTCSeconds() === s;
  return exact ? new Date(utc - TASHKENT_OFFSET_MS) : new Date(Number.NaN);
}

/** Panel qiymati → lahza (zonasiz qiymat — Toshkent vaqti); noto'g'ri qiymat — `Invalid Date`. */
export function toInstant(value: string): Date {
  return HAS_ZONE.test(value) ? new Date(value) : fromLocal(value);
}

const dateTimeSchema = z
  .string({ error: msg.required })
  .min(1, msg.required)
  .max(40, msg.tooLong)
  .refine((v) => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(v) && !Number.isNaN(toInstant(v).getTime()), msg.date);

export const assignInputSchema = z
  .strictObject({
    testId: id(),
    target: z.discriminatedUnion('kind', [
      z.strictObject({ kind: z.literal('CLASSES'), classIds: z.array(id()).min(1, msg.atLeastOne).max(60) }),
      z.strictObject({ kind: z.literal('GRADES'), grades: z.array(z.number().int().min(1).max(11)).min(1, msg.atLeastOne).max(11) }),
    ]),
    opensAt: dateTimeSchema,
    closesAt: dateTimeSchema,
    consent: z.literal(true, { error: vmsg.consent }),
  })
  .refine((v) => toInstant(v.closesAt).getTime() > toInstant(v.opensAt).getTime(), { path: ['closesAt'], error: msg.endBeforeStart });

export type AssignInput = z.output<typeof assignInputSchema>;

const optionalId = z.string().trim().max(ID_MAX, msg.tooLong).optional();

export const testFilterSchema = z.object({
  kind: z.enum(PSYCH_KINDS).optional(),
  status: z.enum(TEST_STATUSES).optional(),
  source: z.enum(TEST_SOURCES).optional(),
  search: z.string().trim().max(100, msg.tooLong).optional(),
});

export const assignmentFilterSchema = z.object({
  testId: optionalId,
  state: z.enum(ASSIGNMENT_STATES).optional(),
});

export const resultsFilterSchema = z.object({
  classId: optionalId,
  assignmentId: optionalId,
  scale: z.string().trim().max(24, msg.tooLong).optional(),
});

export type ResultsFilter = z.output<typeof resultsFilterSchema>;

/** `PUT tests/:id/norms` — `null` standart (shablon) me'yorlarni tiklaydi. */
export const normsBodySchema = z.object({ norms: z.unknown().optional() });

/** Fayl matni (tur va hajm servisda tekshiriladi — panel bilan bir xil xabarlar). */
export const importBodySchema = z.object({ json: z.unknown().optional() });
export const csvBodySchema = z.object({ text: z.unknown().optional() });

/** Bola javobi: SINGLE — variant kaliti; LIKERT — 1..5; MULTI — variant kalitlari; null — o'tkazilgan. */
const answerValue = z.union([
  z.string().max(24),
  z.number(),
  z.array(z.string().max(24)).max(PSYCH_LIMITS.multiOptions),
  z.null(),
]);

export const submitInputSchema = z.object({
  answers: z
    .record(z.string().min(1).max(24), answerValue)
    .refine((a) => Object.keys(a).length <= PSYCH_LIMITS.items, msg.tooLong),
  durationSec: z.number().int().min(0).max(86_400).nullable().optional(),
});

export type ChildAnswer = z.output<typeof answerValue>;

// Kiruvchi test ta'rifini tekshirish: prototip himoyasi → qat'iy zod sxema.
// Xato — VALIDATION (`yo'l: xabar`, panel `parseOrThrow` bilan bir xil shakl).

import { invalid } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { PSYCH_LIMITS, psychTestFileSchema, psychTestInputSchema, testNormsSchema, vmsg } from './assessments.schemas';
import { findUnsafeJson } from './psych/safe-json';
import type { PsychNorms, PsychTest, PsychTestInputShape } from './psych/types';

const JSON_TOO_LARGE = 'file: assessments.validation.jsonTooLarge';
const JSON_PARSE = 'file: assessments.validation.jsonParse';

/** `__proto__` / `constructor` / `prototype` kalitlari — saqlashdan oldin rad etiladi. */
export function assertSafeJson(value: unknown, base: ReadonlyArray<string | number> = []): void {
  const unsafe = findUnsafeJson(value);
  if (!unsafe) return;
  if (unsafe.reason === 'depth') throw invalid(JSON_PARSE);
  throw invalid(`${[...base, ...unsafe.path].join('.')}: ${vmsg.key}`);
}

/** Konstruktor formasi (yaratish / tahrirlash). */
export function parseTestInput(input: unknown): PsychTestInputShape {
  assertSafeJson(input);
  return parseOrThrow(psychTestInputSchema, input);
}

/** JSON fayl matni: hajm (200 KB) → JSON → himoya → konvert sxemasi. */
export function parseTestFile(json: unknown): PsychTestInputShape {
  if (typeof json !== 'string' || Buffer.byteLength(json, 'utf8') > PSYCH_LIMITS.jsonBytes) throw invalid(JSON_TOO_LARGE);
  let value: unknown;
  try {
    value = JSON.parse(json) as unknown;
  } catch {
    throw invalid(JSON_PARSE);
  }
  assertSafeJson(value);
  return parseOrThrow(psychTestFileSchema, value).test;
}

/** Bitta testning me'yorlari (shkalalari bo'yicha); yo'llar `total.0.sd` shaklida. */
export function parseTestNorms(test: Pick<PsychTest, 'scales'>, norms: unknown): PsychNorms {
  assertSafeJson(norms);
  return parseOrThrow(testNormsSchema(new Set(test.scales.map((s) => s.key))), norms);
}

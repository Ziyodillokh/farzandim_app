import type { DevDomain, HistoryWave, IsoDate, PsychResult, PsychScale, SchoolClass, Student, TemplateId } from '@/data/contracts';
import { latent, normalFromHash, waveDrift } from '@/lib/psych/latent';
import { ageBandOf, ageOn, CAREER_ORDER, normFor } from '@/lib/psych/scoring';
import { academicYearOf } from '@/lib/psych/terms';
import { unitHash } from '@/lib/rng';
import { addDays, isoWeekday } from '../calendar';
import { PSYCH_TEMPLATES } from '../seed/psych-templates';
import { TEMPLATE_SPECS, type TemplateSpec } from '../seed/psych-templates/specs';
import type { Tables } from '../tables';

/**
 * O'tgan choraklar tarixi — SAQLANMAYDI, `tables.psychHistory` to'lqinlaridan deterministik
 * hisoblanadi (localStorage ~0 KB). Xom ball = me'yor o'rtachasi + sd · (latent + to'lqin tebranishi),
 * shuning uchun ilovadagi jonli natijalar (agent A, xuddi shu `latent` modeli) tarix bilan mos keladi.
 */
export const HISTORY_MIN_GRADE = 3;
/** To'lqinda qatnashish ulushi (kasallik, tadbir — test kuni maktabda bo'lmagan). */
export const HISTORY_PARTICIPATION = 0.88;
const CAREER_MID = 3;
const CAREER_SPREAD = 1.6;
const SCALE_NOISE = 0.3;
/**
 * `latent` ~ N(0,1), to'lqin tebranishi sd 0.35 — kuzatilgan z ni birlik dispersiyaga keltiramiz,
 * aks holda yaratilgan ballar me'yorlardan kengroq (sd ≈ 16) bo'lib qoladi.
 */
const OBSERVED_SD = Math.hypot(1, 0.35);
const FIRST_MINUTE = 9 * 60;
const MINUTE_SPAN = 5 * 60;

type Memo = { key: string; results: PsychResult[] };
let memo: Memo | null = null;
const byStudentsRef = new WeakMap<readonly Student[], Memo>();

/** "2025-26:Q4" → joriy (langar) o'quv yili: oxirgi to'lqindan keyingi chorak. */
export function anchorYearOf(waves: readonly HistoryWave[], fallback: IsoDate | null): number | null {
  const last = waves.at(-1);
  const match = last?.key.match(/^(\d{4})-\d{2}:Q([1-4])$/);
  if (match) return Number(match[2]) === 4 ? Number(match[1]) + 1 : Number(match[1]);
  return fallback ? academicYearOf(fallback) : null;
}

function fingerprint(t: Pick<Tables, 'psychHistory' | 'students' | 'school'>): string {
  const h = t.psychHistory;
  const waves = h.waves.map((w) => `${w.key}@${w.date}:${w.testIds.join('+')}`).join(';');
  const students = t.students.map((s) => `${s.id}/${s.classId}/${s.archived ? 1 : 0}`).join(',');
  return `${t.school?.academicYear ?? ''}|${h.seed}|${waves}|${students}`;
}

function testDate(wave: HistoryWave, classId: string): IsoDate {
  const offset = Math.floor(unitHash(classId, wave.key, 'day') * 7) - 3;
  const day = addDays(wave.date, offset);
  return isoWeekday(day) === 7 ? addDays(day, 1) : day;
}

function takenAtOf(date: IsoDate, studentId: string, tpl: TemplateId): string {
  const minute = FIRST_MINUTE + Math.floor(unitHash(studentId, date, tpl, 'min') * MINUTE_SPAN);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date}T${pad(Math.floor(minute / 60))}:${pad(minute % 60)}:00`;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/** Soha shkalasi: z = latent + tebranish; xavotir (HIGHER_CONCERN) — farovonlik latentining teskarisi. */
function domainZ(scale: PsychScale, domain: DevDomain, studentId: string, classId: string, wave: number, lastWave: number, spec: TemplateSpec): number {
  const base = (latent(studentId, domain, classId) + waveDrift(studentId, domain, wave, lastWave)) / OBSERVED_SD;
  const sameDomain = spec.scales.filter((s) => s.domain === domain);
  const extra = sameDomain.length > 1 && scale.polarity === 'HIGHER_BETTER' ? SCALE_NOISE * normalFromHash(studentId, scale.key, wave) : 0;
  return scale.polarity === 'HIGHER_CONCERN' ? -base : base + extra;
}

function careerRaw(studentId: string, wave: number, max: number): Record<string, number> {
  return Object.fromEntries(
    CAREER_ORDER.map((code) => {
      const z = normalFromHash(studentId, 'career', code) + SCALE_NOISE * normalFromHash(studentId, 'career', code, wave);
      return [code, clamp(Math.round(CAREER_MID + CAREER_SPREAD * z), 0, max)];
    }),
  );
}

type Ctx = { student: Student; cls: SchoolClass; wave: HistoryWave; waveIdx: number; lastWave: number; gradeThen: number };

function buildResult(ctx: Ctx, tpl: TemplateId): PsychResult | null {
  const spec = TEMPLATE_SPECS[tpl];
  if (!spec.grades.includes(ctx.gradeThen)) return null;
  const { student, cls, wave, waveIdx, lastWave } = ctx;
  const takenAt = takenAtOf(testDate(wave, cls.id), student.id, tpl);
  const ageBand = ageBandOf(ageOn(student.birthDate, takenAt.slice(0, 10)));
  const raw: Record<string, number> = {};
  if (spec.kind === 'CAREER') {
    Object.assign(raw, careerRaw(student.id, waveIdx, spec.ranges.R?.max ?? 6));
  } else {
    for (const scale of spec.scales) {
      const range = spec.ranges[scale.key];
      const norm = normFor(spec.norms, scale.key, ageBand);
      if (!range || !norm || !scale.domain) continue;
      const z = domainZ(scale, scale.domain, student.id, cls.id, waveIdx, lastWave, spec);
      raw[scale.key] = clamp(Math.round(norm.mean + norm.sd * z), range.min, range.max);
    }
  }
  const duration = spec.timeLimitMin * 60 * (0.45 + 0.45 * unitHash(student.id, wave.key, tpl, 'dur'));
  return {
    id: `ph-${waveIdx}-${tpl}-${student.id}`,
    studentId: student.id,
    classId: cls.id,
    grade: ctx.gradeThen,
    ageBand,
    testId: tpl,
    version: PSYCH_TEMPLATES[tpl].version,
    assignmentId: null,
    takenAt,
    origin: 'SEED',
    raw,
    durationSec: Math.round(duration),
  };
}

function compute(t: Pick<Tables, 'psychHistory' | 'students' | 'classes' | 'school'>): PsychResult[] {
  const { waves, seed } = t.psychHistory;
  const anchorYear = anchorYearOf(waves, t.school?.quarters?.[0]?.start ?? null);
  if (anchorYear === null || waves.length === 0) return [];
  const classes = new Map(t.classes.map((c) => [c.id, c]));
  const lastWave = waves.length - 1;
  const out: PsychResult[] = [];
  for (const student of t.students) {
    const cls = classes.get(student.classId);
    if (student.archived || !cls || cls.grade < HISTORY_MIN_GRADE) continue;
    waves.forEach((wave, waveIdx) => {
      if (student.enrolledAt > wave.date) return;
      if (unitHash(seed, student.id, wave.key, 'took') >= HISTORY_PARTICIPATION) return;
      const gradeThen = cls.grade - (anchorYear - academicYearOf(wave.date));
      const ctx: Ctx = { student, cls, wave, waveIdx, lastWave, gradeThen };
      for (const tpl of wave.testIds) {
        const result = buildResult(ctx, tpl);
        if (result) out.push(result);
      }
    });
  }
  return out;
}

/**
 * Tarix natijalari (memo: baseDate | to'lqinlar | o'quvchilar barmoq izi). Har `transact`
 * jadvallarni nusxalaydi, shuning uchun havola emas, mazmun bo'yicha keshlanadi.
 */
export function historyResults(t: Pick<Tables, 'psychHistory' | 'students' | 'classes' | 'school'>): PsychResult[] {
  if (!t.psychHistory?.waves?.length) return [];
  const byRef = byStudentsRef.get(t.students);
  if (byRef && memo === byRef) return byRef.results;
  const key = fingerprint(t);
  if (!memo || memo.key !== key) memo = { key, results: compute(t) };
  byStudentsRef.set(t.students, memo);
  return memo.results;
}

/** Faqat testlar uchun — memo holatini tozalash. */
export function __resetHistoryMemo(): void {
  memo = null;
}

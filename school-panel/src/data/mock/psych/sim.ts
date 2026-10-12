import type {
  AgeBand,
  DevDomain,
  IsoDate,
  PsychAssignment,
  PsychItem,
  PsychResult,
  PsychScale,
  PsychTest,
  SchoolClass,
  Student,
} from '@/data/contracts';
import { latent, normalFromHash } from '@/lib/psych/latent';
import { type AnswerVector, ageBandOf, ageOn, CAREER_ORDER, encodeAnswers, normFor, rawScores } from '@/lib/psych/scoring';
import { unitHash } from '@/lib/rng';
import { pushNotification } from '../notify';
import type { Tables } from '../tables';
import { findTest } from './catalog';

/**
 * Demo: o'quvchilar testni Parvoz ilovasida yechadi. Javoblar `latent()` modelidan —
 * xom ball ≈ me'yor o'rtachasi + sd · z (agent B tarixi bilan bir xil), shuning uchun
 * jonli natijalar o'tgan choraklar bilan mos keladi. Hammasi deterministik (xesh).
 */
export const PARTICIPATION = 0.85;
const DAY_START = 8 * 60 + 30;
const DAY_SPAN = 9 * 60;
/** Jonli tebranish va kuzatilgan SD — agent B tarixidagi `OBSERVED_SD` bilan bir xil. */
const LIVE_NOISE = 0.35;
const OBSERVED_SD = Math.hypot(1, LIVE_NOISE);
const SCALE_NOISE = 0.3;
/** "Eng osonidan" tartibidagi tebranish (savol pozitsiyasi birligida) — bir nechta almashinuv. */
const ORDER_NOISE = 1.2;
const LIKERT_SPREAD = 0.8;
const CAREER_MID = 3;
const CAREER_SPREAD = 1.6;
const SECONDS_PER_ITEM = 25;

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
const logistic = (x: number) => 1 / (1 + Math.exp(-x));
const pad = (n: number) => String(n).padStart(2, '0');

export function hhmm(minute: number): string {
  const m = clamp(Math.floor(minute), 0, 24 * 60 - 1);
  return `${pad(Math.floor(m / 60))}:${pad(m % 60)}`;
}

export const resultId = (assignmentId: string, studentId: string) => `pr-${assignmentId}-${studentId}`;

/** Sinf ID'sidan taxminiy yosh bandi (tug'ilgan sana berilmasa): 7-sinf → ~13 yosh. */
function guessBand(classId: string): AgeBand {
  const grade = Number(/(\d+)/.exec(classId)?.[1] ?? 7);
  return ageBandOf(grade + 6);
}

type SingleItem = Extract<PsychItem, { type: 'SINGLE' }>;
type LikertItem = Extract<PsychItem, { type: 'LIKERT' }>;
type Planned = Map<string, string | number | null>;
type Who = { studentId: string; classId: string; salt: string | number; band: AgeBand };

/** Shkala z darajasi: (latent + jonli tebranish) / kuzatilgan SD; xavotir kabi shkalalarda — teskari. */
function scaleZ(test: PsychTest, scale: PsychScale, fallback: DevDomain, who: Who): number {
  const domain = scale.domain ?? fallback;
  const base = (latent(who.studentId, domain, who.classId) + LIVE_NOISE * normalFromHash(who.studentId, domain, 'live', who.salt)) / OBSERVED_SD;
  const shared = scale.domain !== null && test.scales.filter((s) => s.domain === scale.domain).length > 1;
  const extra = shared && scale.polarity === 'HIGHER_BETTER' ? SCALE_NOISE * normalFromHash(who.studentId, scale.key, 'live', who.salt) : 0;
  return scale.polarity === 'HIGHER_CONCERN' ? -base : base + extra;
}

/** Maqsadli xom ball = clamp(round(o'rtacha + sd · z)); me'yor bo'lmasa — oraliq bo'yicha logistik. */
function scaleTarget(test: PsychTest, key: string, z: number, band: AgeBand, min: number, max: number): number {
  const norm = normFor(test.norms, key, band);
  const value = norm && norm.sd > 0 ? norm.mean + norm.sd * z : min + (max - min) * logistic(1.7 * z);
  return clamp(Math.round(value), min, max);
}

/** Aynan `target` ta to'g'ri javob: eng osonidan (tartib bo'yicha), xeshlangan kichik almashinuvlar bilan. */
function allocateSingles(items: readonly SingleItem[], target: number, who: Who, out: Planned): void {
  const order = items
    .map((item, rank) => ({ item, key: rank + ORDER_NOISE * normalFromHash(who.salt, who.studentId, item.id, 'order') }))
    .sort((a, b) => a.key - b.key);
  order.forEach(({ item }, i) => {
    if (i < target) {
      out.set(item.id, item.correct);
      return;
    }
    const wrong = item.options.filter((o) => o.key !== item.correct);
    out.set(item.id, wrong[Math.floor(unitHash(who.salt, who.studentId, item.id, 'wrong') * wrong.length)]?.key ?? null);
  });
}

/** Likert yig'indisi aynan `target`: o'rtacha atrofida tebranib, keyin aniq tenglashtiriladi. */
function allocateLikert(items: readonly LikertItem[], target: number, who: Who, out: Planned): void {
  if (items.length === 0) return;
  const mean = target / items.length;
  const desired = items.map((item) => mean + LIKERT_SPREAD * normalFromHash(who.salt, who.studentId, item.id, 'likert'));
  const values = desired.map((d) => clamp(Math.round(d), 1, 5));
  let sum = values.reduce((a, b) => a + b, 0);
  for (let guard = 0; sum !== target && guard < items.length * 5; guard++) {
    const up = sum < target;
    let pick = -1;
    values.forEach((v, i) => {
      if (up ? v >= 5 : v <= 1) return;
      const gap = (desired[i] ?? 0) - v;
      const best = pick < 0 ? null : (desired[pick] ?? 0) - (values[pick] ?? 0);
      if (best === null || (up ? gap > best : gap < best)) pick = i;
    });
    if (pick < 0) break;
    values[pick] = (values[pick] ?? 3) + (up ? 1 : -1);
    sum += up ? 1 : -1;
  }
  items.forEach((item, i) => {
    const v = values[i] ?? 3;
    out.set(item.id, item.reverse ? 6 - v : v);
  });
}

function planScale(test: PsychTest, scale: PsychScale, who: Who, out: Planned): void {
  const singles = test.items.filter((i): i is SingleItem => i.type === 'SINGLE' && i.scale === scale.key);
  const likerts = test.items.filter((i): i is LikertItem => i.type === 'LIKERT' && i.scale === scale.key);
  if (singles.length + likerts.length === 0) return;
  const min = likerts.length;
  const max = singles.length + 5 * likerts.length;
  const z = scaleZ(test, scale, singles.length ? 'REASONING' : 'EMOTIONAL', who);
  const target = scaleTarget(test, scale.key, z, who.band, min, max);
  const share = max > min ? (target - min) / (max - min) : 0;
  const singleTarget = clamp(Math.round(share * singles.length), 0, singles.length);
  allocateSingles(singles, singleTarget, who, out);
  allocateLikert(likerts, clamp(target - singleTarget, likerts.length, 5 * likerts.length), who, out);
}

/** Kasbiy qiziqish profili — tarix bilan bir xil (`normalFromHash(o'quvchi, 'career', kod)`). */
function interestChance(test: PsychTest, scaleKey: string, studentId: string): number {
  const count = test.items.reduce((n, it) => n + (it.type === 'MULTI' ? it.options.filter((o) => o.scale === scaleKey).length : 0), 0);
  if ((CAREER_ORDER as readonly string[]).includes(scaleKey)) {
    const z = normalFromHash(studentId, 'career', scaleKey);
    const expected = clamp(CAREER_MID + CAREER_SPREAD * z, 0, count);
    return clamp(expected / Math.max(1, count), 0.03, 0.97);
  }
  return logistic(1.2 * normalFromHash(studentId, 'interest', scaleKey) - 0.3);
}

/**
 * Bitta o'quvchining deterministik javoblari (Parvoz ilovasidagi demo). Har shkala uchun
 * maqsadli xom ball agent B tarixi bilan bir xil formulada; SINGLE — aynan shuncha to'g'ri
 * javob (osonidan), LIKERT — yig'indi aynan maqsadga teng (teskari savollar hisobga olinadi),
 * MULTI — qiziqish profili bo'yicha.
 */
export function simulateAnswers(
  test: PsychTest,
  studentId: string,
  classId: string,
  takenAt: string,
  salt: string | number,
  opts: { birthDate?: IsoDate } = {},
): AnswerVector {
  const band = opts.birthDate ? ageBandOf(ageOn(opts.birthDate, takenAt.slice(0, 10))) : guessBand(classId);
  const who: Who = { studentId, classId, salt, band };
  const planned: Planned = new Map();
  for (const scale of test.scales) planScale(test, scale, who, planned);
  return test.items.map((item) => {
    if (item.type !== 'MULTI') return planned.get(item.id) ?? null;
    return item.options.flatMap((o, idx) => (unitHash(salt, studentId, item.id, o.key) < interestChance(test, o.scale, studentId) ? [idx] : []));
  });
}

/** Ilovada yechilgan natija (javoblar kodlangan, faqat xom ball saqlanadi). */
export function buildAppResult(
  test: PsychTest,
  student: Pick<Student, 'id' | 'birthDate'>,
  cls: Pick<SchoolClass, 'id' | 'grade'>,
  assignment: Pick<PsychAssignment, 'id' | 'testVersion'>,
  takenAt: string,
  salt: string | number,
): PsychResult {
  const answers = simulateAnswers(test, student.id, cls.id, takenAt, salt, { birthDate: student.birthDate });
  const limitSec = (test.timeLimitMin ?? Math.ceil((test.items.length * SECONDS_PER_ITEM) / 60)) * 60;
  return {
    id: resultId(assignment.id, student.id),
    studentId: student.id,
    classId: cls.id,
    grade: cls.grade,
    ageBand: ageBandOf(ageOn(student.birthDate, takenAt.slice(0, 10))),
    testId: test.id,
    version: assignment.testVersion,
    assignmentId: assignment.id,
    takenAt,
    origin: 'APP',
    raw: rawScores(test, answers),
    answers: encodeAnswers(test, answers),
    durationSec: Math.round(limitSec * (0.4 + 0.5 * unitHash(assignment.id, student.id, 'duration'))),
  };
}

/** Tayinlangan sinflardagi faol o'quvchilar (sinf bilan). */
export function targetStudents(t: Pick<Tables, 'students' | 'classes'>, a: Pick<PsychAssignment, 'classIds'>): Array<{ student: Student; cls: SchoolClass }> {
  const classes = new Map(t.classes.filter((c) => a.classIds.includes(c.id)).map((c) => [c.id, c]));
  return t.students.flatMap((student) => {
    const cls = classes.get(student.classId);
    return cls && !student.archived ? [{ student, cls }] : [];
  });
}

/** O'quvchi bu tayinlashda qatnashadimi (~85%) va qaysi daqiqada (maktab kuni ichida). */
export const takeChance = (assignmentId: string, studentId: string) => unitHash(assignmentId, studentId, 'take');
export const completionMinute = (assignmentId: string, studentId: string) => DAY_START + Math.floor(unitHash(assignmentId, studentId, 'minute') * DAY_SPAN);

/** "N ta o'quvchi testni yakunladi" — har tayinlash uchun kuniga bitta (yangilanadi). */
export function upsertTestCompleted(t: Tables, a: Pick<PsychAssignment, 'id' | 'testId'>, test: Pick<PsychTest, 'title'>, date: IsoDate, at: string): void {
  const count = (t.psychResults ?? []).filter((r) => r.assignmentId === a.id && r.takenAt.startsWith(date)).length;
  if (count === 0) return;
  pushNotification(t, {
    id: `ntf-test-${a.id}-${date}`,
    kind: 'TEST_COMPLETED',
    at,
    roles: ['PSYCHOLOGIST'],
    classIds: null,
    params: { count },
    subject: test.title,
    href: `/assessments?tab=results&test=${a.testId}`,
  });
}

function tickAssignment(t: Tables, a: PsychAssignment, date: IsoDate, minute: number, done: ReadonlySet<string>): PsychResult[] {
  const test = findTest(t, a.testId);
  if (!test || test.items.length === 0) return [];
  const opens = Date.parse(a.opensAt);
  const closes = Date.parse(a.closesAt);
  const fresh: PsychResult[] = [];
  for (const { student, cls } of targetStudents(t, a)) {
    const id = resultId(a.id, student.id);
    if (done.has(id) || takeChance(a.id, student.id) >= PARTICIPATION) continue;
    const m = completionMinute(a.id, student.id);
    if (m > minute) continue;
    const takenAt = `${date}T${hhmm(m)}:00`;
    const at = Date.parse(takenAt);
    if (at < opens || at > closes) continue;
    fresh.push(buildAppResult(test, student, cls, a, takenAt, a.id));
  }
  if (fresh.length) {
    t.psychResults = [...(t.psychResults ?? []), ...fresh];
    upsertTestCompleted(t, a, test, date, `${date}T${hhmm(minute)}:00`);
  }
  return fresh;
}

function tick(t: Tables, date: IsoDate, minute: number): number {
  const nowMs = Date.parse(`${date}T${hhmm(minute)}:00`);
  const dayStart = Date.parse(`${date}T00:00:00`);
  const open = (t.psychAssignments ?? []).filter((a) => a.status === 'OPEN' && Date.parse(a.opensAt) <= nowMs && Date.parse(a.closesAt) >= dayStart);
  if (open.length === 0) return 0;
  const done = new Set((t.psychResults ?? []).map((r) => r.id));
  return open.reduce((sum, a) => sum + tickAssignment(t, a, date, minute, done).length, 0);
}

/**
 * Demo dvigateli har daqiqada chaqiradi (DemoEngine `transact` ichida). Idempotent:
 * natija ID'si `pr-<tayinlash>-<o'quvchi>`; kichikroq daqiqa bilan chaqirilsa hech narsa qo'shmaydi.
 * Hech qachon xato tashlamaydi — yangi natijalar sonini qaytaradi.
 */
export function tickPsychAssignments(tables: Tables, date: IsoDate, minute: number): number {
  try {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(minute)) return 0;
    return tick(tables, date, minute);
  } catch {
    return 0;
  }
}

import type {
  AttentionRow,
  ClassDevOverview,
  ClassDevRow,
  DevDomain,
  IsoDate,
  SchoolClass,
  SchoolDevOverview,
  ScoredResult,
  Student,
  StudentDevProfile,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { roleHas } from '@/auth/permissions';
import { CARE_MIN_GROUP as K, maskSmallCount } from '@/lib/k-anon';
import { ageBandOf, ageOn } from '@/lib/psych/scoring';
import { termOf } from '@/lib/psych/terms';
import { sharePercent } from '@/lib/utils';
import { addDays, isSchoolDay, toIsoDate } from '../calendar';
import { clockToday } from '../clock';
import { type Actor, assertCan, assertClassInScope, currentActor, latency } from '../context';
import { getTables } from '../db';
import { compareClasses, studentName } from '../lookups';
import { HISTORY_MIN_GRADE } from '../psych/history';
import type { Tables } from '../tables';
import { attendedRate, type DayCounts, resolveRecord } from './attendance';
import {
  computeSchoolOverview,
  defaultSchoolTerm,
  DEV_DOMAINS,
  devIndex,
  type DevIndex,
  type DomainMap,
  type Entry,
  schoolDomainValues,
  termEnd,
} from './development-aggregate';
import { computeAttention } from './development-attention';
import { lastClosedWeek, learningTotals } from './learning';

/**
 * Rivojlanish servisi.
 * - `studentProfile`, `classOverview` — `development.individual` (psixolog: butun maktab;
 *   sinf rahbari: faqat o'z sinfi, javoblarsiz va xom ballarsiz, hissiy holat — faqat daraja, o'rtachasiz).
 * - `schoolOverview`, `termOptions` — `development.view`; direktor/admin uchun k-anonim yashirish.
 * - `attentionList` — `assessments.manage` (faqat psixolog).
 */
const TERM_KEY = /^\d{4}-\d{2}:Q[1-4]$/;
const ATTENDANCE_DAYS = 30;
const MAX_LOOKBACK_DAYS = 90;

/** Psixolog (testlarni boshqaradi) — to'liq ma'lumot; qolganlar — himoyalangan ko'rinish. */
const canSeeRaw = (actor: Actor) => roleHas(actor.role, 'assessments.manage');
const isSchoolWide = (actor: Actor) => actor.scope === 'SCHOOL';

function parseTerm(termKey: string | undefined, idx: DevIndex): string | undefined {
  if (termKey === undefined) return undefined;
  if (!TERM_KEY.test(termKey) || !idx.terms.includes(termKey)) throw new ServiceError('VALIDATION', `term ${termKey}`);
  return termKey;
}

function findStudent(t: Tables, id: string): Student {
  const student = t.students.find((s) => s.id === id);
  if (!student) throw new ServiceError('NOT_FOUND', id);
  return student;
}

function findClass(t: Tables, id: string): SchoolClass {
  const cls = t.classes.find((c) => c.id === id);
  if (!cls) throw new ServiceError('NOT_FOUND', id);
  return cls;
}

function latestOf(entries: readonly Entry[]): DomainMap {
  return entries.reduce<DomainMap>((acc, e) => ({ ...acc, ...e.domains }), {});
}

/**
 * Sinf o'rtachalari sohalari: hissiy holat — faqat psixologga (backend bilan bir xil). Aks holda sinf
 * rahbari sinf o'rtachasidan sinfdoshlar o'rtachasini ayirib, o'quvchining yashirin hissiy indeksini topardi.
 */
const averageDomains = (full: boolean): readonly DevDomain[] => (full ? DEV_DOMAINS : DEV_DOMAINS.filter((d) => d !== 'EMOTIONAL'));

/** Sinfdoshlar o'rtachasi (o'quvchining o'zisiz), faqat n ≥ K bo'lgan sohalar; psixologdan boshqaga — hissiy holatsiz. */
function classmatesAverage(t: Tables, idx: DevIndex, student: Student, full: boolean): StudentDevProfile['classAverage'] {
  const mates = t.students.filter((s) => !s.archived && s.classId === student.classId && s.id !== student.id);
  const latest = mates.map((s) => latestOf(idx.byStudent.get(s.id) ?? []));
  const out: StudentDevProfile['classAverage'] = {};
  for (const d of averageDomains(full)) {
    const xs = latest.map((m) => m[d]?.index).filter((x): x is number => typeof x === 'number');
    if (xs.length >= K) out[d] = Math.round(xs.reduce((a, b) => a + b, 0) / xs.length);
  }
  return out;
}

function timeline(entries: readonly Entry[], full: boolean): StudentDevProfile['timeline'] {
  const terms = [...new Set(entries.map((e) => e.termKey))].sort();
  return terms.map((termKey) => {
    const inTerm = entries.filter((e) => e.termKey === termKey);
    const domains = latestOf(inTerm);
    const values: Partial<Record<DevDomain, number>> = {};
    for (const d of DEV_DOMAINS) {
      const v = domains[d]?.index;
      if (typeof v === 'number' && (full || d !== 'EMOTIONAL')) values[d] = v;
    }
    const last = inTerm.at(-1);
    return { termKey, date: last ? toIsoDate(new Date(last.at)) : termEnd(termKey), values };
  });
}

/** Sinf rahbari: javoblar va xom ballar yo'q; hissiy holat shkalalarida faqat daraja. */
function protectResult(entry: Entry, idx: DevIndex): ScoredResult {
  const { answers: _answers, ...rest } = entry.result;
  void _answers;
  const test = idx.tests.get(entry.result.testId);
  const emotional = new Set(test?.scales.filter((s) => s.domain === 'EMOTIONAL').map((s) => s.key) ?? []);
  return {
    ...rest,
    raw: {},
    scales: entry.result.scales.map((s) =>
      emotional.has(s.key) ? { ...s, raw: 0, max: null, z: null, standard: null, percentile: null } : { ...s, raw: 0, max: null },
    ),
  };
}

function careerOf(entries: readonly Entry[]): StudentDevProfile['career'] {
  const last = [...entries].reverse().find((e) => e.result.topCodes);
  return last?.result.topCodes ? { topCodes: last.result.topCodes, raw: { ...last.result.raw }, takenAt: last.result.takenAt } : null;
}

/** Oxirgi 30 o'quv kuni (bugundan oldin) bo'yicha o'quvchi davomati. */
function attendance30(t: Tables, student: Student, today: IsoDate): StudentDevProfile['context']['attendance30'] {
  const cls = t.classes.find((c) => c.id === student.classId);
  const shift = cls ? t.shifts.find((s) => s.id === cls.shiftId) : undefined;
  if (!shift) return { rate: null, late: 0, absent: 0 };
  const stored = new Map(t.attendance.filter((r) => r.studentId === student.id).map((r) => [r.date, r]));
  let counts: DayCounts = { present: 0, late: 0, absent: 0, leftEarly: 0, excused: 0, pending: 0, total: 0 };
  let days = 0;
  for (let back = 1; back <= MAX_LOOKBACK_DAYS && days < ATTENDANCE_DAYS; back++) {
    const d = addDays(today, -back);
    if (d < student.enrolledAt) break;
    if (!isSchoolDay(d, shift, t.holidays)) continue;
    days += 1;
    const status = resolveRecord(t, student, d, today, stored.get(d))?.status ?? null;
    counts = {
      ...counts,
      total: counts.total + 1,
      pending: counts.pending + (status === null ? 1 : 0),
      present: counts.present + (status === 'PRESENT' ? 1 : 0),
      late: counts.late + (status === 'LATE' ? 1 : 0),
      absent: counts.absent + (status === 'ABSENT' ? 1 : 0),
      leftEarly: counts.leftEarly + (status === 'LEFT_EARLY' ? 1 : 0),
      excused: counts.excused + (status === 'EXCUSED' ? 1 : 0),
    };
  }
  const decided = counts.total - counts.pending;
  return { rate: decided > 0 ? attendedRate(counts) : null, late: counts.late, absent: counts.absent };
}

/**
 * Sinfning Growth Learning faolligi — oxirgi YOPIQ hafta (joriy hafta natijasi ko'rsatilmaydi, backend
 * bilan bir xil); ball K=5 qoidasi bilan (`learningTotals`).
 */
function classLearning(t: Tables, classId: string, today: IsoDate): StudentDevProfile['context']['classLearning'] {
  const week = lastClosedWeek(today);
  const cell = t.activity.find((a) => a.classId === classId && a.weekStart === week);
  if (!cell) return null;
  const size = t.students.filter((s) => !s.archived && s.classId === classId).length;
  const { avgScore, suppressed } = learningTotals([cell]);
  return { activeRate: sharePercent(cell.activeStudents, size), avgScore, suppressed };
}

export function buildProfile(t: Tables, actor: Actor, student: Student, today: IsoDate): StudentDevProfile {
  const idx = devIndex(t);
  const full = canSeeRaw(actor);
  const cls = t.classes.find((c) => c.id === student.classId);
  const entries = idx.byStudent.get(student.id) ?? [];
  const latest = DEV_DOMAINS.map((domain) => {
    const last = [...entries].reverse().find((e) => e.domains[domain]);
    const value = last?.domains[domain];
    return {
      domain,
      index: value && (full || domain !== 'EMOTIONAL') ? value.index : null,
      band: value?.band ?? null,
      takenAt: last?.result.takenAt ?? null,
    };
  });
  return {
    student: { id: student.id, name: studentName(student), className: cls?.name ?? '—', grade: cls?.grade ?? 0, ageBand: ageBandOf(ageOn(student.birthDate, today)) },
    latest,
    classAverage: classmatesAverage(t, idx, student, full),
    timeline: timeline(entries, full),
    career: careerOf(entries),
    results: [...entries].reverse().map((e) => ({ ...(full ? e.result : protectResult(e, idx)), testTitle: e.testTitle })),
    context: {
      attendance30: actor.role === 'HOMEROOM' ? attendance30(t, student, today) : null,
      classLearning: classLearning(t, student.classId, today),
    },
    canSeeRaw: full,
  };
}

function classTerm(t: Tables, idx: DevIndex, classId: string, today: IsoDate): string {
  const ids = new Set(t.students.filter((s) => s.classId === classId).map((s) => s.id));
  const terms = idx.terms.filter((term) => [...(idx.snapshot.get(term)?.keys() ?? [])].some((id) => ids.has(id)));
  return terms.at(-1) ?? idx.terms.at(-1) ?? termOf(today).key;
}

export function buildClassOverview(t: Tables, actor: Actor, cls: SchoolClass, termKey: string | undefined, today: IsoDate): ClassDevOverview {
  const idx = devIndex(t);
  const full = canSeeRaw(actor);
  const term = termKey ?? classTerm(t, idx, cls.id, today);
  const snap = idx.snapshot.get(term);
  const flagged = full ? new Set(computeAttention(t, idx).map((r) => r.studentId)) : new Set<string>();
  const rows: ClassDevRow[] = t.students
    .filter((s) => !s.archived && s.classId === cls.id)
    .sort((a, b) => studentName(a).localeCompare(studentName(b), 'uz'))
    .map((s) => {
      const st = snap?.get(s.id);
      const domains: ClassDevRow['domains'] = {};
      for (const d of DEV_DOMAINS) {
        const v = st?.domains[d];
        if (v) domains[d] = { index: full || d !== 'EMOTIONAL' ? v.index : null, band: v.band };
      }
      return { studentId: s.id, name: studentName(s), assessedAt: st?.lastTakenAt ?? null, domains, attention: flagged.has(s.id) };
    });
  // Psixologdan boshqaga hissiy holat o'rtachasi yo'q (index null) — `averageDomains`.
  const shown = new Set(averageDomains(full));
  const domainAverages = DEV_DOMAINS.map((domain) => {
    if (!shown.has(domain)) return { domain, index: null };
    const xs = rows.map((r) => snap?.get(r.studentId)?.domains[domain]?.index).filter((x): x is number => typeof x === 'number');
    return { domain, index: xs.length >= K ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null };
  });
  const schoolAverages: ClassDevOverview['schoolAverages'] = {};
  for (const v of schoolDomainValues(t, idx, term, today)) if (v.index !== null) schoolAverages[v.domain] = v.index;
  return {
    classId: cls.id,
    className: cls.name,
    termKey: term,
    assessed: rows.filter((r) => r.assessedAt).length,
    total: rows.length,
    domainAverages,
    schoolAverages,
    rows,
  };
}

function emptySchoolOverview(termKey: string, suppress: boolean): SchoolDevOverview {
  return {
    termKey,
    suppressed: suppress,
    participation: { assessed: 0, eligible: 0, rate: 0 },
    domainAverages: DEV_DOMAINS.map((domain) => ({ domain, index: null, n: 0 })),
    cognitiveByGrade: [],
    cognitiveCoarse: null,
    trend: [],
    heat: [],
    attentionCount: null,
  };
}

export function buildSchoolOverview(t: Tables, actor: Actor, termKey: string | undefined, today: IsoDate): SchoolDevOverview {
  const idx = devIndex(t);
  const suppress = !canSeeRaw(actor);
  const term = termKey ?? defaultSchoolTerm(t, idx, today);
  if (!term) return emptySchoolOverview(termOf(today).key, suppress);
  const attention = computeAttention(t, idx).length;
  return computeSchoolOverview(t, idx, term, { suppress, today, attentionCount: suppress ? maskSmallCount(attention) : String(attention) });
}

function termCounts(t: Tables, idx: DevIndex, actor: Actor): Array<{ key: string; n: number }> {
  const allowed = isSchoolWide(actor) ? null : new Set(actor.classIds);
  return idx.terms
    .map((key) => ({ key, n: [...(idx.snapshot.get(key)?.values() ?? [])].filter((st) => !allowed || allowed.has(st.classId)).length }))
    .filter((x) => x.n > 0 && (canSeeRaw(actor) || !isSchoolWide(actor) || x.n >= K))
    .reverse();
}

export const developmentService = {
  async studentProfile(studentId: string): Promise<StudentDevProfile> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'development.individual');
    const t = getTables();
    const student = findStudent(t, studentId);
    assertClassInScope(actor, student.classId);
    return buildProfile(t, actor, student, clockToday());
  },

  async classOverview(classId: string, termKey?: string): Promise<ClassDevOverview> {
    await latency(80, 180);
    const actor = currentActor();
    assertCan(actor, 'development.individual');
    const t = getTables();
    const cls = findClass(t, classId);
    assertClassInScope(actor, cls.id);
    return buildClassOverview(t, actor, cls, parseTerm(termKey, devIndex(t)), clockToday());
  },

  async schoolOverview(q: { termKey?: string } = {}): Promise<SchoolDevOverview> {
    await latency(100, 220);
    const actor = currentActor();
    assertCan(actor, 'development.view');
    if (!isSchoolWide(actor)) throw new ServiceError('FORBIDDEN', 'development.school');
    const t = getTables();
    return buildSchoolOverview(t, actor, parseTerm(q.termKey, devIndex(t)), clockToday());
  },

  async attentionList(): Promise<AttentionRow[]> {
    await latency(80, 160);
    const actor = currentActor();
    assertCan(actor, 'assessments.manage');
    const t = getTables();
    return computeAttention(t, devIndex(t));
  },

  /** Profil va sinf ko'rinishi uchun doiradagi sinflar (psixolog — 3-sinfdan; sinf rahbari — o'z sinfi). */
  async classOptions(): Promise<Array<{ id: string; name: string; grade: number }>> {
    await latency(20, 60);
    const actor = currentActor();
    assertCan(actor, 'development.individual');
    const allowed = isSchoolWide(actor) ? null : new Set(actor.classIds);
    return [...getTables().classes]
      .filter((c) => (allowed ? allowed.has(c.id) : c.grade >= HISTORY_MIN_GRADE))
      .sort(compareClasses)
      .map((c) => ({ id: c.id, name: c.name, grade: c.grade }));
  },

  async termOptions(): Promise<Array<{ key: string; n: number }>> {
    await latency(30, 80);
    const actor = currentActor();
    assertCan(actor, 'development.view');
    const t = getTables();
    return termCounts(t, devIndex(t), actor);
  },
};

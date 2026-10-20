// Rivojlanish (sof qatlam): e'lon qilingan natijalar, natijadagi sinf / daraja nusxasi
// bo'yicha guruhlash, direktor kesimida ayirish hujumi (panel `development-anonymity.test.ts`
// usuli) va e'tibor ro'yxati qoidalari.

import { isAssignmentFinal } from '../assessments/assessments-view';
import { termOf } from '../assessments/psych/terms';
import { PSYCH_TEMPLATES } from '../assessments/psych/templates';
import type { DevDomain, TemplateId } from '../assessments/psych/types';
import { scoreStoredResult, ScoredResult } from '../assessments/results-view';
import { computeSchoolOverview } from './development-aggregate';
import { computeAttention } from './development-attention';
import { cellsOf, domainN, K, sumOf } from './development-cells';
import { buildIndex, DEV_DOMAINS, DevIndex, localDay } from './development-index';
import { releasedResults } from './development-release';
import type { LiveClass, LiveStudent, Roster, SchoolDevOverview } from './development.types';

const TODAY = '2026-10-12';
const NOW_DAY = '2026-10-05';
const PREV_DAY = '2026-04-15';
type School = Roster & { results: ScoredResult[] };

function result(studentId: string, classId: string | null, grade: number, testId: TemplateId, raw: Record<string, number>, day: string, opts: { assignmentId?: string | null; createdAt?: string } = {}): ScoredResult {
  const at = new Date(`${day}T04:00:00.000Z`);
  return scoreStoredResult(PSYCH_TEMPLATES[testId], {
    id: `${studentId}-${testId}-${day}`,
    studentId,
    classId,
    grade,
    ageBand: 'A13_14',
    testId,
    version: 1,
    assignmentId: opts.assignmentId === undefined ? `a-${testId}-${day}` : opts.assignmentId,
    takenAt: at,
    origin: opts.assignmentId === null ? 'IMPORT' : 'APP',
    raw,
    durationSec: 300,
    createdAt: new Date(opts.createdAt ?? at.toISOString()),
  });
}

/** Har sinfda `size` o'quvchi; har biri ikki chorakda mantiq + diqqat + hissiy holat testini yechgan. */
function school(sizes: Record<string, number>): School {
  const classes: LiveClass[] = Object.keys(sizes).map((name) => ({ id: `cls-${name}`, name, grade: Number(name.split('-')[0]), letter: name.split('-')[1] ?? 'A' }));
  const students: LiveStudent[] = classes.flatMap((c) =>
    Array.from({ length: sizes[c.name] ?? 0 }, (_, i) => ({ id: `stu-${c.name}-${i}`, classId: c.id, lastName: `Fam${c.name}`, firstName: `Ism${i}`, archived: false, enrolledAt: '2025-09-02', birthDate: '2013-05-14' })),
  );
  const results = students.flatMap((s, i) => {
    const cls = classes.find((c) => c.id === s.classId) as LiveClass;
    return [PREV_DAY, NOW_DAY].flatMap((day, wave) => [
      result(s.id, cls.id, cls.grade - (wave === 0 ? 1 : 0), 'tpl-logic', { total: 4 + ((i * 7 + wave * 3) % 12) }, day),
      result(s.id, cls.id, cls.grade - (wave === 0 ? 1 : 0), 'tpl-attention', { attention: 2 + ((i * 3) % 6), memory: 1 + ((i * 5 + wave) % 7) }, day),
      result(s.id, cls.id, cls.grade - (wave === 0 ? 1 : 0), 'tpl-emotion', { worry: 9 + ((i * 11) % 24), mood: 8 + ((i * 7) % 16) }, day),
    ]);
  });
  return { classes, students, results };
}

const TESTS = new Map(Object.values(PSYCH_TEMPLATES).map((t) => [t.id, t]));
const indexOf = (results: readonly ScoredResult[]): DevIndex => buildIndex([...results].sort((a, b) => Date.parse(a.takenAt) - Date.parse(b.takenAt)), TESTS);
const termOfResult = (r: ScoredResult) => termOf(localDay(r.takenAt)).key;
const director = (idx: DevIndex, roster: Roster, term: string) => computeSchoolOverview(idx, roster, term, { suppress: true, today: TODAY, attentionCount: null });

const BASE: Record<string, number> = Object.fromEntries(
  ['3-A', '3-B', '4-A', '4-B', '5-A', '5-B', '6-A', '6-B', '7-A', '7-B', '8-A', '8-B', '9-A', '10-A', '11-A', '11-B'].map((n) => [n, 8]),
);

// ── Ayirish hujumi tekshiruvi (oq quti) ───────────────────────────────
type Stat = 'ANY' | DevDomain;
type Published = { kind: string; cells: Set<string> };

function trueCount(idx: DevIndex, term: string, ids: ReadonlySet<string>, stat: Stat): number {
  const cells = cellsOf(idx.snapshot.get(term)).filter((c) => ids.has(c.id));
  return stat === 'ANY' ? sumOf(cells, (c) => c.any) : sumOf(cells, (c) => domainN(c, stat));
}

function publishedSets(o: SchoolDevOverview, idx: DevIndex, stat: Stat): Published[] {
  const cells = cellsOf(idx.snapshot.get(o.termKey));
  const all = new Set(cells.map((c) => c.id));
  const ofClass = (classId: string) => new Set(cells.filter((c) => c.classId === classId).map((c) => c.id));
  const out: Published[] = [];
  if (stat === 'ANY') {
    if (o.participation.assessed > 0) out.push({ kind: 'school', cells: all });
    for (const h of o.heat) if (!h.hidden && h.n > 0) out.push({ kind: 'class', cells: ofClass(h.classId) });
    return out;
  }
  if (o.domainAverages.find((d) => d.domain === stat)?.index != null) out.push({ kind: 'school', cells: all });
  if (o.trend.find((x) => x.termKey === o.termKey)?.values[stat] !== undefined) out.push({ kind: 'trend', cells: all });
  if (stat === 'REASONING') {
    for (const g of o.cognitiveByGrade) if (!g.hidden) out.push({ kind: 'grade', cells: new Set(cells.filter((c) => c.grade === g.grade).map((c) => c.id)) });
  }
  for (const h of o.heat) if (h.cells[stat] != null) out.push({ kind: 'class', cells: ofClass(h.classId) });
  return out;
}

const isSubset = (a: ReadonlySet<string>, b: ReadonlySet<string>) => [...a].every((x) => b.has(x));

function assertSafe(o: SchoolDevOverview, idx: DevIndex, stat: Stat): void {
  const sets = publishedSets(o, idx, stat);
  for (const x of sets) {
    for (const kind of new Set(sets.map((s) => s.kind))) {
      const inside = sets.filter((s) => s.kind === kind && s !== x && isSubset(s.cells, x.cells));
      const residual = new Set([...x.cells].filter((id) => !inside.some((s) => s.cells.has(id))));
      const n = trueCount(idx, o.termKey, residual, stat);
      expect({ term: o.termKey, stat, pair: `${x.kind}-${kind}`, ok: n === 0 || n >= K }).toMatchObject({ ok: true });
    }
  }
  const signatures = new Map<string, Set<string>>();
  for (const c of cellsOf(idx.snapshot.get(o.termKey))) {
    const sig = sets.map((s) => (s.cells.has(c.id) ? '1' : '0')).join('');
    if (sig.includes('1')) signatures.set(sig, new Set([...(signatures.get(sig) ?? []), c.id]));
  }
  for (const piece of signatures.values()) {
    const n = trueCount(idx, o.termKey, piece, stat);
    expect({ term: o.termKey, stat, piece: [...piece].join(','), ok: n === 0 || n >= K }).toMatchObject({ ok: true });
  }
}

describe('development — e\'lon qilingan natijalar', () => {
  it('yakuniy tayinlash: yopilgan yoki muddati + qo\'shimcha vaqt o\'tgan', () => {
    const closesAt = new Date('2026-10-10T13:00:00Z');
    const now = closesAt.getTime();
    expect(isAssignmentFinal({ status: 'CLOSED', closesAt }, undefined, now - 86_400_000)).toBe(true);
    expect(isAssignmentFinal({ status: 'OPEN', closesAt }, { timeLimitMin: 20 }, now + 19 * 60_000)).toBe(false);
    expect(isAssignmentFinal({ status: 'OPEN', closesAt }, { timeLimitMin: 20 }, now + 21 * 60_000)).toBe(true);
    expect(isAssignmentFinal({ status: 'OPEN', closesAt }, { timeLimitMin: null }, now + 29 * 60_000)).toBe(false);
  });

  it('ochiq tayinlash yashiriladi; har (partiya, chorak, sinf) bo\'lagi < K — yashiriladi', () => {
    const rs = [
      ...[0, 1, 2, 3, 4].map((i) => result(`s${i}`, 'c1', 7, 'tpl-logic', { total: 8 }, NOW_DAY, { assignmentId: 'closed' })),
      ...[5, 6].map((i) => result(`s${i}`, 'c2', 7, 'tpl-logic', { total: 8 }, NOW_DAY, { assignmentId: 'closed' })),
      ...[0, 1, 2, 3, 4, 5].map((i) => result(`s${i}`, 'c1', 7, 'tpl-attention', { attention: 3, memory: 3 }, NOW_DAY, { assignmentId: 'open' })),
    ];
    const released = releasedResults(rs, new Set(['closed']), termOfResult);
    expect(released.map((r) => r.studentId).sort()).toEqual(['s0', 's1', 's2', 's3', 's4']);
  });

  it('CSV import: bitta import + bitta test = partiya', () => {
    const at = '2026-10-01T07:00:00.000Z';
    const rs = [
      ...[0, 1, 2, 3, 4].map((i) => result(`s${i}`, 'c1', 7, 'tpl-logic', { total: 8 }, NOW_DAY, { assignmentId: null, createdAt: at })),
      result('s5', 'c1', 7, 'tpl-attention', { attention: 3, memory: 3 }, NOW_DAY, { assignmentId: null, createdAt: at }),
      result('s6', 'c1', 7, 'tpl-logic', { total: 8 }, NOW_DAY, { assignmentId: null, createdAt: '2026-10-02T07:00:00.000Z' }),
    ];
    expect(releasedResults(rs, new Set(), termOfResult).map((r) => r.studentId).sort()).toEqual(['s0', 's1', 's2', 's3', 's4']);
  });
});

describe('development — natijadagi sinf / daraja nusxasi bo\'yicha guruhlash', () => {
  const s = school(BASE);
  const idx = indexOf(s.results);
  const term = termOf(NOW_DAY).key;

  it('sinf darajasini tahrirlash direktor kesimini o\'zgartirmaydi', () => {
    const before = director(idx, s, term);
    const edited = { ...s, classes: s.classes.map((c) => (c.id === 'cls-7-A' ? { ...c, grade: 9 } : c)) };
    expect(director(idx, edited, term)).toEqual(before);
  });

  it('sinfni o\'chirish natijalarni guruhlardan chiqarmaydi (qator yo\'qoladi, yig\'indilar o\'sha)', () => {
    const before = director(idx, s, term);
    const deleted = { classes: s.classes.filter((c) => c.id !== 'cls-7-B'), students: s.students.map((x) => (x.classId === 'cls-7-B' ? { ...x, classId: null } : x)) };
    const after = director(idx, deleted, term);
    expect(after.heat.find((h) => h.classId === 'cls-7-B')).toBeUndefined();
    expect([after.domainAverages, after.trend, after.cognitiveByGrade, after.cognitiveCoarse, after.participation.assessed]).toEqual([
      before.domainAverages,
      before.trend,
      before.cognitiveByGrade,
      before.cognitiveCoarse,
      before.participation.assessed,
    ]);
  });

  it('psixolog: yashirishsiz, parallel darajalari bor', () => {
    const o = computeSchoolOverview(idx, s, term, { suppress: false, today: TODAY, attentionCount: '0' });
    expect(o.suppressed).toBe(false);
    expect(o.cognitiveByGrade.every((g) => g.bands !== null && !g.hidden)).toBe(true);
    expect(o.trend.map((x) => x.termKey)).toEqual(idx.terms);
  });
});

const SCENARIOS: Array<[string, Record<string, number>]> = [
  ['standart', {}],
  ['7-A → 3', { '7-A': 3 }],
  ['8-B → 2', { '8-B': 2 }],
  ['butun parallel kichik (5-A → 2, 5-B → 1)', { '5-A': 2, '5-B': 1 }],
  ['turli parallellarda kichik sinflar', { '4-A': 1, '6-B': 4, '10-A': 2, '11-B': 0 }],
];

describe('development — direktor kesimida ayirish hujumi yashirin guruhni bermaydi', () => {
  it.each(SCENARIOS)('%s', (_, trims) => {
    const s = school({ ...BASE, ...trims });
    const idx = indexOf(s.results);
    for (const term of idx.terms) {
      const o = director(idx, s, term);
      expect(o.cognitiveByGrade.every((g) => g.bands === null)).toBe(true);
      expect(o.heat.filter((h) => !h.hidden && h.n > 0).length).toBeGreaterThan(5);
      expect(o.domainAverages.filter((d) => d.index !== null).length).toBeGreaterThanOrEqual(4);
      expect(JSON.stringify(o)).not.toMatch(/stu-|Fam/);
      for (const stat of ['ANY', ...DEV_DOMAINS] as const) assertSafe(o, idx, stat);
    }
  });

  it('kichik sinf yashiriladi va soni ko\'rsatilmaydi', () => {
    const s = school({ ...BASE, '7-A': 3 });
    const o = director(indexOf(s.results), s, termOf(NOW_DAY).key);
    const row = o.heat.find((h) => h.classId === 'cls-7-A');
    expect(row).toMatchObject({ hidden: true, n: 0 });
    expect(Object.values(row?.cells ?? {}).every((v) => v === null)).toBe(true);
    const b = o.heat.find((h) => h.classId === 'cls-7-B');
    expect(o.cognitiveByGrade.find((g) => g.grade === 7)?.hidden === false && b?.cells.REASONING != null).toBe(false);
  });
});

describe('development — e\'tibor ro\'yxati', () => {
  it('COG_LOW, EMO_SUPPORT, DECLINE va MISSED', () => {
    const s = school({ '7-A': 6 });
    const extra: LiveStudent = { id: 'stu-new', classId: 'cls-7-A', lastName: 'Yangi', firstName: 'Bola', archived: false, enrolledAt: '2025-09-02', birthDate: '2013-05-14' };
    const tweak = s.results.map((r) => {
      if (r.studentId !== 'stu-7-A-0') return r;
      if (r.testId === 'tpl-logic') return result(r.studentId, r.classId, r.grade, 'tpl-logic', { total: r.takenAt.startsWith(PREV_DAY) ? 15 : 2 }, localDay(r.takenAt));
      if (r.testId === 'tpl-emotion') return result(r.studentId, r.classId, r.grade, 'tpl-emotion', { worry: 33, mood: 15 }, localDay(r.takenAt));
      return r;
    });
    const rows = computeAttention(indexOf(tweak), { classes: s.classes, students: [...s.students, extra] });
    const reasons = Object.fromEntries(rows.map((r) => [r.studentId, r.reasons]));
    expect(reasons['stu-7-A-0']).toEqual(expect.arrayContaining(['COG_LOW', 'EMO_SUPPORT', 'DECLINE']));
    expect(reasons['stu-new']).toEqual(['MISSED']);
    expect(rows[0]?.studentId).toBe('stu-7-A-0');
  });
});

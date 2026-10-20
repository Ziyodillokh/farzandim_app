import { computeCareAggregate, ResponseRow, topicScores } from './care-aggregate';
import { CARE_MIN_GROUP as K } from './care-suppression';
import { ageGroupOf, CARE_BREAKDOWNS, CareBreakdown, CareTopic } from './care.schemas';

/** Deterministik tasodif (mulberry32). */
function rng(seed: number) {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const questions = new Map<string, { topic: CareTopic; reverse: boolean }>([
  ['q1', { topic: 'WELLBEING', reverse: false }],
  ['q2', { topic: 'PEERS', reverse: true }],
  ['q3', { topic: 'SAFETY', reverse: false }],
]);
const ALL_GROUPS = ['G1_4', 'G5_8', 'G9_11'];

/** Tasodifiy maktab: har sinfda 0..12 respondent, ba'zilari faqat bitta mavzuga javob beradi. */
function school(seed: number) {
  const r = rng(seed);
  const classes = [];
  const responses: ResponseRow[] = [];
  for (let grade = 1; grade <= 11; grade++) {
    for (const letter of ['A', 'B', 'V'].slice(0, 1 + Math.floor(r() * 3))) {
      const id = `${grade}${letter}`;
      classes.push({ id, name: `${grade}-${letter}`, grade, letter });
      const n = Math.floor(r() * 13);
      for (let i = 0; i < n; i++) {
        const answers: Record<string, number> = { q1: 1 + Math.floor(r() * 5) };
        if (r() > 0.3) answers.q2 = 1 + Math.floor(r() * 5);
        if (r() > 0.6) answers.q3 = 1 + Math.floor(r() * 5);
        responses.push({ studentId: `${id}-s${i}`, classId: id, answers });
      }
    }
  }
  return { classes, responses };
}

function classesOf(classes: Array<{ id: string; grade: number }>, breakdown: CareBreakdown, key: string): Set<string> {
  const pick = (ok: (c: { id: string; grade: number }) => boolean) => new Set(classes.filter(ok).map((c) => c.id));
  switch (breakdown) {
    case 'SCHOOL':
      return pick(() => true);
    case 'AGE_GROUP':
      return pick((c) => ageGroupOf(c.grade) === key);
    case 'GRADE':
      return pick((c) => String(c.grade) === key);
    case 'CLASS':
      return pick((c) => c.id === key);
  }
}

describe('care aggregate — ayirish hujumidan himoya', () => {
  it.each([1, 2, 3, 4, 5, 6, 7, 8])('tasodifiy maktab #%i: e\'lon qilingan to\'plamlarning eng mayda bo\'lagi 0 yoki ≥ K', (seed) => {
    const { classes, responses } = school(seed);
    for (const stat of ['ANY', 'WELLBEING', 'PEERS', 'SAFETY'] as const) {
      const published: Array<Set<string>> = [];
      for (const breakdown of CARE_BREAKDOWNS) {
        const agg = computeCareAggregate({
          survey: { id: 's', invited: 999, ageGroups: ALL_GROUPS },
          classes,
          responses,
          questions,
          breakdown,
          trend: [],
          requestsThisWeek: 0,
        });
        for (const g of agg.groups) {
          const shown = !g.hidden && (stat === 'ANY' || g.topicScores?.[stat] !== undefined);
          if (shown) published.push(classesOf(classes, breakdown, g.key));
        }
        // Natijada shaxsga bog'liq maydon yo'q.
        expect(JSON.stringify(agg)).not.toContain('-s');
      }
      // Har sinfning "a'zolik imzosi" bo'yicha bo'laklar: bir xil imzoli sinflar birga.
      const cells = new Map<string, string[]>();
      for (const c of classes) {
        const signature = published.map((set) => (set.has(c.id) ? '1' : '0')).join('');
        cells.set(signature, [...(cells.get(signature) ?? []), c.id]);
      }
      for (const ids of cells.values()) {
        const people = new Set(
          responses
            .filter((r) => ids.includes(r.classId))
            .filter((r) => stat === 'ANY' || Object.keys(r.answers).some((q) => questions.get(q)?.topic === stat))
            .map((r) => r.studentId),
        ).size;
        expect(people === 0 || people >= K).toBe(true);
      }
    }
  });

  it('mavzu ko\'rsatkichi: teskari savol aylantiriladi, K dan kam bo\'lsa chiqmaydi', () => {
    const rows = (n: number, q2: number): ResponseRow[] =>
      Array.from({ length: n }, (_, i) => ({ studentId: `s${i}`, classId: 'c', answers: { q1: 5, q2 } }));
    expect(topicScores(rows(5, 1), questions)).toEqual({ WELLBEING: 100, PEERS: 100 });
    expect(topicScores(rows(5, 5), questions)).toEqual({ WELLBEING: 100, PEERS: 0 });
    expect(topicScores(rows(4, 1), questions)).toEqual({});
  });

  it('kichik sinf yashiriladi; murojaatlar soni "<5"', () => {
    const classes = [
      { id: 'a', name: '7-A', grade: 7, letter: 'A' },
      { id: 'b', name: '7-B', grade: 7, letter: 'B' },
    ];
    const responses = [
      ...Array.from({ length: 6 }, (_, i) => ({ studentId: `a${i}`, classId: 'a', answers: { q1: 4 } })),
      ...Array.from({ length: 2 }, (_, i) => ({ studentId: `b${i}`, classId: 'b', answers: { q1: 2 } })),
    ];
    const agg = computeCareAggregate({
      survey: { id: 's', invited: 30, ageGroups: ['G5_8'] },
      classes,
      responses,
      questions,
      breakdown: 'CLASS',
      trend: [],
      requestsThisWeek: 3,
    });
    // b (2 kishi) a bilan bitta atomga qo'shiladi → ikkala sinf ham alohida ko'rsatilmaydi.
    expect(agg.groups.map((g) => g.hidden)).toEqual([true, true]);
    expect(agg).toMatchObject({ respondents: 8, participationRate: 27, requestsThisWeek: '<5' });
    expect(agg.overall.WELLBEING).toBeDefined();
  });
});

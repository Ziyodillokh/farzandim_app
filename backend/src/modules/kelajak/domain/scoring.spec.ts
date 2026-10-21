import {
  categoryScores,
  interestScores,
  isWithinDays,
  latestAnswers,
  normalizeValue,
  ProfileSession,
  riasecDimension,
  ScoredItem,
  ScoringQuestion,
  SCORING_VERSION,
  toScoredItems,
  topInterests,
} from './scoring';

const scale = (n: number) => Array.from({ length: n }, (_, i) => ({ value: i + 1 }));

const question = (
  id: string,
  category: string,
  extra: Partial<ScoringQuestion> = {},
): ScoringQuestion => ({
  id,
  externalId: id.toUpperCase(),
  category,
  answerType: 'likert_5',
  options: scale(5),
  scoring: null,
  reverse: false,
  ...extra,
});

const interest = (id: string, dimension: string) =>
  question(id, 'career_interest', { answerType: 'interest_4', options: scale(4), scoring: { dimension } });

const item = (q: ScoringQuestion, value: number): ScoredItem => ({ question: q, value });

describe('kelajak scoring — normallashtirish', () => {
  it('versiya', () => {
    expect(SCORING_VERSION).toBe(1);
  });

  it('(v - min) / (max - min) * 100; teskari — 100 - x', () => {
    expect(normalizeValue(1, scale(4), false)).toBe(0);
    expect(normalizeValue(4, scale(4), false)).toBe(100);
    expect(normalizeValue(2, scale(4), false)).toBeCloseTo(33.333, 2);
    expect(normalizeValue(3, scale(5), false)).toBe(50);
    expect(normalizeValue(5, scale(5), true)).toBe(0);
    expect(normalizeValue(2, scale(5), true)).toBe(75);
  });

  it('shkalada yo\'q qiymat yoki bitta variant — null', () => {
    expect(normalizeValue(6, scale(5), false)).toBeNull();
    expect(normalizeValue(1, [{ value: 1 }], false)).toBeNull();
  });

  it('RIASEC o\'lchami faqat career_interest uchun', () => {
    expect(riasecDimension(interest('i1', 'A'))).toBe('A');
    expect(riasecDimension(interest('i2', 'Z'))).toBeNull();
    expect(riasecDimension(question('l1', 'learning', { scoring: { dimension: 'R' } }))).toBeNull();
  });
});

describe('kelajak scoring — kategoriya va qiziqishlar', () => {
  it('kategoriya o\'rtachasi, faqat ballanadigan kategoriyalar (wellbeing/safety yo\'q)', () => {
    const scores = categoryScores([
      item(question('l1', 'learning'), 5),
      item(question('l2', 'learning'), 4),
      item(question('t1', 'teacher_relation'), 2),
      item(question('w1', 'wellbeing'), 1),
      item(question('s1', 'safety'), 1),
      item(interest('i1', 'R'), 4),
      item(question('c1', 'career_lab', { answerType: 'career_lab_5' }), 5),
    ]);
    expect(scores).toEqual([
      { category: 'learning', score: 88, answered: 2 },
      { category: 'teacher_relation', score: 25, answered: 1 },
    ]);
  });

  it('teskari savol balli teskari hisoblanadi', () => {
    const scores = categoryScores([item(question('p1', 'personal_traits', { reverse: true }), 5)]);
    expect(scores).toEqual([{ category: 'personal_traits', score: 0, answered: 1 }]);
  });

  it('notekis RIASEC: yig\'indi emas, o\'rtacha', () => {
    // R: 3 savol (yig'indi 9 > I ning 8), lekin o'rtacha I yuqori.
    const result = interestScores([
      item(interest('r1', 'R'), 4),
      item(interest('r2', 'R'), 4),
      item(interest('r3', 'R'), 1),
      item(interest('i1', 'I'), 4),
      item(interest('i2', 'I'), 4),
    ]);
    expect(result?.dimensions).toEqual([
      { code: 'R', score: 67, answered: 3 },
      { code: 'I', score: 100, answered: 2 },
    ]);
    expect(result?.top).toEqual(['I', 'R']);
    expect(result?.reliable).toBe(true);
  });

  it('qiziqish javobi yo\'q — null', () => {
    expect(interestScores([item(question('l1', 'learning'), 3)])).toBeNull();
  });

  it('top-3: tenglikda javoblar ko\'pi, keyin R-I-A-S-E-C; faqat ≥50', () => {
    const { top, reliable } = topInterests([
      { code: 'C', score: 80, answered: 2 },
      { code: 'A', score: 80, answered: 3 },
      { code: 'S', score: 80, answered: 2 },
      { code: 'E', score: 90, answered: 1 },
      { code: 'R', score: 49, answered: 3 },
    ]);
    expect(top).toEqual(['E', 'A', 'S']);
    expect(reliable).toBe(false);
    expect(topInterests([{ code: 'R', score: 50, answered: 2 }])).toEqual({ top: ['R'], reliable: true });
    expect(topInterests([{ code: 'R', score: 40, answered: 3 }])).toEqual({ top: [], reliable: false });
  });
});

describe('kelajak scoring — kumulyativ javoblar', () => {
  const now = new Date('2026-10-21T10:00:00Z');
  const session = (id: string, completedAt: string, answers: ProfileSession['answers']): ProfileSession => ({
    id,
    type: 'daily',
    day: completedAt.slice(0, 10),
    completedAt: new Date(completedAt),
    answers,
  });
  const answer = (questionId: string, value: number | null, at: string) => ({
    questionId,
    value,
    answeredAt: new Date(at),
  });

  it('har savolning eng so\'nggi javobi; ochiq matn va 180 kundan eskisi olinmaydi', () => {
    const latest = latestAnswers(
      [
        session('new', '2026-10-20T09:00:00Z', [answer('q1', 5, '2026-10-20T08:59:00Z'), answer('t1', null, '2026-10-20T08:58:00Z')]),
        session('old', '2026-10-01T09:00:00Z', [answer('q1', 1, '2026-10-01T08:00:00Z'), answer('q2', 2, '2026-10-01T08:00:00Z')]),
        session('ancient', '2026-04-20T09:00:00Z', [answer('q3', 4, '2026-04-20T08:00:00Z')]),
      ],
      now,
    );
    expect([...latest.keys()].sort()).toEqual(['q1', 'q2']);
    expect(latest.get('q1')).toMatchObject({ value: 5, sessionId: 'new' });
  });

  it('oyna Toshkent kunlarida: 179 kun oldin — ichida, 180 — tashqarida', () => {
    expect(isWithinDays(new Date('2026-04-25T00:00:00Z'), now, 180)).toBe(true);
    expect(isWithinDays(new Date('2026-04-24T12:00:00Z'), now, 180)).toBe(false);
    // 2026-04-24T19:30Z — Toshkentda allaqachon 25-aprel.
    expect(isWithinDays(new Date('2026-04-24T19:30:00Z'), now, 180)).toBe(true);
  });

  it('javoblar savollar bilan bog\'lanadi; noma\'lum savol va matn tashlanadi', () => {
    const q1 = question('q1', 'learning');
    const items = toScoredItems(
      [
        { questionId: 'q1', value: 4 },
        { questionId: 'zz', value: 3 },
        { questionId: 'q1', value: null },
      ],
      new Map([['q1', q1]]),
    );
    expect(items).toEqual([{ question: q1, value: 4 }]);
  });
});

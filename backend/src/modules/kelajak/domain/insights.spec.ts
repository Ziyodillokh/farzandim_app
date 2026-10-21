import {
  CareerLabAvailable,
  careerLabRatings,
  careerLabVerdict,
  nextCareerLab,
  nextRecommendations,
  profileSupport,
  safetyRulesGap,
  strengthsAndGrowth,
  supportSignal,
} from './insights';
import { ProfileSession, ScoredItem, ScoringQuestion } from './scoring';

const likert = (id: string, category: string, reverse = false, scoring: unknown = null): ScoringQuestion => ({
  id,
  externalId: id,
  category,
  answerType: 'likert_5',
  options: [1, 2, 3, 4, 5].map((value) => ({ value })),
  scoring,
  reverse,
});
const lab = (externalId: string, riasec: string | null = null): ScoringQuestion => ({
  ...likert(`id-${externalId}`, 'career_lab', false, riasec ? { method: 'reflection_rating', riasec } : null),
  externalId,
  answerType: 'career_lab_5',
});
/** Xavfsizlik bilimi savoli (`scoring.signal = 'knowledge'`). */
const knowledge = (id: string): ScoringQuestion => likert(id, 'safety', false, { signal: 'knowledge' });
const item = (question: ScoringQuestion, value: number): ScoredItem => ({ question, value });

describe('kelajak insights — kuchli tomon va rivojlanish', () => {
  it('≥70 va ≥2 javob — kuchli; <50 va ≥2 — rivojlanish; chegaralar', () => {
    const result = strengthsAndGrowth([
      { category: 'learning', score: 70, answered: 2 },
      { category: 'school_quality', score: 69, answered: 5 },
      { category: 'teacher_relation', score: 95, answered: 1 },
      { category: 'social_self', score: 49, answered: 2 },
      { category: 'career_planning', score: 50, answered: 4 },
      { category: 'personal_traits', score: 10, answered: 1 },
    ]);
    expect(result).toEqual({ strengths: ['learning'], growthAreas: ['social_self'] });
  });

  it('xavfsizlik bilimi: knowledge savollari o\'rtachasi <50 va ≥2 javob — maslahat; holat savollari hisobga olinmaydi', () => {
    const [k1, k2] = [knowledge('k1'), knowledge('k2')];
    expect(safetyRulesGap([item(k1, 1), item(k2, 3)])).toBe(true);
    expect(safetyRulesGap([item(k1, 1)])).toBe(false);
    expect(safetyRulesGap([item(k1, 3), item(k2, 3)])).toBe(false);
    expect(safetyRulesGap([item(likert('s1', 'safety'), 1), item(likert('s2', 'safety'), 1)])).toBe(false);
  });
});

describe('kelajak insights — Career Lab', () => {
  it.each([
    [100, 'liked'],
    [75, 'liked'],
    [60, 'liked'],
    [59, 'neutral'],
    [50, 'neutral'],
    [41, 'neutral'],
    [40, 'disliked'],
    [25, 'disliked'],
    [0, 'disliked'],
  ])('normallashtirilgan ball %i → %s', (score, verdict) => {
    expect(careerLabVerdict(score)).toBe(verdict);
  });

  it('reytinglar: RIASEC kodi scoring.riasec\'dan, umumiy savol — null; boshqa kategoriya yo\'q', () => {
    const ratings = careerLabRatings([
      item(lab('PARVOZ-Q196', 'A'), 2),
      item(lab('PARVOZ-Q194', 'R'), 5),
      item(lab('PARVOZ-Q193'), 3),
      item(likert('l1', 'learning'), 5),
    ]);
    expect(ratings.map((r) => [r.externalId, r.code, r.rating, r.score, r.verdict])).toEqual([
      ['PARVOZ-Q193', null, 3, 50, 'neutral'],
      ['PARVOZ-Q194', 'R', 5, 100, 'liked'],
      ['PARVOZ-Q196', 'A', 2, 25, 'disliked'],
    ]);
  });

  it('boshqa shkaladagi Career Lab savoli (yes_no): "Ha" — yoqdi, "Yo\'q" — yoqmadi', () => {
    const yesNo: ScoringQuestion = { ...lab('ADMIN-LAB1'), answerType: 'yes_no', options: [{ value: 1 }, { value: 2 }] };
    expect(careerLabRatings([item(yesNo, 2)])[0]).toMatchObject({ rating: 2, score: 100, verdict: 'liked' });
    expect(careerLabRatings([item(yesNo, 1)])[0]).toMatchObject({ rating: 1, score: 0, verdict: 'disliked' });
    const interest: ScoringQuestion = { ...lab('ADMIN-LAB2'), answerType: 'interest_4', options: [1, 2, 3, 4].map((value) => ({ value })) };
    expect(careerLabRatings([item(interest, 3)])[0].verdict).toBe('liked');
  });

  const available: CareerLabAvailable[] = [
    { externalId: 'PARVOZ-Q193', code: null },
    { externalId: 'PARVOZ-Q194', code: 'R' },
    { externalId: 'PARVOZ-Q195', code: 'S' },
    { externalId: 'PARVOZ-Q196', code: 'A' },
    { externalId: 'PARVOZ-Q197', code: 'I' },
  ];

  it('keyingi sinash: top kodga mos, baholanmagan faoliyat (admin qo\'shgani ham)', () => {
    expect(nextCareerLab({ topCodes: ['S', 'R'], ratings: [], available })).toEqual({
      externalId: 'PARVOZ-Q195',
      code: 'S',
      mode: 'try',
    });
    // S baholangan — keyingi top kod (R).
    const rated = careerLabRatings([item(lab('PARVOZ-Q195', 'S'), 2)]);
    expect(nextCareerLab({ topCodes: ['S', 'R'], ratings: rated, available })?.externalId).toBe('PARVOZ-Q194');
    // Admin qo'shgan, kodi ma'lumotda belgilangan faoliyat.
    const withAdmin = [...available, { externalId: 'ADMIN-0000ABCD', code: 'C' as const }];
    expect(nextCareerLab({ topCodes: ['C'], ratings: [], available: withAdmin })?.externalId).toBe('ADMIN-0000ABCD');
  });

  it('mos yangi faoliyat yo\'q — yoqqanini chuqurlashtirish; yoqqani ham yo\'q — null', () => {
    const ratings = careerLabRatings([item(lab('PARVOZ-Q194', 'R'), 4), item(lab('PARVOZ-Q196', 'A'), 5)]);
    expect(nextCareerLab({ topCodes: ['E'], ratings, available })).toEqual({
      externalId: 'PARVOZ-Q196',
      code: 'A',
      mode: 'deepen',
    });
    const disliked = careerLabRatings([item(lab('PARVOZ-Q194', 'R'), 1)]);
    expect(nextCareerLab({ topCodes: ['C'], ratings: disliked, available })).toBeNull();
    expect(nextCareerLab({ topCodes: [], ratings: [], available })).toBeNull();
  });
});

describe('kelajak insights — qo\'llab-quvvatlash signali', () => {
  const w = likert('w1', 'wellbeing');
  const s = likert('s1', 'safety');

  it('tashvish ≤25: 0 → none, 1 → watch, ≥2 → support; sohalar kategoriya darajasida', () => {
    expect(supportSignal([item(w, 3), item(s, 4)])).toEqual({ level: 'none', areas: [] });
    expect(supportSignal([item(w, 2), item(s, 4)])).toEqual({ level: 'watch', areas: ['wellbeing'] });
    expect(supportSignal([item(w, 1), item(s, 2)])).toEqual({ level: 'support', areas: ['safety', 'wellbeing'] });
  });

  it('teskari savol: yuqori qiymat — tashvish', () => {
    const tired = likert('PARVOZ-Q156', 'wellbeing', true);
    expect(supportSignal([item(tired, 5)])?.level).toBe('watch');
    expect(supportSignal([item(tired, 1)])?.level).toBe('none');
  });

  it('xavfsizlik bilimi savollari signalga kirmaydi; faqat ular bo\'lsa — null', () => {
    const [k1, k2] = [knowledge('k1'), knowledge('k2')];
    expect(supportSignal([item(k1, 1), item(k2, 1)])).toBeNull();
    expect(supportSignal([item(k1, 1), item(k2, 1), item(w, 4)])).toEqual({ level: 'none', areas: [] });
    expect(supportSignal([item(k1, 1), item(likert('s2', 'safety', false, { signal: 'distress' }), 1)])).toEqual({
      level: 'watch',
      areas: ['safety'],
    });
  });

  it('wellbeing/safety javobi yo\'q — null', () => {
    expect(supportSignal([item(likert('l1', 'learning'), 1)])).toBeNull();
  });

  describe('manba (30 kun)', () => {
    const k = knowledge('k1');
    const l = likert('l1', 'learning');
    const w2 = likert('w2', 'wellbeing');
    const questions = new Map([w, w2, s, k, l].map((q) => [q.id, q]));
    const session = (id: string, type: string, day: string, answers: Array<[string, number]>): ProfileSession => ({
      id,
      type,
      day,
      completedAt: new Date(`${day}T08:00:00Z`),
      answers: answers.map(([questionId, value]) => ({ questionId, value, answeredAt: new Date(`${day}T07:00:00Z`) })),
    });
    const now = new Date('2026-10-21T10:00:00Z');

    it('wellbeing testi yo\'q: oynadagi eng yuqori daraja; signalsiz va eskirgan sessiyalar hisobga olinmaydi', () => {
      const sessions = [
        session('latest-no-signal', 'daily', '2026-10-20', [['l1', 1]]),
        session('recent', 'daily', '2026-10-10', [['w1', 1]]),
        session('older', 'daily', '2026-10-05', [['w1', 5]]),
      ];
      expect(profileSupport(sessions, questions, now)).toEqual({
        level: 'watch',
        areas: ['wellbeing'],
        sessionId: 'recent',
        day: '2026-10-10',
      });
      expect(profileSupport([session('stale', 'daily', '2026-09-20', [['w1', 1]])], questions, now)).toBeNull();
    });

    it('kunlik savollar wellbeing testidagi "support"ni tushira olmaydi', () => {
      const sessions = [
        // Keyingi kunlik: bitta ijobiy safety javobi va bilim savoli.
        session('daily', 'daily', '2026-10-20', [['s1', 5], ['k1', 5]]),
        session('check', 'wellbeing', '2026-10-19', [['w1', 1], ['w2', 1]]),
      ];
      expect(profileSupport(sessions, questions, now)).toEqual({
        level: 'support',
        areas: ['wellbeing'],
        sessionId: 'check',
        day: '2026-10-19',
      });
    });

    it('wellbeing testidan keyingi kunlik tashvish darajani oshiradi; testdan oldingilari hisobga olinmaydi', () => {
      const sessions = [
        session('daily-after', 'daily', '2026-10-20', [['s1', 1]]),
        session('check', 'wellbeing', '2026-10-15', [['w1', 5], ['w2', 5]]),
        session('daily-before', 'daily', '2026-10-10', [['w1', 1], ['w2', 1]]),
      ];
      expect(profileSupport(sessions, questions, now)).toEqual({
        level: 'watch',
        areas: ['safety'],
        sessionId: 'daily-after',
        day: '2026-10-20',
      });
      // Yangi to'liq tekshiruv eski kunlik tashvishni almashtiradi.
      const calm = [sessions[1], sessions[2]];
      expect(profileSupport(calm, questions, now)).toMatchObject({ level: 'none', areas: [], sessionId: 'check' });
    });

    it('faqat bilim savollari bo\'lgan sessiya manba bo\'lmaydi', () => {
      expect(profileSupport([session('k', 'daily', '2026-10-20', [['k1', 1]])], questions, now)).toBeNull();
    });
  });
});

describe('kelajak insights — keyingi tavsiya', () => {
  const lab194 = { externalId: 'PARVOZ-Q194', code: 'R' as const, mode: 'try' as const };

  it('≤2 ta, tartib: career → wellbeing → Career Lab', () => {
    const next = nextRecommendations({ careerCoverage: 0.5, hasRecentWellbeing: false, careerLabNext: lab194 });
    expect(next.map((n) => [n.kind, n.testType])).toEqual([
      ['take_test', 'career'],
      ['take_test', 'wellbeing'],
    ]);
  });

  it('qamrov 80% va wellbeing bor — Career Lab faoliyati', () => {
    expect(nextRecommendations({ careerCoverage: 0.8, hasRecentWellbeing: true, careerLabNext: lab194 })).toEqual([
      { kind: 'career_lab', testType: 'career_lab', externalId: 'PARVOZ-Q194', mode: 'try' },
    ]);
  });

  it('hech biri yo\'q — "ertaga yana"', () => {
    expect(nextRecommendations({ careerCoverage: 1, hasRecentWellbeing: true, careerLabNext: null })).toEqual([
      { kind: 'come_back', testType: null, externalId: null, mode: null },
    ]);
  });
});

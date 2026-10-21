import { buildKelajakBankRows } from '../../../../scripts/kelajak/build-bank-migration';
import { buildKelajakProfile, buildSessionResult, careerCoverage, ProfileInput } from './profile';
import { careerLabRiasec, ProfileSession, ScoringQuestion, supportSignalKind, toScoredItems } from './scoring';

const allRows = buildKelajakBankRows();
const rows = allRows.filter((q) => q.ageGroup === '7-9');
const questions: ReadonlyMap<string, ScoringQuestion> = new Map(allRows.map((q) => [q.id, q]));
const ids = (category: string) => rows.filter((q) => q.category === category && q.active).map((q) => q.id);
const byExternal = new Map(allRows.map((q) => [q.externalId, q.id]));
// Ijobiy (teskari bo'lmagan) wellbeing savollari — past qiymat = tashvish.
const wellbeingPositive = rows.filter((q) => q.category === 'wellbeing' && !q.reverse).map((q) => q.id);
const available: ProfileInput['available'] = {
  careerInterestIds: ids('career_interest'),
  careerLab: rows
    .filter((q) => q.category === 'career_lab' && q.active)
    .map((q) => ({ externalId: q.externalId, code: careerLabRiasec(q) })),
  scaleIds: rows.filter((q) => q.active && q.answerType !== 'text').map((q) => q.id),
};
const now = new Date('2026-10-21T10:00:00Z');

const session = (
  id: string,
  type: string,
  day: string,
  answers: ReadonlyArray<readonly [string, number | null]>,
): ProfileSession => ({
  id,
  type,
  day,
  completedAt: new Date(`${day}T09:00:00Z`),
  answers: answers.map(([questionId, value], i) => ({
    questionId,
    value,
    answeredAt: new Date(`${day}T08:${String(i).padStart(2, '0')}:00Z`),
  })),
});

// 7–9: R (Q001, Q005, Q009) va A (Q021, Q025, Q029) yuqori, qolgani past.
const dimension = (id: string) => (questions.get(id)?.scoring as { dimension: string }).dimension;
const careerAnswers = ids('career_interest').map((id) => [id, ['R', 'A'].includes(dimension(id)) ? 4 : 1] as const);

describe('kelajak profile', () => {
  it('qamrov: javob berilgan / mavjud', () => {
    expect(careerCoverage(new Set(['a', 'b']), ['a', 'b', 'c', 'd'])).toBe(0.5);
    expect(careerCoverage(new Set(), [])).toBe(1);
  });

  it('kumulyativ profil: so\'nggi javoblar, top yo\'nalishlar, Career Lab va signal', () => {
    const learning = ids('learning');
    const wellbeing = wellbeingPositive;
    const profile = buildKelajakProfile({
      questions,
      available,
      now,
      sessions: [
        session('career', 'career', '2026-10-01', careerAnswers),
        // Eski javob (1) keyingi kunda 5 bilan almashadi.
        session('d1', 'daily', '2026-10-02', [[learning[0], 1], [learning[1], 5]]),
        session('d2', 'daily', '2026-10-15', [[learning[0], 5], [wellbeing[0], 1], [wellbeing[1], 1]]),
        session('lab', 'career_lab', '2026-10-16', [[byExternal.get('PARVOZ-Q196')!, 5]]),
      ],
    });

    expect(profile.updatedAt).toEqual(new Date('2026-10-16T09:00:00Z'));
    expect(profile.answeredQuestions).toBe(15 + 2 + 2 + 1);
    expect(profile.categories).toEqual([{ category: 'learning', score: 100, answered: 2 }]);
    expect(profile.interests?.top).toEqual(['R', 'A']);
    expect(profile.interests?.reliable).toBe(true);
    expect(profile.careerLab).toEqual([
      expect.objectContaining({ externalId: 'PARVOZ-Q196', code: 'A', rating: 5, verdict: 'liked' }),
    ]);
    expect(profile.support).toMatchObject({ level: 'support', areas: ['wellbeing'], sessionId: 'd2', day: '2026-10-15' });
    expect(profile.insightCodes).toMatchObject({
      strengths: ['learning'],
      growthAreas: [],
      interests: ['R', 'A'],
      support: 'support',
    });
    // Qamrov to'liq; wellbeing sessiyasi 14 kunda yo'q; R uchun baholanmagan faoliyat (Q194).
    expect(profile.insightCodes.next).toEqual([
      { kind: 'take_test', testType: 'wellbeing', externalId: null, mode: null },
      { kind: 'career_lab', testType: 'career_lab', externalId: 'PARVOZ-Q194', mode: 'try' },
    ]);
  });

  it('yangi bola: bo\'sh profil va qiziqishlar testi tavsiyasi', () => {
    const profile = buildKelajakProfile({ questions, available, now, sessions: [] });
    expect(profile).toMatchObject({
      updatedAt: null,
      answeredQuestions: 0,
      categories: [],
      interests: null,
      careerLab: [],
      support: null,
    });
    expect(profile.insightCodes.next.map((n) => n.testType)).toEqual(['career', 'wellbeing']);
  });

  it('bitta javobdan yo\'nalish tavsiya qilinmaydi (reliable emas) — insight bo\'sh, ball esa bor', () => {
    const one = ids('career_interest').find((id) => dimension(id) === 'R')!;
    const profile = buildKelajakProfile({
      questions,
      available,
      now,
      sessions: [session('d', 'daily', '2026-10-20', [[one, 4]])],
    });
    expect(profile.interests).toMatchObject({ top: ['R'], reliable: false });
    expect(profile.insightCodes.interests).toEqual([]);
  });

  it('answeredQuestions: faqat joriy guruhning faol shkala savollari (eski guruh va nofaol hisoblanmaydi)', () => {
    const older = allRows.find((q) => q.ageGroup === '10-12' && q.category === 'learning' && q.active)!;
    const inactive = byExternal.get('PARVOZ-Q061')!;
    const learning = ids('learning');
    const profile = buildKelajakProfile({
      questions,
      available,
      now,
      sessions: [session('d', 'daily', '2026-10-20', [[learning[0], 4], [older.id, 4], [inactive, 4]])],
    });
    expect(profile.answeredQuestions).toBe(1);
    // Ballar uchun tarix saqlanadi (§3: guruh filtri yo'q).
    expect(profile.categories).toEqual([{ category: 'learning', score: 75, answered: 3 }]);
  });

  it('xavfsizlik bilimi past — "safety_rules" maslahati, signal esa ko\'tarilmaydi', () => {
    const knowledgeIds = rows.filter((q) => supportSignalKind(q) === 'knowledge').map((q) => q.id);
    expect(knowledgeIds).toHaveLength(2);
    const profile = buildKelajakProfile({
      questions,
      available,
      now,
      sessions: [session('d', 'daily', '2026-10-20', knowledgeIds.map((id) => [id, 1] as const))],
    });
    expect(profile.insightCodes.growthAreas).toEqual(['safety_rules']);
    expect(profile.support).toBeNull();
    expect(profile.insightCodes.support).toBeNull();
  });

  it('sessiya natijasi: sessiya ballari + profil insightlari, faqat kodlar', () => {
    const wellbeing = wellbeingPositive;
    const daily = session('d', 'daily', '2026-10-21', [[ids('learning')[0], 4], [wellbeing[0], 1], [wellbeing[1], 1]]);
    const profile = buildKelajakProfile({ questions, available, now, sessions: [daily] });
    const result = buildSessionResult(toScoredItems(daily.answers, questions), profile);
    expect(result.version).toBe(1);
    expect(result.scores.categories).toEqual([{ category: 'learning', score: 75, answered: 1 }]);
    expect(result.scores.categories.some((c) => (c.category as string) === 'wellbeing')).toBe(false);
    expect(result.scores.support).toEqual({ level: 'support', areas: ['wellbeing'] });
    expect(result.scores.interests).toBeNull();
    expect(result.insightCodes).toBe(profile.insightCodes);
    expect(JSON.stringify(result)).not.toMatch(/[Ѐ-ӿ]|qiziqish|yo‘nalish/);
  });
});

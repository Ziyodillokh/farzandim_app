import {
  assessMastery,
  coversGrade,
  EvidenceAnswer,
  isTopicAvailable,
  MASTERY_MIN_EVIDENCE,
  MASTERY_PERCENT,
  MASTERY_WINDOW,
  MIN_TOPIC_QUESTIONS,
  pickCurrentTopicId,
  summarizeTopicAttempts,
} from './topic-mastery';

/** `flags[0]` — eng yangi javob. */
function evidence(flags: boolean[]): EvidenceAnswer[] {
  const base = Date.UTC(2026, 10, 1, 12, 0, 0);
  return flags.map((isCorrect, i) => ({ isCorrect, answeredAt: new Date(base - i * 60_000) }));
}

describe('mavzu konstantalari', () => {
  it('shartnomadagi qiymatlar', () => {
    expect(MIN_TOPIC_QUESTIONS).toBe(10);
    expect(MASTERY_WINDOW).toBe(10);
    expect(MASTERY_MIN_EVIDENCE).toBe(5);
    expect(MASTERY_PERCENT).toBe(80);
  });
});

describe('assessMastery', () => {
  it('dalil yo\'q — NOT_ASSESSED, sana yo\'q', () => {
    expect(assessMastery([])).toEqual({
      mastery: 'NOT_ASSESSED',
      evidenceCount: 0,
      evidenceCorrect: 0,
      lastAssessedAt: null,
    });
  });

  it('MASTERY_MIN_EVIDENCE dan kam dalil — hammasi xato bo\'lsa ham NOT_ASSESSED (0% emas)', () => {
    const result = assessMastery(evidence([false, false, false, false]));
    expect(result.mastery).toBe('NOT_ASSESSED');
    expect(result).toMatchObject({ evidenceCount: 4, evidenceCorrect: 0 });
    expect(result.lastAssessedAt).toEqual(evidence([false])[0].answeredAt);
  });

  it('aynan MASTERY_MIN_EVIDENCE ta dalil baholanadi', () => {
    expect(assessMastery(evidence([true, true, true, true, true])).mastery).toBe('MASTERED');
    expect(assessMastery(evidence([false, false, false, false, false])).mastery).toBe('PRACTICE');
  });

  it('chegara: 80% — MASTERED, 80% dan past — PRACTICE', () => {
    expect(assessMastery(evidence([true, true, true, true, false])).mastery).toBe('MASTERED'); // 4/5
    expect(assessMastery(evidence([true, true, true, false, false])).mastery).toBe('PRACTICE'); // 3/5
    expect(assessMastery(evidence([true, true, true, true, true, true, true, true, false, false])).mastery).toBe('MASTERED'); // 8/10
    expect(assessMastery(evidence([true, true, true, true, true, true, true, false, false, false])).mastery).toBe('PRACTICE'); // 7/10
  });

  it('yaxlitlash chegarani buzmaydi: 7/9 (77,8%) — PRACTICE', () => {
    const flags = [true, true, true, true, true, true, true, false, false];
    expect(assessMastery(evidence(flags)).mastery).toBe('PRACTICE');
  });

  it('faqat eng yangi MASTERY_WINDOW ta javob hisoblanadi', () => {
    // Yangi 10 tasi to'g'ri, eskilari xato → MASTERED.
    const fresh = assessMastery(evidence([...Array(10).fill(true), ...Array(10).fill(false)]));
    expect(fresh).toMatchObject({ mastery: 'MASTERED', evidenceCount: 10, evidenceCorrect: 10 });
    // Yangi 10 tasi xato, eskilari to'g'ri → PRACTICE.
    const stale = assessMastery(evidence([...Array(10).fill(false), ...Array(10).fill(true)]));
    expect(stale).toMatchObject({ mastery: 'PRACTICE', evidenceCount: 10, evidenceCorrect: 0 });
  });

  it('kiruvchi tartibdan qat\'i nazar yangisi birinchi olinadi', () => {
    const shuffled = [...evidence([...Array(10).fill(true), ...Array(5).fill(false)])].reverse();
    expect(assessMastery(shuffled)).toMatchObject({ mastery: 'MASTERED', evidenceCorrect: 10 });
  });

  it('kiruvchi massivni o\'zgartirmaydi', () => {
    const input = evidence([true, false, true, true, true, true]);
    const copy = [...input];
    assessMastery(input);
    expect(input).toEqual(copy);
  });
});

describe('coversGrade', () => {
  it('oraliq chegaralarni o\'z ichiga oladi', () => {
    const range = { minGrade: 5, maxGrade: 7 };
    expect([4, 5, 6, 7, 8].map((g) => coversGrade(range, g))).toEqual([false, true, true, true, false]);
  });
});

describe('isTopicAvailable', () => {
  it('faol va savollar yetarli', () => {
    expect(isTopicAvailable({ status: 'ACTIVE' }, MIN_TOPIC_QUESTIONS)).toBe(true);
    expect(isTopicAvailable({ status: 'ACTIVE' }, MIN_TOPIC_QUESTIONS - 1)).toBe(false);
  });

  it('yashirin mavzu savollar yetarli bo\'lsa ham mavjud emas', () => {
    expect(isTopicAvailable({ status: 'HIDDEN' }, 50)).toBe(false);
  });
});

describe('pickCurrentTopicId', () => {
  const t = (id: string, available: boolean, mastery: 'MASTERED' | 'PRACTICE' | 'NOT_ASSESSED') => ({
    id,
    available,
    mastery,
  });

  it('birinchi mavjud va o\'zlashtirilmagan mavzu', () => {
    expect(pickCurrentTopicId([t('a', true, 'MASTERED'), t('b', true, 'PRACTICE'), t('c', true, 'NOT_ASSESSED')])).toBe('b');
  });

  it('mavjud bo\'lmagan mavzular o\'tkazib yuboriladi', () => {
    expect(pickCurrentTopicId([t('a', false, 'NOT_ASSESSED'), t('b', true, 'NOT_ASSESSED')])).toBe('b');
  });

  it('hammasi o\'zlashtirilgan yoki mavjud emas — null', () => {
    expect(pickCurrentTopicId([t('a', true, 'MASTERED'), t('b', false, 'PRACTICE')])).toBeNull();
    expect(pickCurrentTopicId([])).toBeNull();
  });
});

describe('summarizeTopicAttempts', () => {
  const at = (day: number) => new Date(Date.UTC(2026, 10, day));

  it('mavzu bo\'yicha son va eng so\'nggi natija (tartibdan qat\'i nazar)', () => {
    const summary = summarizeTopicAttempts([
      { topicId: 'a', correct: 6, total: 10, completedAt: at(1) },
      { topicId: 'b', correct: 9, total: 10, completedAt: at(2) },
      { topicId: 'a', correct: 8, total: 10, completedAt: at(5) },
      { topicId: 'a', correct: 3, total: 10, completedAt: at(3) },
    ]);
    expect(summary.get('a')).toEqual({
      completedAttempts: 3,
      lastResult: { correct: 8, total: 10, completedAt: at(5) },
    });
    expect(summary.get('b')).toEqual({
      completedAttempts: 1,
      lastResult: { correct: 9, total: 10, completedAt: at(2) },
    });
    expect(summary.get('c')).toBeUndefined();
  });
});

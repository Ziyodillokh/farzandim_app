import { LearningSubject } from '@prisma/client';
import { summarizeLearning, learningStreak, StatResult } from './learning-stats';
import { parseBankQuestion } from './question-bank';
import {
  attemptSeed,
  pickQuestions,
  shuffled,
  targetDifficulty,
} from './question-picker';
import { donFor, percentOf, xpFor } from './rewards';
import { fromApiSubject, profileError, toApiSubject } from './subjects';

const { MATH, ENGLISH, PHYSICS, CHEMISTRY, HISTORY } = LearningSubject;

describe('subjects', () => {
  it('API nomlari ↔ enum', () => {
    expect(toApiSubject(MATH)).toBe('math');
    expect(fromApiSubject('informatics')).toBe('INFORMATICS');
    expect(fromApiSubject('astrology')).toBeNull();
  });

  it('profil validatsiyasi', () => {
    expect(profileError(7, [MATH, ENGLISH])).toBeNull();
    expect(profileError(0, [MATH])).toMatch(/grade/);
    expect(profileError(7, [])).toMatch(/fan/);
    expect(profileError(7, [MATH, MATH])).toMatch(/takror/);
    expect(profileError(5, [PHYSICS])).toMatch(/physics/);
    expect(profileError(6, [PHYSICS])).toBeNull();
    expect(profileError(6, [CHEMISTRY])).toMatch(/chemistry/);
    expect(
      profileError(9, [MATH, ENGLISH, PHYSICS, CHEMISTRY, HISTORY, LearningSubject.BIOLOGY]),
    ).toMatch(/5/);
  });
});

describe('rewards', () => {
  it('DON va XP', () => {
    expect(donFor(0, 10)).toBe(0);
    expect(donFor(7, 10)).toBe(14);
    expect(donFor(10, 10)).toBe(30);
    expect(xpFor(7, 10)).toBe(35);
    expect(percentOf(2, 3)).toBe(67);
    expect(percentOf(1, 0)).toBe(0);
  });
});

describe('question picker', () => {
  const pool = [
    ...[1, 2, 3].flatMap((d) =>
      [0, 1, 2, 3, 4].map((i) => ({ id: `d${d}-${i}`, difficulty: d, minGrade: 5, maxGrade: 9 })),
    ),
    ...[0, 1, 2, 3, 4, 5].map((i) => ({ id: `p${i}`, difficulty: 1, minGrade: 1, maxGrade: 4 })),
  ];

  it('maqsadli qiyinlik', () => {
    expect(targetDifficulty(null)).toBe(1);
    expect(targetDifficulty(59)).toBe(1);
    expect(targetDifficulty(60)).toBe(2);
    expect(targetDifficulty(80)).toBe(3);
  });

  it('yuqori natija — qiyin va o\'rta, osondan qiyinga', () => {
    const picked = pickQuestions({
      pool, grade: 7, count: 10, recentPercent: 95, recentlySeen: new Set(), seed: 1,
    });
    expect(picked).toHaveLength(10);
    expect(picked.filter((q) => q.difficulty === 3)).toHaveLength(5);
    expect(picked.filter((q) => q.difficulty === 2)).toHaveLength(5);
    expect(picked.map((q) => q.difficulty)).toEqual([...picked.map((q) => q.difficulty)].sort());
  });

  it('kichik sinf — boshlang\'ich sinf savollari', () => {
    const picked = pickQuestions({
      pool, grade: 2, count: 6, recentPercent: null, recentlySeen: new Set(), seed: 2,
    });
    expect(picked.every((q) => q.id.startsWith('p'))).toBe(true);
  });

  it('yaqinda ko\'rilganlar chetga suriladi', () => {
    const seen = new Set(['d1-0', 'd1-1', 'd1-2', 'd1-3', 'd1-4']);
    const picked = pickQuestions({
      pool, grade: 7, count: 5, recentPercent: null, recentlySeen: seen, seed: 3,
    });
    expect(picked.some((q) => seen.has(q.id))).toBe(false);
  });

  it('urug\' barqaror, aralashtirish to\'liq', () => {
    expect(shuffled([1, 2, 3, 4, 5], 9)).toEqual(shuffled([1, 2, 3, 4, 5], 9));
    expect([...shuffled([1, 2, 3, 4, 5], 9)].sort()).toEqual([1, 2, 3, 4, 5]);
    expect(attemptSeed('2026-10-19', 0, 0)).not.toBe(attemptSeed('2026-10-19', 1, 0));
    expect(attemptSeed('2026-10-19', 0, 0)).not.toBe(attemptSeed('2026-10-19', 0, 1));
  });
});

describe('question bank', () => {
  const valid = {
    id: 'math-01',
    difficulty: 2,
    grades: [5, 9],
    topic: { uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' },
    question: { uz: '1/2 + 1/4 = ?', ru: '1/2 + 1/4 = ?', en: '1/2 + 1/4 = ?' },
    options: ['1/6', '3/4', '2/6', '1'],
    answer: 1,
    explanation: { uz: 'a', ru: 'b', en: 'c' },
  };

  it('bank formatidagi savol', () => {
    const r = parseBankQuestion(valid, MATH);
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.value.options[1].en).toBe('3/4');
      expect(r.value.minGrade).toBe(5);
      expect(r.value.externalId).toBe('math-01');
    }
  });

  it.each([
    [{ difficulty: 4 }, /difficulty/],
    [{ grades: [9, 5] }, /grades/],
    [{ answer: 4 }, /answer/],
    [{ options: ['a', 'a', 'b', 'c'] }, /takror/],
    [{ options: ['a'] }, /options/],
    [{ topic: { uz: 'x', ru: '', en: 'y' } }, /topic\.ru/],
    [{ id: 'bad id!' }, /id/],
  ])('noto\'g\'ri: %j', (patch, error) => {
    const r = parseBankQuestion({ ...valid, ...patch }, MATH);
    expect(r.ok).toBe(false);
    if (!r.ok) expect(r.error).toMatch(error);
  });
});

describe('learning stats', () => {
  const r = (subject: LearningSubject, correct: number, day: string): StatResult => ({
    subject, correct, total: 10, day,
  });

  it('haftalik xulosa: o\'sish, kuchli va e\'tibor fan', () => {
    const summary = summarizeLearning({
      today: '2026-10-19',
      periodDays: 7,
      order: [ENGLISH, MATH],
      results: [
        r(MATH, 9, '2026-10-19'),
        r(ENGLISH, 5, '2026-10-18'),
        r(MATH, 8, '2026-10-13'),
        r(MATH, 6, '2026-10-12'),
        r(ENGLISH, 6, '2026-10-06'),
      ],
    });
    expect(summary.from).toBe('2026-10-13');
    expect(summary.testsCount).toBe(3);
    expect(summary.correctAnswers).toBe(22);
    expect(summary.overallPercent).toBe(73);
    expect(summary.previousPercent).toBe(60);
    expect(summary.growthPercent).toBe(13);
    expect(summary.subjects.map((s) => s.subject)).toEqual(['english', 'math']);
    expect(summary.strongSubject).toBe('math');
    expect(summary.focusSubject).toBe('english');
    expect(summary.activeDays).toBe(3);
    expect(summary.streakDays).toBe(2);
  });

  it('natija yo\'q — bo\'sh xulosa', () => {
    const summary = summarizeLearning({ today: '2026-10-19', periodDays: 7, results: [] });
    expect(summary.overallPercent).toBeNull();
    expect(summary.growthPercent).toBeNull();
    expect(summary.strongSubject).toBeNull();
    expect(summary.streakDays).toBe(0);
  });

  it('streak: bugun yechilmagan bo\'lsa kechadan', () => {
    expect(learningStreak([r(MATH, 5, '2026-10-18'), r(MATH, 5, '2026-10-17')], '2026-10-19')).toBe(2);
    expect(learningStreak([r(MATH, 5, '2026-10-16')], '2026-10-19')).toBe(0);
  });
});

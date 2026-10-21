import { buildKelajakProgress, PROGRESS_MAX_POINTS, ProgressSession } from './progress';

const session = (
  day: string,
  categories: ProgressSession['categories'] = [],
  interests: ProgressSession['interests'] = [],
): ProgressSession => ({ day, categories, interests });

describe('kelajak progress', () => {
  it('sessiya yo\'q — bo\'sh', () => {
    expect(buildKelajakProgress([])).toEqual({ categories: [], interests: [], improved: [], interestsRising: [] });
  });

  it('oxirgi va oldingi kun, delta, o\'sganlar (≥10)', () => {
    const progress = buildKelajakProgress([
      session('2026-10-20', [
        { category: 'learning', score: 40, answered: 3 },
        { category: 'social_self', score: 80, answered: 2 },
      ], [{ code: 'I', score: 50, answered: 2 }]),
      session('2026-10-21', [
        { category: 'learning', score: 55, answered: 3 },
        { category: 'social_self', score: 75, answered: 2 },
      ], [{ code: 'I', score: 75, answered: 2 }]),
    ]);
    expect(progress.categories).toEqual([
      {
        key: 'learning',
        latest: 55,
        previous: 40,
        delta: 15,
        points: [{ day: '2026-10-20', score: 40 }, { day: '2026-10-21', score: 55 }],
      },
      {
        key: 'social_self',
        latest: 75,
        previous: 80,
        delta: -5,
        points: [{ day: '2026-10-20', score: 80 }, { day: '2026-10-21', score: 75 }],
      },
    ]);
    expect(progress.improved).toEqual(['learning']);
    expect(progress.interests).toEqual([
      expect.objectContaining({ key: 'I', latest: 75, previous: 50, delta: 25 }),
    ]);
    expect(progress.interestsRising).toEqual(['I']);
  });

  it('bir kunda bir nechta sessiya — javoblar soni bo\'yicha o\'rtacha; bitta kun — previous null', () => {
    const progress = buildKelajakProgress([
      session('2026-10-21', [{ category: 'learning', score: 100, answered: 3 }]),
      session('2026-10-21', [{ category: 'learning', score: 0, answered: 1 }]),
    ]);
    expect(progress.categories).toEqual([
      { key: 'learning', latest: 75, previous: null, delta: null, points: [{ day: '2026-10-21', score: 75 }] },
    ]);
    expect(progress.improved).toEqual([]);
  });

  it(`kunlar tartiblanadi, ko'pi bilan ${PROGRESS_MAX_POINTS} nuqta (oxirgilari)`, () => {
    const days = Array.from({ length: 15 }, (_, i) => `2026-10-${String(i + 1).padStart(2, '0')}`);
    const progress = buildKelajakProgress(
      [...days].reverse().map((day, i) => session(day, [{ category: 'personal_traits', score: i, answered: 2 }])),
    );
    const [traits] = progress.categories;
    expect(traits.points).toHaveLength(PROGRESS_MAX_POINTS);
    expect(traits.points[0].day).toBe('2026-10-04');
    expect(traits.points[traits.points.length - 1]).toEqual({ day: '2026-10-15', score: 0 });
    expect(traits.previous).toBe(1);
  });
});

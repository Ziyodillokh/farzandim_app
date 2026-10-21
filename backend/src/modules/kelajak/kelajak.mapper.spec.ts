import { KelajakInsightCodes } from './domain/profile';
import { SUPPORT_PARENT_TEXTS } from './domain/texts';
import {
  activityLabeler,
  isParentVisibleScore,
  toParentInsightsView,
  toParentSupportView,
  toSessionAnswerViews,
} from './kelajak.mapper';

const codes: KelajakInsightCodes = {
  strengths: ['learning', 'parent_communication'],
  growthAreas: ['parent_communication', 'safety_rules'],
  interests: ['I'],
  careerLab: [
    { questionId: 'q1', externalId: 'PARVOZ-Q198', code: 'I', rating: 5, score: 100, verdict: 'liked' },
    { questionId: 'q2', externalId: 'PARVOZ-Q199', code: 'S', rating: 2, score: 25, verdict: 'disliked' },
  ],
  support: 'watch',
  next: [{ kind: 'career_lab', testType: 'career_lab', externalId: 'PARVOZ-Q200', mode: 'try' }],
};
const label = activityLabeler(new Map());

describe('kelajak mapper — ota-ona ko\'rinishlari', () => {
  it('signal: none → null; watch / support — faqat daraja, soha nomi, kun va yo\'l-yo\'riq', () => {
    expect(toParentSupportView(null)).toBeNull();
    expect(toParentSupportView({ level: 'none', areas: [], sessionId: 's', day: '2026-10-21' })).toBeNull();
    for (const level of ['watch', 'support'] as const) {
      const view = toParentSupportView({ level, areas: ['safety', 'wellbeing'], sessionId: 's', day: '2026-10-21' });
      expect(view).toEqual({
        level,
        areas: [
          { key: 'safety', name: expect.objectContaining({ uz: 'Xavfsizlik va bullying' }) },
          { key: 'wellbeing', name: expect.objectContaining({ uz: expect.any(String) }) },
        ],
        day: '2026-10-21',
        guidance: SUPPORT_PARENT_TEXTS[level],
      });
      // Raqam ham, sessiya ham yo'q — faqat shu to'rt maydon.
      expect(Object.keys(view ?? {}).sort()).toEqual(['areas', 'day', 'guidance', 'level']);
    }
  });

  it('insightlar: parent_communication yo\'q, Career Lab — reyting va savol id\'sisiz (tavsiyada ham)', () => {
    const view = toParentInsightsView(codes, label);
    expect(view.strengths.map((s) => s.key)).toEqual(['learning']);
    expect(view.growthAreas.map((g) => g.key)).toEqual(['safety_rules']);
    expect(view.likedDirections).toEqual([{ activity: expect.objectContaining({ uz: expect.any(String) }), code: 'I' }]);
    expect(view.triedDirections.map((d) => [d.code, d.verdict])).toEqual([
      ['I', 'liked'],
      ['S', 'disliked'],
    ]);
    expect(JSON.stringify(view.likedDirections)).not.toMatch(/rating|externalId|PARVOZ-Q198/);
    expect(view.next[0]).toMatchObject({ kind: 'career_lab', testType: 'career_lab', externalId: null });
    expect(view.next[0].body.uz.length).toBeGreaterThan(0);
    expect(JSON.stringify(view)).not.toContain('PARVOZ-');
    expect(view).not.toHaveProperty('support');
  });

  it('kategoriya ota-onaga: yashirin emas va kamida 2 javob', () => {
    expect(isParentVisibleScore({ category: 'learning', answered: 2 })).toBe(true);
    expect(isParentVisibleScore({ category: 'learning', answered: 1 })).toBe(false);
    expect(isParentVisibleScore({ category: 'parent_communication', answered: 5 })).toBe(false);
  });
});

describe('kelajak mapper — sessiya javoblari', () => {
  const questions = [
    { id: 'w', category: 'wellbeing' },
    { id: 's', category: 'safety' },
    { id: 'l', category: 'learning' },
    { id: 'v', category: 'child_voice' },
  ];
  const answers = [
    { questionId: 'w', value: 1, text: null },
    { questionId: 's', value: 2, text: null },
    { questionId: 'l', value: 4, text: null },
    { questionId: 'v', value: null, text: 'maxfiy' },
  ];

  it('ochiq sessiya — hammasi (orqaga qaytish uchun)', () => {
    expect(toSessionAnswerViews({ open: true, questions, answers })).toEqual(answers);
  });

  it('yopiq sessiya — matn va wellbeing / safety qiymatlari null, qolganlari saqlanadi', () => {
    expect(toSessionAnswerViews({ open: false, questions, answers })).toEqual([
      { questionId: 'w', value: null, text: null },
      { questionId: 's', value: null, text: null },
      { questionId: 'l', value: 4, text: null },
      { questionId: 'v', value: null, text: null },
    ]);
  });
});

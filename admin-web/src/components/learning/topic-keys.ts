/**
 * TanStack Query kalitlari. `questions` ostidagi barcha mavzu panellari
 * (`topicQuestions`) bitta `invalidateQueries` bilan yangilanadi.
 */
export const learningKeys = {
  topics: ['learning', 'topics'] as const,
  questions: ['learning', 'questions'] as const,
  /** Bitta mavzu paneli: fan, mavzu, rejim va qidiruv bo'yicha. */
  topicQuestions: (topicId: string, scope: string, q: string) =>
    ['learning', 'questions', topicId, scope, q] as const,
};

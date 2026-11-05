// Mavzu o'zlashtirish darajasi va mavjudligi — sof funksiyalar (DB'siz).
//
// Dalil (evidence) = bolaning mavzuga bog'langan savollarga YAKUNLANGAN
// urinishlardagi javoblari, yangisi birinchi, ko'pi bilan MASTERY_WINDOW ta.
// Kamida MASTERY_MIN_EVIDENCE ta dalil bo'lmasa — "hali baholanmagan"
// (hech qachon 0% sifatida ko'rsatilmaydi).

/** Mavzu bo'yicha test boshlash uchun kerakli minimal faol savollar soni. */
export const MIN_TOPIC_QUESTIONS = 10;
/** Baholashga hisoblanadigan eng so'nggi javoblar soni. */
export const MASTERY_WINDOW = 10;
/** Baho berish uchun minimal javoblar soni. */
export const MASTERY_MIN_EVIDENCE = 5;
/** "O'zlashtirilgan" chegarasi (foiz, shu qiymatning o'zi ham kiradi). */
export const MASTERY_PERCENT = 80;

export type TopicMastery = 'MASTERED' | 'PRACTICE' | 'NOT_ASSESSED';

export interface EvidenceAnswer {
  isCorrect: boolean;
  answeredAt: Date;
}

export interface MasteryAssessment {
  mastery: TopicMastery;
  evidenceCount: number;
  evidenceCorrect: number;
  /** Eng so'nggi dalil javobi vaqti; dalil bo'lmasa — null. */
  lastAssessedAt: Date | null;
}

/**
 * Dalillardan daraja. Kiruvchi tartib muhim emas — ichkarida yangisi
 * birinchi tartiblanib, oxirgi MASTERY_WINDOW tasi olinadi.
 */
export function assessMastery(evidence: readonly EvidenceAnswer[]): MasteryAssessment {
  const window = [...evidence]
    .sort((a, b) => b.answeredAt.getTime() - a.answeredAt.getTime())
    .slice(0, MASTERY_WINDOW);
  const evidenceCount = window.length;
  const evidenceCorrect = window.filter((a) => a.isCorrect).length;
  return {
    mastery: masteryLevel(evidenceCorrect, evidenceCount),
    evidenceCount,
    evidenceCorrect,
    lastAssessedAt: window[0]?.answeredAt ?? null,
  };
}

/** Butun sonlar bilan (yaxlitlashsiz): 79,5% — hali 80% emas. */
function masteryLevel(correct: number, count: number): TopicMastery {
  if (count < MASTERY_MIN_EVIDENCE) return 'NOT_ASSESSED';
  return correct * 100 >= MASTERY_PERCENT * count ? 'MASTERED' : 'PRACTICE';
}

export function coversGrade(range: { minGrade: number; maxGrade: number }, grade: number): boolean {
  return grade >= range.minGrade && grade <= range.maxGrade;
}

/**
 * Mavzu bola uchun mavjud: faol va shu sinfga mos faol savollar yetarli.
 * (Yetarli bo'lmasa ilova eski aralash kunlik mashqqa qaytadi.)
 */
export function isTopicAvailable(
  topic: { status: 'ACTIVE' | 'HIDDEN' },
  inGradeQuestionCount: number,
): boolean {
  return topic.status === 'ACTIVE' && inGradeQuestionCount >= MIN_TOPIC_QUESTIONS;
}

/**
 * Joriy mavzu: tartib bo'yicha birinchi mavjud va hali o'zlashtirilmagan
 * mavzu. Kiruvchi ro'yxat allaqachon `position` bo'yicha tartiblangan.
 */
export function pickCurrentTopicId(
  topics: readonly { id: string; available: boolean; mastery: TopicMastery }[],
): string | null {
  return topics.find((t) => t.available && t.mastery !== 'MASTERED')?.id ?? null;
}

export interface CompletedTopicAttempt {
  topicId: string;
  correct: number;
  total: number;
  completedAt: Date;
}

export interface TopicAttemptSummary {
  completedAttempts: number;
  lastResult: { correct: number; total: number; completedAt: Date } | null;
}

/**
 * Mavzu bo'yicha yakunlangan urinishlar: soni va eng so'nggisining natijasi.
 * Kiruvchi tartib muhim emas.
 */
export function summarizeTopicAttempts(
  attempts: readonly CompletedTopicAttempt[],
): Map<string, TopicAttemptSummary> {
  const result = new Map<string, TopicAttemptSummary>();
  for (const a of attempts) {
    const prev = result.get(a.topicId);
    const isNewer = !prev?.lastResult || a.completedAt > prev.lastResult.completedAt;
    result.set(a.topicId, {
      completedAttempts: (prev?.completedAttempts ?? 0) + 1,
      lastResult: isNewer
        ? { correct: a.correct, total: a.total, completedAt: a.completedAt }
        : prev!.lastResult,
    });
  }
  return result;
}

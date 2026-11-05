// Mavzu katalogi → bola ilovasi ko'rinishlari (U02 "bilim xaritasi", U03 "mavzu").

import { LearningTopic } from '@prisma/client';
import { LocalizedText } from './domain/localized';
import { fillTopicText, TopicText } from './domain/topic-input';
import { MasteryAssessment, TopicAttemptSummary, TopicMastery } from './domain/topic-mastery';

/** Qisqa havola: urinish / natija javoblarida. */
export interface TopicRefView {
  id: string;
  key: string;
  title: LocalizedText;
}

export interface TopicView extends TopicRefView {
  goal: LocalizedText | null;
  position: number;
  minGrade: number;
  maxGrade: number;
  /** Bola sinfiga mos FAOL savollar soni. */
  questionCount: number;
  available: boolean;
  mastery: TopicMastery;
  evidenceCount: number;
  evidenceCorrect: number;
  lastAssessedAt: string | null;
  completedAttempts: number;
  lastResult: { correct: number; total: number; completedAt: string } | null;
}

export interface TopicDetailView extends TopicView {
  subject: string;
  inProgressAttempt: { id: string; answered: number; total: number } | null;
}

export interface TopicListView {
  subject: string;
  grade: number;
  currentTopicId: string | null;
  topics: TopicView[];
}

/** Ma'lumotlar bazasidagi mavzu → havola uchun kerakli ustunlar. */
export const TOPIC_REF_SELECT = { id: true, key: true, title: true } as const;
export type TopicRefRow = Pick<LearningTopic, 'id' | 'key' | 'title'>;

export function toTopicRef(row: TopicRefRow): TopicRefView {
  return { id: row.id, key: row.key, title: fillTopicText(row.title as unknown as TopicText) };
}

export interface TopicStats {
  questionCount: number;
  available: boolean;
  assessment: MasteryAssessment;
  attempts: TopicAttemptSummary | undefined;
}

export function toTopicView(topic: LearningTopic, stats: TopicStats): TopicView {
  const { assessment, attempts } = stats;
  return {
    ...toTopicRef(topic),
    goal: topic.goal ? fillTopicText(topic.goal as unknown as TopicText) : null,
    position: topic.position,
    minGrade: topic.minGrade,
    maxGrade: topic.maxGrade,
    questionCount: stats.questionCount,
    available: stats.available,
    mastery: assessment.mastery,
    evidenceCount: assessment.evidenceCount,
    evidenceCorrect: assessment.evidenceCorrect,
    lastAssessedAt: assessment.lastAssessedAt?.toISOString() ?? null,
    completedAttempts: attempts?.completedAttempts ?? 0,
    lastResult: attempts?.lastResult
      ? {
          correct: attempts.lastResult.correct,
          total: attempts.lastResult.total,
          completedAt: attempts.lastResult.completedAt.toISOString(),
        }
      : null,
  };
}

// Mavzu o'zlashtirish dalillari (DB so'rovi) — mavzular ro'yxati ham, "Mavzu ustasi"
// yutug'i ham shu bitta so'rovdan foydalanadi (daraja qoidalari: `domain/topic-mastery.ts`).

import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assessMastery, EvidenceAnswer, MASTERY_WINDOW } from './domain/topic-mastery';

interface EvidenceRow {
  topic_id: string;
  is_correct: boolean;
  answered_at: Date;
}

type Db = Pick<PrismaService, '$queryRaw'>;

/**
 * Har mavzu uchun eng yangi MASTERY_WINDOW ta javob: bolaning YAKUNLANGAN
 * urinishlaridagi, mavzuga bog'langan savollarga javoblari (urinish turidan
 * qat'i nazar). `topicIds === null` — bolaning barcha mavzulari.
 */
export async function fetchMasteryEvidence(
  db: Db,
  childId: string,
  topicIds: readonly string[] | null,
): Promise<Map<string, EvidenceAnswer[]>> {
  if (topicIds && topicIds.length === 0) return new Map();
  const topicFilter = topicIds
    ? Prisma.sql`q.topic_id IN (${Prisma.join(topicIds)})`
    : Prisma.sql`q.topic_id IS NOT NULL`;
  const rows = await db.$queryRaw<EvidenceRow[]>`
    SELECT topic_id, is_correct, answered_at FROM (
      SELECT q.topic_id AS topic_id, a.is_correct AS is_correct, a.answered_at AS answered_at,
             ROW_NUMBER() OVER (
               PARTITION BY q.topic_id ORDER BY a.answered_at DESC, a.id DESC
             ) AS rn
      FROM learning_answers a
      JOIN learning_attempts t ON t.id = a.attempt_id
      JOIN learning_questions q ON q.id = a.question_id
      WHERE t.child_id = ${childId}
        AND t.status = 'COMPLETED'
        AND ${topicFilter}
    ) ranked
    WHERE rn <= ${MASTERY_WINDOW}`;
  const byTopic = new Map<string, EvidenceAnswer[]>();
  for (const r of rows) {
    byTopic.set(r.topic_id, [
      ...(byTopic.get(r.topic_id) ?? []),
      { isCorrect: r.is_correct, answeredAt: r.answered_at },
    ]);
  }
  return byTopic;
}

/** Berilgan mavzulardan (null — hammasidan) kamida bittasi "o'zlashtirilgan"mi. */
export async function hasMasteredTopic(
  db: Db,
  childId: string,
  topicIds: readonly string[] | null,
): Promise<boolean> {
  const evidence = await fetchMasteryEvidence(db, childId, topicIds);
  return [...evidence.values()].some((answers) => assessMastery(answers).mastery === 'MASTERED');
}

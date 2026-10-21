// Kelajak servislari uchun umumiy DB o'qishlari: bola yoshi, advisory lock,
// savollar, javoblar tarixi va kumulyativ profil. Tranzaksiya ichida ham
// (yakunlash), tashqarida ham (overview, ota-ona xulosasi) ishlaydi.

import { NotFoundException } from '@nestjs/common';
import { KelajakQuestion, KelajakSession, KelajakSessionStatus, Prisma } from '@prisma/client';
import { DayKey, tashkentDayStart } from '../../common/time/tashkent';
import { careerLabLabel } from './domain/career-lab';
import { CareerLabAvailable } from './domain/insights';
import { L } from './domain/localized';
import { buildKelajakProfile, KelajakInsightCodes, KelajakProfile } from './domain/profile';
import { careerLabRiasec, PROFILE_WINDOW_DAYS, ProfileSession, ScoringQuestion } from './domain/scoring';
import { ActivityLabel, activityIds, activityLabeler } from './kelajak.mapper';

export type Db = Prisma.TransactionClient;

const DAY_MS = 24 * 60 * 60 * 1000;
/** Profil oynasi + 1 kun zaxira (aniq chegarani `latestAnswers` tekshiradi). */
const PROFILE_LOOKBACK_MS = (PROFILE_WINDOW_DAYS + 1) * DAY_MS;

export const OPEN_STATUSES: KelajakSessionStatus[] = [
  KelajakSessionStatus.STARTED,
  KelajakSessionStatus.IN_PROGRESS,
];

/** Bola bo'yicha tranzaksion qulf (boshlash / javob / yakunlash navbat bilan). */
export async function lockChild(tx: Db, childId: string): Promise<void> {
  await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${`kelajak:${childId}`}, 0))`;
}

export const isOpenStatus = (status: KelajakSessionStatus) => OPEN_STATUSES.includes(status);

/** O'tgan Toshkent kunida boshlangan va hali ochiq sessiya (yopilishi kerak). */
export const isStaleOpen = (session: Pick<KelajakSession, 'status' | 'day'>, today: DayKey) =>
  isOpenStatus(session.status) && session.day < today;

/** O'tgan kunlarda yakunlanmay qolgan sessiyalar — ABANDONED (§3). */
export async function closeStaleSessions(db: Db, childId: string, today: DayKey): Promise<void> {
  await db.kelajakSession.updateMany({
    where: { childId, status: { in: OPEN_STATUSES }, day: { lt: today } },
    data: { status: KelajakSessionStatus.ABANDONED },
  });
}

/**
 * Javobdan oldin savol qatori FOR SHARE bilan o'qiladi: admin tahriri
 * (FOR UPDATE) bilan navbat — variantlar tekshiruv va yozish orasida
 * o'zgarib qolmaydi.
 */
export async function lockQuestionForAnswer(tx: Db, questionId: string): Promise<KelajakQuestion | null> {
  await tx.$queryRaw`SELECT 1 AS locked FROM "kelajak_questions" WHERE "id" = ${questionId} FOR SHARE`;
  return tx.kelajakQuestion.findUnique({ where: { id: questionId } });
}

export async function loadChildAge(db: Db, childId: string): Promise<{ birthDate: Date | null; age: number | null }> {
  const child = await db.child.findUnique({ where: { id: childId }, select: { birthDate: true, age: true } });
  if (!child) throw new NotFoundException('Child not found');
  return child;
}

/** Savollar `ids` tartibida (topilmagani tashlab yuboriladi). */
export async function questionsInOrder(db: Db, ids: readonly string[]): Promise<KelajakQuestion[]> {
  const rows = await db.kelajakQuestion.findMany({ where: { id: { in: [...ids] } } });
  const byId = new Map(rows.map((q) => [q.id, q]));
  return ids.flatMap((id) => {
    const q = byId.get(id);
    return q ? [q] : [];
  });
}

/** Savol id → bolaning shu savolga oxirgi javob bergan kuni (ms, Toshkent kuni boshi). */
export async function loadAnswerHistory(db: Db, childId: string): Promise<Map<string, number>> {
  const rows = await db.$queryRaw<Array<{ questionId: string; day: string }>>`
    SELECT a."question_id" AS "questionId", MAX(s."day") AS "day"
    FROM "kelajak_answers" a
    JOIN "kelajak_sessions" s ON s."id" = a."session_id"
    WHERE s."child_id" = ${childId}
    GROUP BY a."question_id"`;
  return new Map(rows.map((r) => [r.questionId, tashkentDayStart(r.day).getTime()]));
}

export function toScoringQuestion(q: Pick<
  KelajakQuestion,
  'id' | 'externalId' | 'category' | 'answerType' | 'options' | 'scoring' | 'reverse'
>): ScoringQuestion {
  return {
    id: q.id,
    externalId: q.externalId,
    category: q.category,
    answerType: q.answerType,
    options: q.options as unknown as ScoringQuestion['options'],
    scoring: q.scoring,
    reverse: q.reverse,
  };
}

async function loadScoringQuestions(db: Db, ids: readonly string[]): Promise<Map<string, ScoringQuestion>> {
  if (ids.length === 0) return new Map();
  const rows = await db.kelajakQuestion.findMany({
    where: { id: { in: [...ids] } },
    select: { id: true, externalId: true, category: true, answerType: true, options: true, scoring: true, reverse: true },
  });
  return new Map(rows.map((q) => [q.id, toScoringQuestion(q)]));
}

/** Profil oynasidagi YAKUNLANGAN sessiyalar va ularning javoblari. */
async function loadProfileSessions(db: Db, childId: string, now: Date): Promise<ProfileSession[]> {
  const rows = await db.kelajakSession.findMany({
    where: {
      childId,
      status: KelajakSessionStatus.COMPLETED,
      completedAt: { gte: new Date(now.getTime() - PROFILE_LOOKBACK_MS) },
    },
    select: {
      id: true,
      type: true,
      day: true,
      completedAt: true,
      answers: { select: { questionId: true, value: true, answeredAt: true } },
    },
  });
  return rows.flatMap((s) => (s.completedAt ? [{ ...s, completedAt: s.completedAt }] : []));
}

export interface AvailableQuestions {
  careerInterestIds: string[];
  careerLab: CareerLabAvailable[];
  /** Yosh guruhidagi faol shkala savollari (ochiq matnsiz). */
  scaleIds: string[];
}

async function loadAvailable(db: Db, ageGroup: string | null): Promise<AvailableQuestions> {
  if (!ageGroup) return { careerInterestIds: [], careerLab: [], scaleIds: [] };
  const rows = await db.kelajakQuestion.findMany({
    where: { ageGroup, active: true },
    select: { id: true, externalId: true, category: true, answerType: true, scoring: true },
    orderBy: { externalId: 'asc' },
  });
  return {
    careerInterestIds: rows.filter((q) => q.category === 'career_interest').map((q) => q.id),
    careerLab: rows
      .filter((q) => q.category === 'career_lab')
      .map((q) => ({ externalId: q.externalId, code: careerLabRiasec(q) })),
    scaleIds: rows.filter((q) => q.answerType !== 'text').map((q) => q.id),
  };
}

export interface LoadedProfile {
  profile: KelajakProfile;
  /** Profil va `current` javoblaridagi savollar. */
  questions: ReadonlyMap<string, ScoringQuestion>;
  available: AvailableQuestions;
}

/**
 * Kumulyativ profil. `current` — hozir yakunlanayotgan sessiya (hali
 * COMPLETED yozilmagan), profilga qo'shib hisoblanadi.
 */
export async function loadKelajakProfile(
  db: Db,
  params: { childId: string; ageGroup: string | null; now: Date; current?: ProfileSession },
): Promise<LoadedProfile> {
  const { childId, ageGroup, now, current } = params;
  const stored = await loadProfileSessions(db, childId, now);
  const sessions = current ? [...stored.filter((s) => s.id !== current.id), current] : stored;
  const questionIds = [...new Set(sessions.flatMap((s) => s.answers.map((a) => a.questionId)))];
  // Ketma-ket: tranzaksiya klientida parallel so'rov yuborilmaydi.
  const questions = await loadScoringQuestions(db, questionIds);
  const available = await loadAvailable(db, ageGroup);
  const profile = buildKelajakProfile({ questions, sessions, available, now });
  return { profile, questions, available };
}

/** Career Lab faoliyati nomlari: xaritada yo'q bo'lsa — savol matni. */
export async function loadActivityLabel(
  db: Db,
  codes: readonly KelajakInsightCodes[],
): Promise<ActivityLabel> {
  const missing = [...new Set(codes.flatMap(activityIds))].filter((id) => !careerLabLabel(id));
  if (missing.length === 0) return activityLabeler(new Map());
  const rows = await db.kelajakQuestion.findMany({
    where: { externalId: { in: missing } },
    select: { externalId: true, text: true },
  });
  return activityLabeler(new Map(rows.map((q) => [q.externalId, q.text as unknown as L])));
}

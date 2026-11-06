// ─────────────────────────────────────────────────────────────────────
// Daily Learning — mavzular katalogi (bola ilovasi tomoni)
// ─────────────────────────────────────────────────────────────────────
//
// U02 "bilim xaritasi" (fan mavzulari + o'zlashtirish darajasi) va U03
// "mavzu" (maqsad, oldingi natija, davom ettiriladigan urinish). Daraja
// serverda hisoblanadi (`domain/topic-mastery.ts`); ro'yxat bir necha
// agregat so'rov bilan (N+1 yo'q).

import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import {
  LearningAttemptStatus,
  LearningQuestionStatus,
  LearningSubject,
  LearningTopic,
  LearningTopicStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { PickableQuestion } from './domain/question-picker';
import { fromApiSubject, toApiSubject } from './domain/subjects';
import {
  assessMastery,
  EvidenceAnswer,
  isTopicAvailable,
  pickCurrentTopicId,
  summarizeTopicAttempts,
} from './domain/topic-mastery';
import { fetchMasteryEvidence } from './learning-mastery.query';
import { requireProfile } from './learning-profile.guard';
import { TopicDetailView, TopicListView, TopicView, toTopicView } from './learning-topic.mapper';

type Db = Pick<Prisma.TransactionClient, 'learningTopic' | 'learningQuestion'>;

@Injectable()
export class LearningTopicsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Test uchun almashtiriladi. */
  protected now(): Date {
    return new Date();
  }

  /** Fan mavzulari (bola sinfiga mos, `position` tartibida) + joriy mavzu. */
  async listForSubject(childId: string, apiSubject: string): Promise<TopicListView> {
    const subject = fromApiSubject(apiSubject);
    if (!subject) throw new BadRequestException('Unknown subject');
    const { grade } = await requireProfile(this.prisma, childId);
    const topics = await this.prisma.learningTopic.findMany({
      where: {
        subject,
        status: LearningTopicStatus.ACTIVE,
        minGrade: { lte: grade },
        maxGrade: { gte: grade },
      },
      orderBy: [{ position: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    });
    const views = await this.viewsFor(childId, grade, topics);
    return {
      subject: toApiSubject(subject),
      grade,
      currentTopicId: pickCurrentTopicId(views),
      topics: views,
    };
  }

  /** Bitta mavzu + shu mavzu bo'yicha bugungi yakunlanmagan urinish. */
  async detail(childId: string, topicId: string): Promise<TopicDetailView> {
    const { grade } = await requireProfile(this.prisma, childId);
    const topic = await this.prisma.learningTopic.findUnique({ where: { id: topicId } });
    if (!topic || topic.status !== LearningTopicStatus.ACTIVE) {
      throw new NotFoundException('Topic not found');
    }
    const [[view], open] = await Promise.all([
      this.viewsFor(childId, grade, [topic]),
      this.prisma.learningAttempt.findFirst({
        where: {
          childId,
          topicId,
          day: tashkentDay(this.now()),
          status: LearningAttemptStatus.IN_PROGRESS,
        },
        select: { id: true, total: true, _count: { select: { answers: true } } },
      }),
    ]);
    return {
      ...view,
      subject: toApiSubject(topic.subject),
      inProgressAttempt: open
        ? { id: open.id, answered: open._count.answers, total: open.total }
        : null,
    };
  }

  /**
   * Urinish boshlash uchun mavzu: mavjud, faol va shu fanniki bo'lishi shart —
   * aks holda 422 `TOPIC_NOT_AVAILABLE`. (Savollar yetarliligi alohida:
   * `assertPoolSufficient`.)
   */
  async requireStartable(db: Db, subject: LearningSubject, topicId: string): Promise<LearningTopic> {
    const topic = await db.learningTopic.findUnique({ where: { id: topicId } });
    if (!topic || topic.status !== LearningTopicStatus.ACTIVE || topic.subject !== subject) {
      throw topicNotAvailable();
    }
    return topic;
  }

  /** Mavzuning shu sinfga mos FAOL savollari (tanlash uchun). */
  async inGradePool(db: Db, topicId: string, grade: number): Promise<PickableQuestion[]> {
    return db.learningQuestion.findMany({
      where: {
        topicId,
        status: LearningQuestionStatus.ACTIVE,
        minGrade: { lte: grade },
        maxGrade: { gte: grade },
      },
      select: { id: true, difficulty: true, minGrade: true, maxGrade: true },
    });
  }

  assertPoolSufficient(topic: LearningTopic, pool: readonly PickableQuestion[]): void {
    if (!isTopicAvailable(topic, pool.length)) throw topicNotAvailable();
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /** Mavzular uchun ko'rinishlar (kiruvchi tartibda) — 3 ta agregat so'rov. */
  private async viewsFor(
    childId: string,
    grade: number,
    topics: readonly LearningTopic[],
  ): Promise<TopicView[]> {
    if (topics.length === 0) return [];
    const ids = topics.map((t) => t.id);
    const [counts, evidence, attempts] = await Promise.all([
      this.questionCounts(ids, grade),
      this.evidence(childId, ids),
      this.completedAttempts(childId, ids),
    ]);
    const attemptSummary = summarizeTopicAttempts(attempts);
    return topics.map((topic) => {
      const questionCount = counts.get(topic.id) ?? 0;
      return toTopicView(topic, {
        questionCount,
        available: isTopicAvailable(topic, questionCount),
        assessment: assessMastery(evidence.get(topic.id) ?? []),
        attempts: attemptSummary.get(topic.id),
      });
    });
  }

  private async questionCounts(ids: string[], grade: number): Promise<Map<string, number>> {
    const rows = await this.prisma.learningQuestion.groupBy({
      by: ['topicId'],
      where: {
        topicId: { in: ids },
        status: LearningQuestionStatus.ACTIVE,
        minGrade: { lte: grade },
        maxGrade: { gte: grade },
      },
      _count: { _all: true },
    });
    return new Map(rows.flatMap((r) => (r.topicId ? [[r.topicId, r._count._all] as const] : [])));
  }

  private evidence(childId: string, ids: string[]): Promise<Map<string, EvidenceAnswer[]>> {
    return fetchMasteryEvidence(this.prisma, childId, ids);
  }

  private async completedAttempts(childId: string, ids: string[]) {
    const rows = await this.prisma.learningAttempt.findMany({
      where: { childId, status: LearningAttemptStatus.COMPLETED, topicId: { in: ids } },
      select: { topicId: true, correct: true, total: true, completedAt: true },
    });
    return rows.flatMap((r) =>
      r.topicId && r.completedAt
        ? [{ topicId: r.topicId, correct: r.correct, total: r.total, completedAt: r.completedAt }]
        : [],
    );
  }
}

function topicNotAvailable(): UnprocessableEntityException {
  return new UnprocessableEntityException({
    message: 'Topic is not available',
    code: 'TOPIC_NOT_AVAILABLE',
  });
}

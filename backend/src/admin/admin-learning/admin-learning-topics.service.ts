// ─────────────────────────────────────────────────────────────────────
// Admin — Daily Learning mavzular katalogi
// ─────────────────────────────────────────────────────────────────────
//
// Mavzu yaratish / tahrirlash / tartiblash va savollarni mavzuga bog'lash.
// Qattiq o'chirish YO'Q: mavzu `HIDDEN` qilinadi (tarix va urinishlar saqlanadi).
// Har o'zgarish audit jurnaliga yoziladi.

import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  LearningQuestionStatus,
  LearningSubject,
  LearningTopic,
  LearningTopicStatus,
  Prisma,
} from '@prisma/client';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { PrismaService } from '../../common/database/prisma.service';
import { fromApiSubject, toApiSubject } from '../../modules/learning/domain/subjects';
import {
  gradeRangeError,
  isValidTopicKey,
  parseTopicText,
  TOPIC_GOAL_MAX,
  TOPIC_TITLE_MAX,
} from '../../modules/learning/domain/topic-input';
import { MIN_TOPIC_QUESTIONS } from '../../modules/learning/domain/topic-mastery';
import {
  CreateLearningTopicDto,
  LinkTopicQuestionsDto,
  ListLearningTopicsQueryDto,
  ReorderLearningTopicsDto,
  UpdateLearningTopicDto,
} from './dto/admin-learning-topic.dto';

type Req = { ip?: string; headers?: Record<string, string | string[] | undefined> };

@Injectable()
export class AdminLearningTopicsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AdminAuditService,
  ) {}

  async list(query: ListLearningTopicsQueryDto) {
    const topics = await this.prisma.learningTopic.findMany({
      where: {
        ...(query.subject && { subject: fromApiSubject(query.subject)! }),
        ...(query.status && { status: query.status }),
      },
      orderBy: [{ subject: 'asc' }, { position: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    });
    return { minQuestions: MIN_TOPIC_QUESTIONS, items: await this.rows(topics) };
  }

  async create(dto: CreateLearningTopicDto, staffId: string, req: Req) {
    const subject = fromApiSubject(dto.subject)!;
    const fields = this.parseFields(dto);
    const position = dto.position ?? (await this.nextPosition(subject));
    const created = await this.guardKey(() =>
      this.prisma.learningTopic.create({
        data: {
          subject,
          key: dto.key,
          title: fields.title,
          goal: fields.goal ?? undefined,
          minGrade: dto.minGrade,
          maxGrade: dto.maxGrade,
          position,
          status: dto.status ?? LearningTopicStatus.ACTIVE,
          createdBy: staffId,
        },
      }),
    );
    void this.audit.log(req, {
      action: 'learning.topic.create',
      moderatorId: staffId,
      resourceType: 'learning_topic',
      resourceId: created.id,
      details: { subject: dto.subject, key: dto.key },
    });
    return (await this.rows([created]))[0];
  }

  async update(id: string, dto: UpdateLearningTopicDto, staffId: string, req: Req) {
    const existing = await this.findOrThrow(id);
    // DTO'da berilmagan maydonlar `undefined` — mavjud qiymatni o'chirmasin (`goal: null` esa o'chiradi).
    const patch = Object.fromEntries(Object.entries(dto).filter(([, v]) => v !== undefined));
    if (Object.keys(patch).length === 0) throw new BadRequestException('No fields to update');
    const fields = this.parseFields({
      key: dto.key ?? existing.key,
      title: dto.title ?? existing.title,
      goal: dto.goal === undefined ? existing.goal : dto.goal,
      minGrade: dto.minGrade ?? existing.minGrade,
      maxGrade: dto.maxGrade ?? existing.maxGrade,
    });
    const updated = await this.guardKey(() =>
      this.prisma.learningTopic.update({
        where: { id },
        data: {
          ...(dto.key !== undefined && { key: dto.key }),
          ...(dto.title !== undefined && { title: fields.title }),
          ...(dto.goal !== undefined && { goal: fields.goal ?? Prisma.DbNull }),
          ...(dto.minGrade !== undefined && { minGrade: dto.minGrade }),
          ...(dto.maxGrade !== undefined && { maxGrade: dto.maxGrade }),
          ...(dto.position !== undefined && { position: dto.position }),
          ...(dto.status !== undefined && { status: dto.status }),
        },
      }),
    );
    void this.audit.log(req, {
      action: 'learning.topic.update',
      moderatorId: staffId,
      resourceType: 'learning_topic',
      resourceId: id,
      details: { fields: Object.keys(patch) },
    });
    return (await this.rows([updated]))[0];
  }

  /** `ids` aynan shu fanning barcha mavzulari bo'lishi shart; pozitsiya = indeks. */
  async reorder(dto: ReorderLearningTopicsDto, staffId: string, req: Req) {
    const subject = fromApiSubject(dto.subject)!;
    const current = await this.prisma.learningTopic.findMany({
      where: { subject },
      select: { id: true },
    });
    const mismatch = orderMismatch(current.map((t) => t.id), dto.ids);
    if (mismatch) {
      throw new BadRequestException({
        message: `ids must be exactly the topics of subject "${dto.subject}"`,
        code: 'TOPIC_ORDER_MISMATCH',
        ...mismatch,
      });
    }
    await this.prisma.$transaction(
      dto.ids.map((id, position) =>
        this.prisma.learningTopic.update({ where: { id }, data: { position } }),
      ),
    );
    void this.audit.log(req, {
      action: 'learning.topic.reorder',
      moderatorId: staffId,
      resourceType: 'learning_topic',
      details: { subject: dto.subject, count: dto.ids.length },
    });
    return this.list({ subject: dto.subject });
  }

  /** Savollarni mavzuga bog'lash (boshqa mavzudan ko'chiriladi). */
  async linkQuestions(id: string, dto: LinkTopicQuestionsDto, staffId: string, req: Req) {
    const topic = await this.findOrThrow(id);
    const questions = await this.prisma.learningQuestion.findMany({
      where: { id: { in: dto.questionIds } },
      select: { id: true, subject: true },
    });
    const found = new Set(questions.map((q) => q.id));
    const missing = dto.questionIds.filter((qid) => !found.has(qid));
    if (missing.length > 0) {
      throw new BadRequestException({
        message: 'Some questions do not exist',
        code: 'QUESTION_NOT_FOUND',
        questionIds: missing,
      });
    }
    const wrongSubject = questions.filter((q) => q.subject !== topic.subject).map((q) => q.id);
    if (wrongSubject.length > 0) {
      throw new BadRequestException({
        message: 'Questions must have the same subject as the topic',
        code: 'QUESTION_SUBJECT_MISMATCH',
        questionIds: wrongSubject,
      });
    }
    const { count } = await this.prisma.learningQuestion.updateMany({
      where: { id: { in: dto.questionIds } },
      data: { topicId: id },
    });
    void this.audit.log(req, {
      action: 'learning.topic.link_questions',
      moderatorId: staffId,
      resourceType: 'learning_topic',
      resourceId: id,
      details: { linked: count },
    });
    return { topicId: id, linked: count, questionCount: await this.activeQuestionCount(id) };
  }

  /** Savol yaratish / tahrirlash uchun: mavzu mavjud va savol bilan bir fanga tegishli. */
  async assertLinkable(topicId: string, subject: LearningSubject): Promise<void> {
    const topic = await this.prisma.learningTopic.findUnique({
      where: { id: topicId },
      select: { subject: true },
    });
    if (!topic) {
      throw new BadRequestException({ message: 'topicId: topic not found', code: 'TOPIC_NOT_FOUND' });
    }
    if (topic.subject !== subject) {
      throw new BadRequestException({
        message: 'topicId: topic belongs to another subject',
        code: 'QUESTION_SUBJECT_MISMATCH',
      });
    }
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async findOrThrow(id: string): Promise<LearningTopic> {
    const topic = await this.prisma.learningTopic.findUnique({ where: { id } });
    if (!topic) throw new NotFoundException('Topic not found');
    return topic;
  }

  private async nextPosition(subject: LearningSubject): Promise<number> {
    const last = await this.prisma.learningTopic.aggregate({
      where: { subject },
      _max: { position: true },
    });
    return (last._max.position ?? -1) + 1;
  }

  private async activeQuestionCount(topicId: string): Promise<number> {
    return this.prisma.learningQuestion.count({
      where: { topicId, status: LearningQuestionStatus.ACTIVE },
    });
  }

  /** Kalit / sarlavha / maqsad / sinflar tekshiruvi (400) — yaratish va tahrirlash uchun umumiy. */
  private parseFields(input: {
    key: string;
    title: unknown;
    goal?: unknown;
    minGrade: number;
    maxGrade: number;
  }): { title: Prisma.InputJsonValue; goal: Prisma.InputJsonValue | null } {
    if (!isValidTopicKey(input.key)) throw new BadRequestException('key: slug (a-z, 0-9, -) kerak');
    const title = parseTopicText(input.title, 'title', TOPIC_TITLE_MAX);
    if (!title.ok) throw new BadRequestException(title.error);
    const goal = input.goal == null ? null : parseTopicText(input.goal, 'goal', TOPIC_GOAL_MAX);
    if (goal && !goal.ok) throw new BadRequestException(goal.error);
    const rangeError = gradeRangeError(input.minGrade, input.maxGrade);
    if (rangeError) throw new BadRequestException(rangeError);
    return { title: title.value, goal: goal?.ok ? goal.value : null };
  }

  /** `(subject, key)` takrori — 409 `TOPIC_KEY_TAKEN`. */
  private async guardKey<T>(action: () => Promise<T>): Promise<T> {
    try {
      return await action();
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException({
          message: 'A topic with this key already exists in the subject',
          code: 'TOPIC_KEY_TAKEN',
        });
      }
      throw e;
    }
  }

  private async rows(topics: readonly LearningTopic[]) {
    const counts =
      topics.length === 0
        ? []
        : await this.prisma.learningQuestion.groupBy({
            by: ['topicId'],
            where: { topicId: { in: topics.map((t) => t.id) }, status: LearningQuestionStatus.ACTIVE },
            _count: { _all: true },
          });
    const byTopic = new Map(counts.map((c) => [c.topicId, c._count._all]));
    return topics.map((t) => ({
      ...t,
      subject: toApiSubject(t.subject),
      questionCount: byTopic.get(t.id) ?? 0,
    }));
  }
}

/** `expected` va `actual` bir xil to'plam emas bo'lsa — farq; aks holda null. */
function orderMismatch(
  expected: readonly string[],
  actual: readonly string[],
): { missing: string[]; unknown: string[] } | null {
  const expectedSet = new Set(expected);
  const actualSet = new Set(actual);
  const missing = expected.filter((id) => !actualSet.has(id));
  const unknown = actual.filter((id) => !expectedSet.has(id));
  return missing.length === 0 && unknown.length === 0 ? null : { missing, unknown };
}

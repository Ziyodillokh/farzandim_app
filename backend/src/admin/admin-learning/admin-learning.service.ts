// ─────────────────────────────────────────────────────────────────────
// Admin — Daily Learning savollar banki
// ─────────────────────────────────────────────────────────────────────
//
// CRUD, JSON import (bank formati, `externalId` bo'yicha) va statistika
// (savol aniqligi — juda oson / juda qiyin savollarni topish). Javob
// berilgan savolning variantlari / to'g'ri javobi O'ZGARTIRILMAYDI (tarix
// va tahlil buzilmasin) — arxivlab, yangisini qo'shish kerak; matn
// xatolarini tuzatish mumkin.

import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  LearningQuestion,
  LearningQuestionStatus,
  LearningSubject,
  Prisma,
} from '@prisma/client';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, tashkentDay } from '../../common/time/tashkent';
import { BankQuestion, parseBankQuestion } from '../../modules/learning/domain/question-bank';
import { fromApiSubject, toApiSubject } from '../../modules/learning/domain/subjects';
import {
  ImportLearningQuestionsDto,
  LearningQuestionInputDto,
  ListLearningQuestionsQueryDto,
  UpdateLearningQuestionDto,
} from './dto/admin-learning.dto';

type Req = { ip?: string; headers?: Record<string, string | string[] | undefined> };

/** Statistikada savol aniqligi hisoblanadigan minimal javoblar soni. */
const MIN_ANSWERS_FOR_STATS = 20;
const STATS_TOP = 10;

interface AnswerStat {
  answers: number;
  correctRate: number | null;
}

@Injectable()
export class AdminLearningService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AdminAuditService,
  ) {}

  async list(query: ListLearningQuestionsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where: Prisma.LearningQuestionWhereInput = {
      ...(query.subject && { subject: fromApiSubject(query.subject)! }),
      ...(query.status && { status: query.status }),
      ...(query.difficulty && { difficulty: query.difficulty }),
      ...(query.grade && {
        minGrade: { lte: query.grade },
        maxGrade: { gte: query.grade },
      }),
      ...(query.q && {
        OR: [
          { externalId: { contains: query.q, mode: 'insensitive' } },
          { prompt: { path: ['uz'], string_contains: query.q } },
        ],
      }),
    };
    const [total, rows] = await Promise.all([
      this.prisma.learningQuestion.count({ where }),
      this.prisma.learningQuestion.findMany({
        where,
        orderBy: [{ subject: 'asc' }, { externalId: 'asc' }, { createdAt: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    const stats = await this.answerStats(rows.map((r) => r.id));
    return {
      items: rows.map((q) => this.row(q, stats.get(q.id))),
      pagination: { page, limit, total, totalPages: Math.max(1, Math.ceil(total / limit)) },
    };
  }

  async get(id: string) {
    const question = await this.prisma.learningQuestion.findUnique({ where: { id } });
    if (!question) throw new NotFoundException('Question not found');
    const stats = await this.answerStats([id]);
    return this.row(question, stats.get(id));
  }

  async create(dto: LearningQuestionInputDto, staffId: string, req: Req) {
    const parsed = this.parse(dto, fromApiSubject(dto.subject)!);
    const created = await this.prisma.learningQuestion.create({
      data: {
        ...this.data(parsed),
        status: dto.status ?? LearningQuestionStatus.ACTIVE,
        createdBy: staffId,
      },
    });
    void this.audit.log(req, {
      action: 'learning.question.create',
      moderatorId: staffId,
      resourceType: 'learning_question',
      resourceId: created.id,
    });
    return this.row(created);
  }

  async update(id: string, dto: UpdateLearningQuestionDto, staffId: string, req: Req) {
    const existing = await this.prisma.learningQuestion.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Question not found');
    // DTO'da berilmagan maydonlar `undefined` — mavjud qiymatni o'chirmasin.
    const patch = Object.fromEntries(
      Object.entries(dto).filter(([, value]) => value !== undefined),
    );
    const parsed = this.parse({ ...this.inputOf(existing), ...patch }, existing.subject);
    await this.assertAnswerUnchanged(existing, parsed);

    const updated = await this.prisma.learningQuestion.update({
      where: { id },
      data: { ...this.data(parsed), ...(dto.status && { status: dto.status }) },
    });
    void this.audit.log(req, {
      action: 'learning.question.update',
      moderatorId: staffId,
      resourceType: 'learning_question',
      resourceId: id,
      details: { fields: Object.keys(patch) },
    });
    return this.row(updated);
  }

  /**
   * Biror urinishga tushgan (javob berilgan yoki hali ochiq) savol
   * arxivlanadi — aks holda o'chiriladi (ochiq urinish "yetim" qolmasin).
   */
  async remove(id: string, staffId: string, req: Req) {
    const existing = await this.prisma.learningQuestion.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Question not found');
    const [answers, attempts] = await Promise.all([
      this.prisma.learningAnswer.count({ where: { questionId: id } }),
      this.prisma.learningAttempt.count({ where: { questionIds: { has: id } } }),
    ]);
    const inUse = answers + attempts > 0;
    if (inUse) {
      await this.prisma.learningQuestion.update({
        where: { id },
        data: { status: LearningQuestionStatus.ARCHIVED },
      });
    } else {
      await this.prisma.learningQuestion.delete({ where: { id } });
    }
    void this.audit.log(req, {
      action: inUse ? 'learning.question.archive' : 'learning.question.delete',
      moderatorId: staffId,
      resourceType: 'learning_question',
      resourceId: id,
    });
    return inUse ? { archived: true } : { deleted: true };
  }

  /** Bank formatidagi savollarni import — har yozuv alohida tekshiriladi. */
  async import(dto: ImportLearningQuestionsDto, staffId: string, req: Req) {
    const subject = fromApiSubject(dto.subject)!;
    const report = {
      created: 0,
      updated: 0,
      skipped: 0,
      errors: [] as { index: number; id: string | null; error: string }[],
    };
    for (const [index, raw] of dto.questions.entries()) {
      const parsed = parseBankQuestion(raw, subject);
      if (!parsed.ok) {
        report.errors.push({ index, id: idOf(raw), error: parsed.error });
        continue;
      }
      const q = parsed.value;
      if (!q.externalId) {
        report.errors.push({ index, id: null, error: 'id: import uchun majburiy' });
        continue;
      }
      const existing = await this.prisma.learningQuestion.findUnique({
        where: { externalId: q.externalId },
      });
      if (!existing) {
        await this.prisma.learningQuestion.create({
          data: { ...this.data(q), createdBy: staffId },
        });
        report.created++;
      } else if (dto.existing === 'update') {
        try {
          await this.assertAnswerUnchanged(existing, q);
          await this.prisma.learningQuestion.update({
            where: { id: existing.id },
            data: this.data(q),
          });
          report.updated++;
        } catch (e) {
          report.errors.push({ index, id: q.externalId, error: (e as Error).message });
        }
      } else {
        report.skipped++;
      }
    }
    void this.audit.log(req, {
      action: 'learning.question.import',
      moderatorId: staffId,
      resourceType: 'learning_question',
      details: { subject: dto.subject, ...report, errors: report.errors.length },
    });
    return report;
  }

  async stats() {
    const [byStatus, byDifficulty, attempts, hardest, easiest] = await Promise.all([
      this.prisma.learningQuestion.groupBy({
        by: ['subject', 'status'],
        _count: { _all: true },
      }),
      this.prisma.learningQuestion.groupBy({
        by: ['subject', 'difficulty'],
        where: { status: LearningQuestionStatus.ACTIVE },
        _count: { _all: true },
      }),
      this.prisma.learningAttempt.groupBy({
        by: ['status'],
        where: { day: { gte: addDays(tashkentDay(), -6) } },
        _count: { _all: true },
      }),
      this.accuracyExtremes('ASC'),
      this.accuracyExtremes('DESC'),
    ]);

    const subjects = Object.values(LearningSubject).map((subject) => {
      const count = (status: LearningQuestionStatus) =>
        byStatus.find((r) => r.subject === subject && r.status === status)?._count._all ?? 0;
      return {
        subject: toApiSubject(subject),
        active: count(LearningQuestionStatus.ACTIVE),
        draft: count(LearningQuestionStatus.DRAFT),
        archived: count(LearningQuestionStatus.ARCHIVED),
        byDifficulty: Object.fromEntries(
          [1, 2, 3].map((d) => [
            d,
            byDifficulty.find((r) => r.subject === subject && r.difficulty === d)?._count._all ?? 0,
          ]),
        ),
      };
    });
    return {
      subjects,
      attemptsLast7Days: Object.fromEntries(attempts.map((a) => [a.status, a._count._all])),
      hardest,
      easiest,
    };
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private parse(raw: object, subject: LearningSubject): BankQuestion {
    const parsed = parseBankQuestion(raw, subject);
    if (!parsed.ok) throw new BadRequestException(parsed.error);
    return parsed.value;
  }

  private data(q: BankQuestion) {
    return {
      externalId: q.externalId,
      subject: q.subject,
      difficulty: q.difficulty,
      minGrade: q.minGrade,
      maxGrade: q.maxGrade,
      topic: q.topic,
      prompt: q.prompt,
      options: q.options,
      answerIndex: q.answerIndex,
      explanation: q.explanation,
    };
  }

  private inputOf(q: LearningQuestion) {
    return {
      externalId: q.externalId,
      difficulty: q.difficulty,
      minGrade: q.minGrade,
      maxGrade: q.maxGrade,
      topic: q.topic,
      prompt: q.prompt,
      options: q.options,
      answerIndex: q.answerIndex,
      explanation: q.explanation,
    };
  }

  /** Javob berilgan savolda variantlar soni / to'g'ri javob o'zgarmasin. */
  private async assertAnswerUnchanged(existing: LearningQuestion, next: BankQuestion) {
    const options = existing.options as unknown[];
    const changed =
      next.answerIndex !== existing.answerIndex || next.options.length !== options.length;
    if (!changed) return;
    const inUse = (await this.prisma.learningAnswer.count({ where: { questionId: existing.id } })) > 0;
    if (inUse) {
      throw new ConflictException({
        message: 'Question already has answers: archive it and add a new one',
        code: 'QUESTION_IN_USE',
      });
    }
  }

  private async answerStats(ids: string[]): Promise<Map<string, AnswerStat>> {
    if (ids.length === 0) return new Map();
    const rows = await this.prisma.learningAnswer.groupBy({
      by: ['questionId', 'isCorrect'],
      where: { questionId: { in: ids } },
      _count: { _all: true },
    });
    const stats = new Map<string, { answers: number; correct: number }>();
    for (const r of rows) {
      const s = stats.get(r.questionId) ?? { answers: 0, correct: 0 };
      s.answers += r._count._all;
      if (r.isCorrect) s.correct += r._count._all;
      stats.set(r.questionId, s);
    }
    return new Map(
      [...stats].map(([id, s]) => [
        id,
        { answers: s.answers, correctRate: s.answers ? Math.round((s.correct * 100) / s.answers) : null },
      ]),
    );
  }

  private async accuracyExtremes(order: 'ASC' | 'DESC') {
    const rows = await this.prisma.$queryRaw<
      { question_id: string; answers: bigint; correct_rate: number }[]
    >`
      SELECT question_id, COUNT(*) AS answers,
             ROUND(AVG(CASE WHEN is_correct THEN 100 ELSE 0 END))::int AS correct_rate
      FROM learning_answers
      GROUP BY question_id
      HAVING COUNT(*) >= ${MIN_ANSWERS_FOR_STATS}
      ORDER BY correct_rate ${Prisma.raw(order)}, answers DESC
      LIMIT ${STATS_TOP}`;
    const questions = await this.prisma.learningQuestion.findMany({
      where: { id: { in: rows.map((r) => r.question_id) } },
      select: { id: true, externalId: true, subject: true, difficulty: true, prompt: true },
    });
    const byId = new Map(questions.map((q) => [q.id, q]));
    return rows.map((r) => {
      const q = byId.get(r.question_id);
      return {
        id: r.question_id,
        externalId: q?.externalId ?? null,
        subject: q ? toApiSubject(q.subject) : null,
        difficulty: q?.difficulty ?? null,
        prompt: q?.prompt ?? null,
        answers: Number(r.answers),
        correctRate: r.correct_rate,
      };
    });
  }

  private row(q: LearningQuestion, stat?: AnswerStat) {
    return {
      ...q,
      subject: toApiSubject(q.subject),
      answers: stat?.answers ?? 0,
      correctRate: stat?.correctRate ?? null,
    };
  }
}

function idOf(raw: unknown): string | null {
  const id = (raw as { id?: unknown } | null)?.id;
  return typeof id === 'string' ? id : null;
}

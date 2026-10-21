// ─────────────────────────────────────────────────────────────────────
// Admin — Parvoz Kelajak savollar banki (docs/KELAJAK-REJA.md §6)
// ─────────────────────────────────────────────────────────────────────
//
// Ro'yxat (filtr, qidiruv, javoblar soni), yaratish, tahrirlash va
// statistika. Validatsiya — import bilan bir xil domen parseri. Javob
// berilgan yoki bugungi ochiq sessiyada turgan savolda kategoriya, yosh,
// javob turi, variantlar, scoring va `reverse` O'ZGARMAYDI (ballar tarixi va
// ochiq sessiya buzilmasin) — 409 QUESTION_IN_USE. Tahrir savol qatorini
// qulflab (FOR UPDATE) bajariladi — parallel javob tekshiruvdan o'tib ketmasin.
// O'chirish yo'q: nofaol qilish yumshoq o'chirish o'rnini bosadi.

import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { KelajakQuestion, KelajakSessionStatus, Prisma } from '@prisma/client';
import { AdminAuditService } from '../../common/audit/admin-audit.service';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, tashkentDay } from '../../common/time/tashkent';
import { KelajakQuestionData, parseKelajakQuestion } from '../../modules/kelajak/domain/bank';
import { QuestionChanges } from '../../modules/kelajak/domain/import-plan';
import {
  changedFields,
  definedFields,
  generateExternalId,
  isReservedExternalId,
  lockedFields,
  mergeQuestionPatch,
  RESERVED_EXTERNAL_ID_PREFIX,
} from './admin-kelajak.input';
import { ActiveGroup, toAdminQuestionView, toStatsView } from './admin-kelajak.views';
import {
  CreateKelajakQuestionDto,
  ListKelajakQuestionsQueryDto,
  UpdateKelajakQuestionDto,
} from './dto/admin-kelajak.dto';

type Req = { ip?: string; headers?: Record<string, string | string[] | undefined> };
type Tx = Prisma.TransactionClient;

const OPEN_STATUSES: KelajakSessionStatus[] = [KelajakSessionStatus.STARTED, KelajakSessionStatus.IN_PROGRESS];

const DEFAULT_PAGE_LIMIT = 20;
/** "Oxirgi 7 kun" — bugun bilan birga. */
const RECENT_DAYS = 7;

const notFound = () => new NotFoundException('Question not found');
const invalid = (message: string) => new BadRequestException({ message, code: 'INVALID_QUESTION' });
const duplicate = (externalId: string) =>
  new ConflictException({ message: `externalId already exists: ${externalId}`, code: 'DUPLICATE_EXTERNAL_ID' });

const isUniqueViolation = (e: unknown) =>
  e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';

/** LIKE maxsus belgilari (`%`, `_`, `\`) — oddiy belgi sifatida qidiriladi. */
const likePattern = (q: string) => `%${q.replace(/[\\%_]/g, '\\$&')}%`;

const jsonOf = (value: unknown) => value as Prisma.InputJsonValue;
const scoringOf = (value: Record<string, unknown> | null) => (value === null ? Prisma.DbNull : jsonOf(value));

/** O'zgargan maydonlar → Prisma `update` (JSON ustunlari alohida). */
function updateData(changes: QuestionChanges): Prisma.KelajakQuestionUpdateInput {
  const { text, options, scoring, ...plain } = changes;
  return {
    ...plain,
    ...(text !== undefined && { text: jsonOf(text) }),
    ...(options !== undefined && { options: jsonOf(options) }),
    ...(scoring !== undefined && { scoring: scoringOf(scoring) }),
  };
}

@Injectable()
export class AdminKelajakService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AdminAuditService,
  ) {}

  async list(query: ListKelajakQuestionsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? DEFAULT_PAGE_LIMIT;
    const where: Prisma.KelajakQuestionWhereInput = {
      ...(query.category && { category: query.category }),
      ...(query.ageGroup && { ageGroup: query.ageGroup }),
      ...(query.active && { active: query.active === 'true' }),
      ...(query.answerType && { answerType: query.answerType }),
      ...(query.sourceType && { sourceType: query.sourceType }),
      ...(query.q && { id: { in: await this.searchIds(query.q) } }),
    };
    const [total, rows] = await Promise.all([
      this.prisma.kelajakQuestion.count({ where }),
      this.prisma.kelajakQuestion.findMany({
        where,
        orderBy: [{ externalId: 'asc' }, { createdAt: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    const counts = await this.answerCounts(rows.map((q) => q.id));
    return {
      items: rows.map((q) => toAdminQuestionView(q, counts.get(q.id) ?? 0)),
      pagination: { page, limit, total, totalPages: Math.max(1, Math.ceil(total / limit)) },
    };
  }

  async get(id: string) {
    const question = await this.prisma.kelajakQuestion.findUnique({ where: { id } });
    if (!question) throw notFound();
    const counts = await this.answerCounts([id]);
    return toAdminQuestionView(question, counts.get(id) ?? 0);
  }

  async create(dto: CreateKelajakQuestionDto, staffId: string, req: Req) {
    if (dto.externalId !== undefined && isReservedExternalId(dto.externalId)) {
      throw invalid(`externalId: ${RESERVED_EXTERNAL_ID_PREFIX} prefiksi bank savollari uchun band`);
    }
    const parsed = this.parse({ ...definedFields(dto), externalId: dto.externalId ?? generateExternalId() });
    const externalId = parsed.externalId as string;
    const exists = await this.prisma.kelajakQuestion.findUnique({ where: { externalId }, select: { id: true } });
    if (exists) throw duplicate(externalId);

    const created = await this.prisma.kelajakQuestion
      .create({
        data: {
          ...parsed,
          externalId,
          text: jsonOf(parsed.text),
          options: jsonOf(parsed.options),
          scoring: scoringOf(parsed.scoring),
          createdBy: staffId,
        },
      })
      .catch((e: unknown) => {
        // Parallel so'rov bir xil externalId bilan — 500 emas, 409.
        throw isUniqueViolation(e) ? duplicate(externalId) : e;
      });
    void this.audit.log(req, {
      action: 'kelajak.question.create',
      moderatorId: staffId,
      resourceType: 'kelajak_question',
      resourceId: created.id,
      details: { externalId },
    });
    return toAdminQuestionView(created, 0);
  }

  async update(id: string, dto: UpdateKelajakQuestionDto, staffId: string, req: Req) {
    const { existing, updated, fields, answerCount } = await this.prisma.$transaction(async (tx) => {
      // Qator qulfi: bolaning javobi (FOR SHARE) shu tahrir tugashini kutadi va aksincha.
      await tx.$queryRaw`SELECT 1 AS locked FROM "kelajak_questions" WHERE "id" = ${id} FOR UPDATE`;
      const current = await tx.kelajakQuestion.findUnique({ where: { id } });
      if (!current) throw notFound();
      const parsed = this.parse(mergeQuestionPatch(current, definedFields(dto)));
      const changed = changedFields(current, parsed);
      const locked = lockedFields(changed);
      const answers = await tx.kelajakAnswer.count({ where: { questionId: id } });
      if (locked.length > 0 && (answers > 0 || (await inOpenSession(tx, id)))) {
        throw new ConflictException({
          message:
            answers > 0
              ? 'Question already has answers: only text, notes, reviewNote, followUp, required and active can change'
              : 'Question is in an open session today: only text, notes, reviewNote, followUp, required and active can change',
          code: 'QUESTION_IN_USE',
          fields: locked,
        });
      }
      const changes = Object.fromEntries(changed.map((f) => [f, parsed[f]])) as QuestionChanges;
      const next: KelajakQuestion =
        changed.length > 0 ? await tx.kelajakQuestion.update({ where: { id }, data: updateData(changes) }) : current;
      return { existing: current, updated: next, fields: changed, answerCount: answers };
    });
    void this.audit.log(req, {
      action: 'kelajak.question.update',
      moderatorId: staffId,
      resourceType: 'kelajak_question',
      resourceId: id,
      details: { externalId: existing.externalId, fields },
    });
    return toAdminQuestionView(updated, answerCount);
  }

  async stats() {
    const since = addDays(tashkentDay(), -(RECENT_DAYS - 1));
    const [byCategory, byAgeGroup, byAnswerType, needsReview, sessions, completed, completedRecent] =
      await Promise.all([
        this.groupByActive('category'),
        this.groupByActive('ageGroup'),
        this.groupByActive('answerType'),
        this.prisma.kelajakQuestion.count({ where: { reviewNote: { not: null } } }),
        this.prisma.kelajakSession.count(),
        this.prisma.kelajakSession.count({ where: { status: KelajakSessionStatus.COMPLETED } }),
        this.prisma.kelajakSession.count({
          where: { status: KelajakSessionStatus.COMPLETED, day: { gte: since } },
        }),
      ]);
    return toStatsView({
      byCategory,
      byAgeGroup,
      byAnswerType,
      needsReview,
      sessions: { total: sessions, completed, completedLast7Days: completedRecent },
    });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private parse(raw: object): KelajakQuestionData {
    const parsed = parseKelajakQuestion(raw);
    if (!parsed.ok) throw new BadRequestException({ message: parsed.error, code: 'INVALID_QUESTION' });
    return parsed.value;
  }

  /** `externalId` yoki matn (uz/ru/en) bo'yicha, katta-kichik harfsiz. */
  private async searchIds(q: string): Promise<string[]> {
    const pattern = likePattern(q.trim());
    const rows = await this.prisma.$queryRaw<Array<{ id: string }>>`
      SELECT "id" FROM "kelajak_questions"
      WHERE "external_id" ILIKE ${pattern}
         OR "text"->>'uz' ILIKE ${pattern}
         OR "text"->>'ru' ILIKE ${pattern}
         OR "text"->>'en' ILIKE ${pattern}`;
    return rows.map((r) => r.id);
  }

  private async answerCounts(ids: readonly string[]): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const rows = await this.prisma.kelajakAnswer.groupBy({
      by: ['questionId'],
      where: { questionId: { in: [...ids] } },
      _count: { _all: true },
    });
    return new Map(rows.map((r) => [r.questionId, r._count._all]));
  }

  private async groupByActive(key: 'category' | 'ageGroup' | 'answerType'): Promise<ActiveGroup[]> {
    const rows = await this.prisma.kelajakQuestion.groupBy({
      by: [key, 'active'],
      _count: { _all: true },
    });
    return rows.map((r) => ({ key: r[key], active: r.active, count: r._count._all }));
  }
}

/** Savol bugungi (yoki keyingi kunning) ochiq sessiyasi snapshot'idami — o'tgan kundagilari yopilgan hisoblanadi. */
async function inOpenSession(tx: Tx, questionId: string): Promise<boolean> {
  const count = await tx.kelajakSession.count({
    where: { status: { in: OPEN_STATUSES }, day: { gte: tashkentDay() }, questionIds: { has: questionId } },
  });
  return count > 0;
}

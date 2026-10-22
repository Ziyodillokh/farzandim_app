// ─────────────────────────────────────────────────────────────────────
// Parvoz IQ test — bola sessiyalari va natijalar (docs/IQ-REJA.md)
// ─────────────────────────────────────────────────────────────────────
//
// Sessiya 24 soat ochiq (davom ettiriladi), keyin ABANDONED. Qayta topshirish
// 180 kundan keyin, forma almashadi. To'g'ri javob kaliti (`IqItem.answer`)
// klientga hech qachon chiqmaydi — `correct` faqat serverda hisoblanadi.
// Natijada faqat xom javoblar; baho o'qilganda (iq.views `scoreSession`).
// Bola bo'yicha advisory lock — boshlash / javob / yakunlash navbat bilan.

import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { IqSession, IqSessionStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { IqItemKind, LocalizedText } from './domain/bank';
import {
  formFor,
  IqAge,
  isExpired,
  nextAvailableAt,
  normGroupForAge,
  normKey,
  resolveIqAge,
  SESSION_TTL_HOURS,
} from './domain/levels';
import { orderSessionItems } from './domain/order';
import { eapAbility, normStats, NormStats, SCORING_VERSION, welfordAdd } from './domain/scoring';
import { IqAnswerDto } from './dto/iq.dto';
import {
  designCenter,
  IqHistoryEntry,
  IqItemView,
  IqOptionView,
  IqOverview,
  IqParentSummary,
  IqSessionView,
  parseStoredResult,
  scoreSession,
  StoredIqResult,
} from './iq.views';

type Db = Prisma.TransactionClient | PrismaService;
type Outcome<T> = { closed: true } | { closed: false; value: T };

const OPEN: IqSessionStatus[] = [IqSessionStatus.STARTED, IqSessionStatus.IN_PROGRESS];
const HISTORY_LIMIT = 20;
const AGE_ERRORS: Readonly<Record<Exclude<IqAge['status'], 'OK'>, string>> = {
  AGE_REQUIRED: 'Child age or birth date is required',
  AGE_OUT_OF_RANGE: 'IQ test is available for ages 9–20',
};

const sessionClosed = () =>
  new ConflictException({
    message: 'Session is closed',
    code: 'SESSION_CLOSED',
  });
const notInSession = () =>
  new BadRequestException({
    message: 'Item is not part of this session',
    code: 'ITEM_NOT_IN_SESSION',
  });

async function lock(db: Db, key: string): Promise<void> {
  await db.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${key}, 0))`;
}

async function ownSession(db: Db, childId: string, sessionId: string): Promise<IqSession> {
  const session = await db.iqSession.findUnique({ where: { id: sessionId } });
  if (!session || session.childId !== childId) {
    throw new NotFoundException({
      message: 'Session not found',
      code: 'SESSION_NOT_FOUND',
    });
  }
  return session;
}

const optionKeys = (options: Prisma.JsonValue): string[] =>
  Array.isArray(options)
    ? options.map((o) => (o as { key?: unknown })?.key).filter((k): k is string => typeof k === 'string')
    : [];

/** Sessiya tartibidagi `b` qiymatlari. */
function orderedBs(itemIds: readonly string[], items: ReadonlyArray<{ id: string; b: number }>): number[] {
  const byId = new Map(items.map((i) => [i.id, i.b]));
  const bs = itemIds.map((id) => byId.get(id));
  const center = designCenter(bs.filter((b): b is number => b !== undefined));
  return bs.map((b) => b ?? center);
}

/** Sessiya tartibidagi savol turlari (tur bo'yicha natija uchun). */
function orderedKinds(itemIds: readonly string[], items: ReadonlyArray<{ id: string; kind: IqItemKind }>): Array<IqItemKind | undefined> {
  const byId = new Map(items.map((i) => [i.id, i.kind]));
  return itemIds.map((id) => byId.get(id));
}

type ItemRow = { id: string; kind: IqItemKind; gridSvg: string | null; stem: Prisma.JsonValue; options: Prisma.JsonValue };

/** Klientga savol — faqat ko'rsatish uchun maydonlar (`answer`, `b` yo'q). */
function itemView(item: ItemRow, position: number, choice: string | null): IqItemView {
  const raw = (Array.isArray(item.options) ? item.options : []) as Array<{ key: string; svg?: string; text?: LocalizedText }>;
  const options: IqOptionView[] =
    item.kind === 'FIGURAL' ? raw.map(({ key, svg }) => ({ key, svg })) : raw.map(({ key, text }) => ({ key, text }));
  return {
    id: item.id,
    position,
    kind: item.kind,
    gridSvg: item.kind === 'FIGURAL' ? item.gridSvg : null,
    stem: item.kind === 'FIGURAL' ? null : ((item.stem as LocalizedText | null) ?? null),
    options,
    choice,
  };
}

@Injectable()
export class IqService {
  constructor(private readonly prisma: PrismaService) {}

  /** Test uchun almashtiriladi. */
  protected now(): Date {
    return new Date();
  }

  // ── Kirish ─────────────────────────────────────────────────────────

  async childIdForUser(userId: string): Promise<string> {
    const child = await this.prisma.child.findUnique({
      where: { childUserId: userId },
      select: { id: true },
    });
    if (!child) throw new ForbiddenException('Child profile required');
    return child.id;
  }

  async assertParentOwns(parentUserId: string, childId: string): Promise<void> {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
      select: { parentId: true },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== parentUserId) throw new ForbiddenException('Forbidden');
  }

  // ── Ko'rinishlar ───────────────────────────────────────────────────

  async overview(childId: string): Promise<IqOverview> {
    const now = this.now();
    await this.closeExpired(this.prisma, childId, now);
    const [age, open, summary] = await Promise.all([
      this.ageOf(this.prisma, childId, now),
      this.prisma.iqSession.findFirst({
        where: { childId, status: { in: OPEN } },
        orderBy: { startedAt: 'desc' },
      }),
      this.parentSummary(childId),
    ]);
    const answered = open ? await this.prisma.iqAnswer.count({ where: { sessionId: open.id } }) : 0;
    return {
      age,
      canStart: age.status === 'OK' && (open !== null || summary.nextAvailableAt === null),
      nextAvailableAt: summary.nextAvailableAt,
      active: open ? { sessionId: open.id, answered, total: open.total } : null,
      last: summary.last,
      history: summary.history,
    };
  }

  async parentSummary(childId: string): Promise<IqParentSummary> {
    const now = this.now();
    const [age, completed] = await Promise.all([
      this.ageOf(this.prisma, childId, now),
      this.prisma.iqSession.findMany({
        where: { childId, status: IqSessionStatus.COMPLETED },
        orderBy: { completedAt: 'desc' },
        take: HISTORY_LIMIT,
      }),
    ]);
    const history = await this.history(completed);
    const next = nextAvailableAt(completed[0]?.completedAt ?? null);
    return {
      age,
      last: history[0]?.result ?? null,
      nextAvailableAt: next && next > now ? next.toISOString() : null,
      history,
    };
  }

  async sessionView(childId: string, sessionId: string): Promise<IqSessionView> {
    await this.closeExpired(this.prisma, childId, this.now());
    const session = await ownSession(this.prisma, childId, sessionId);
    const [items, answers] = await Promise.all([
      this.prisma.iqItem.findMany({
        where: { id: { in: session.itemIds } },
        select: { id: true, kind: true, gridSvg: true, stem: true, options: true, b: true },
      }),
      this.prisma.iqAnswer.findMany({
        where: { sessionId },
        select: { itemId: true, choice: true },
      }),
    ]);
    const byId = new Map(items.map((i) => [i.id, i]));
    const choices = new Map(answers.map((a) => [a.itemId, a.choice]));
    const stored = session.status === IqSessionStatus.COMPLETED ? parseStoredResult(session.result) : null;
    return {
      id: session.id,
      status: session.status,
      level: session.level,
      form: session.form,
      total: session.total,
      startedAt: session.startedAt.toISOString(),
      completedAt: session.completedAt?.toISOString() ?? null,
      items: session.itemIds.flatMap((id, position) => {
        const item = byId.get(id);
        return item ? [itemView(item, position, choices.get(id) ?? null)] : [];
      }),
      result: stored
        ? scoreSession(
            session,
            stored,
            orderedBs(session.itemIds, items),
            await this.normOf(this.prisma, session),
            orderedKinds(session.itemIds, items),
          )
        : null,
    };
  }

  // ── Sessiya ────────────────────────────────────────────────────────

  /** Yangi yoki davom etayotgan sessiya. */
  async startSession(childId: string): Promise<IqSessionView> {
    const now = this.now();
    const sessionId = await this.prisma.$transaction(async (tx) => {
      await lock(tx, `iq:${childId}`);
      const age = await this.ageOf(tx, childId, now);
      if (age.status !== 'OK' || age.level === null || age.age === null) {
        const code = age.status === 'OK' ? 'AGE_OUT_OF_RANGE' : age.status;
        throw new ConflictException({ message: AGE_ERRORS[code], code });
      }
      await this.closeExpired(tx, childId, now);
      const open = await tx.iqSession.findFirst({
        where: { childId, status: { in: OPEN } },
        orderBy: { startedAt: 'desc' },
      });
      if (open && open.level === age.level) return open.id;
      // Yosh darajasi o'zgargan (sana tahrirlangan) — eski daraja savollari aralashmasin.
      if (open)
        await tx.iqSession.update({
          where: { id: open.id },
          data: { status: IqSessionStatus.ABANDONED },
        });

      const completed = await tx.iqSession.findMany({
        where: { childId, status: IqSessionStatus.COMPLETED },
        orderBy: { completedAt: 'desc' },
        select: { completedAt: true },
      });
      const next = nextAvailableAt(completed[0]?.completedAt ?? null);
      if (next && next > now) {
        throw new ConflictException({
          message: 'Retake is not available yet',
          code: 'RETAKE_TOO_SOON',
          nextAvailableAt: next.toISOString(),
        });
      }
      const form = formFor(age.level, completed.length);
      const items = await tx.iqItem.findMany({
        where: { active: true, forms: { has: form } },
        select: { id: true, externalId: true, kind: true, b: true },
      });
      if (items.length === 0)
        throw new NotFoundException({
          message: 'No items for this level yet',
          code: 'NO_ITEMS',
        });
      const created = await tx.iqSession.create({
        data: {
          childId,
          level: age.level,
          form,
          ageYears: age.age,
          itemIds: orderSessionItems(items),
          total: items.length,
          firstAttempt: completed.length === 0,
          startedAt: now,
        },
        select: { id: true },
      });
      return created.id;
    });
    return this.sessionView(childId, sessionId);
  }

  /** Javob (o'zgartirish mumkin); to'g'riligi QAYTARILMAYDI. */
  async answer(childId: string, sessionId: string, itemId: string, dto: IqAnswerDto) {
    const now = this.now();
    const outcome = await this.prisma.$transaction(
      async (
        tx,
      ): Promise<
        Outcome<{
          answeredCount: number;
          total: number;
          status: IqSessionStatus;
        }>
      > => {
        await lock(tx, `iq:${childId}`);
        const session = await ownSession(tx, childId, sessionId);
        if (OPEN.includes(session.status) && isExpired(session.startedAt, now)) {
          await tx.iqSession.update({
            where: { id: session.id },
            data: { status: IqSessionStatus.ABANDONED },
          });
          return { closed: true };
        }
        if (!OPEN.includes(session.status)) throw sessionClosed();
        const position = session.itemIds.indexOf(itemId);
        if (position < 0) throw notInSession();
        const item = await tx.iqItem.findUnique({
          where: { id: itemId },
          select: { answer: true, options: true },
        });
        if (!item) throw notInSession();
        if (!optionKeys(item.options).includes(dto.choice)) {
          throw new BadRequestException({
            message: 'Unknown option',
            code: 'INVALID_CHOICE',
          });
        }
        const data = {
          choice: dto.choice,
          correct: dto.choice === item.answer,
          durationMs: dto.durationMs ?? null,
          answeredAt: now,
        };
        await tx.iqAnswer.upsert({
          where: { sessionId_itemId: { sessionId, itemId } },
          create: { sessionId, itemId, position, ...data },
          update: data,
        });
        const status = session.status === IqSessionStatus.STARTED ? IqSessionStatus.IN_PROGRESS : session.status;
        if (status !== session.status)
          await tx.iqSession.update({
            where: { id: sessionId },
            data: { status },
          });
        return {
          closed: false,
          value: {
            answeredCount: await tx.iqAnswer.count({ where: { sessionId } }),
            total: session.total,
            status,
          },
        };
      },
    );
    if (outcome.closed) throw sessionClosed();
    return outcome.value;
  }

  /** Yakunlash — idempotent; hamma savolga javob kerak. Birinchi urinish normaga qo'shiladi. */
  async complete(childId: string, sessionId: string): Promise<IqSessionView> {
    const now = this.now();
    const outcome = await this.prisma.$transaction(async (tx): Promise<Outcome<null>> => {
      await lock(tx, `iq:${childId}`);
      const session = await ownSession(tx, childId, sessionId);
      if (session.status === IqSessionStatus.COMPLETED) return { closed: false, value: null };
      if (OPEN.includes(session.status) && isExpired(session.startedAt, now)) {
        await tx.iqSession.update({
          where: { id: session.id },
          data: { status: IqSessionStatus.ABANDONED },
        });
        return { closed: true };
      }
      if (session.status === IqSessionStatus.ABANDONED) throw sessionClosed();

      const answers = await tx.iqAnswer.findMany({
        where: { sessionId },
        select: { itemId: true, correct: true },
      });
      const correctById = new Map(answers.map((a) => [a.itemId, a.correct]));
      const remaining = session.itemIds.filter((id) => !correctById.has(id));
      if (remaining.length > 0) {
        throw new BadRequestException({
          message: 'Not all items are answered',
          code: 'UNANSWERED',
          remaining,
        });
      }
      const responses = session.itemIds.map((id) => (correctById.get(id) ? 1 : 0));
      const stored: StoredIqResult = {
        correct: responses.filter((r) => r === 1).length,
        total: responses.length,
        responses,
      };
      const age = await this.ageOf(tx, childId, now);
      const normGroup = age.age === null ? null : normGroupForAge(age.age);
      if (session.firstAttempt && normGroup) {
        await this.addToNorm(tx, session.itemIds, responses, normKey(session.form, normGroup));
      }
      await tx.iqSession.update({
        where: { id: sessionId },
        data: {
          status: IqSessionStatus.COMPLETED,
          completedAt: now,
          normGroup,
          result: stored as unknown as Prisma.InputJsonValue,
          scoringVersion: SCORING_VERSION,
        },
      });
      return { closed: false, value: null };
    });
    if (outcome.closed) throw sessionClosed();
    return this.sessionView(childId, sessionId);
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /**
   * Maktab IQ natijalari (docs/IQ-REJA.md §7): har bola uchun [since..hozir]
   * oralig'idagi ENG SO'NGGI yakunlangan sessiya — joriy normalar bilan baholangan.
   * Tarix umumiy: test qayerdan boshlanganidan qat'i nazar (maktab tayinlovi yoki o'zi).
   */
  async latestScored(childIds: string[], since: Date): Promise<Map<string, IqHistoryEntry>> {
    if (childIds.length === 0) return new Map();
    const sessions = await this.prisma.iqSession.findMany({
      where: { childId: { in: childIds }, status: IqSessionStatus.COMPLETED, completedAt: { gte: since } },
      orderBy: [{ completedAt: 'desc' }, { id: 'asc' }],
    });
    const latest = new Map<string, IqSession>();
    for (const s of sessions) if (!latest.has(s.childId)) latest.set(s.childId, s);
    const scored = new Map((await this.history([...latest.values()])).map((e) => [e.sessionId, e]));
    const result = new Map<string, IqHistoryEntry>();
    for (const [childId, s] of latest) {
      const entry = scored.get(s.id);
      if (entry) result.set(childId, entry);
    }
    return result;
  }

  private async ageOf(db: Db, childId: string, now: Date): Promise<IqAge> {
    const child = await db.child.findUnique({
      where: { id: childId },
      select: { birthDate: true, age: true },
    });
    if (!child) throw new NotFoundException('Child not found');
    return resolveIqAge(child, tashkentDay(now));
  }

  private async closeExpired(db: Db, childId: string, now: Date): Promise<void> {
    const cutoff = new Date(now.getTime() - SESSION_TTL_HOURS * 60 * 60 * 1000);
    await db.iqSession.updateMany({
      where: { childId, status: { in: OPEN }, startedAt: { lt: cutoff } },
      data: { status: IqSessionStatus.ABANDONED },
    });
  }

  private async normOf(db: Db, session: Pick<IqSession, 'form' | 'normGroup'>): Promise<NormStats> {
    if (!session.normGroup) return normStats(null);
    return normStats(await db.iqNorm.findUnique({ where: { group: normKey(session.form, session.normGroup) } }));
  }

  private async addToNorm(
    tx: Prisma.TransactionClient,
    itemIds: string[],
    responses: number[],
    group: string,
  ): Promise<void> {
    const items = await tx.iqItem.findMany({
      where: { id: { in: itemIds } },
      select: { id: true, b: true },
    });
    const bs = orderedBs(itemIds, items);
    const { theta } = eapAbility(
      responses.map((r, i) => ({ b: bs[i], correct: r === 1 })),
      designCenter(bs),
    );
    await lock(tx, `iq-norm:${group}`);
    const row = await tx.iqNorm.findUnique({ where: { group } });
    const next = welfordAdd(row ?? { n: 0, mean: 0, m2: 0 }, theta);
    await tx.iqNorm.upsert({
      where: { group },
      create: { group, ...next },
      update: next,
    });
  }

  private async history(sessions: IqSession[]): Promise<IqHistoryEntry[]> {
    if (sessions.length === 0) return [];
    const ids = [...new Set(sessions.flatMap((s) => s.itemIds))];
    const keyOf = (s: IqSession) => (s.normGroup ? normKey(s.form, s.normGroup) : null);
    const groups = [...new Set(sessions.map(keyOf).filter((g): g is string => g !== null))];
    const [items, norms] = await Promise.all([
      this.prisma.iqItem.findMany({
        where: { id: { in: ids } },
        select: { id: true, b: true, kind: true },
      }),
      this.prisma.iqNorm.findMany({ where: { group: { in: groups } } }),
    ]);
    const normByGroup = new Map(norms.map((n) => [n.group, normStats(n)]));
    return sessions.flatMap((s) => {
      const stored = parseStoredResult(s.result);
      if (!stored || !s.completedAt) return [];
      const key = keyOf(s);
      const norm = (key && normByGroup.get(key)) || normStats(null);
      return [
        {
          sessionId: s.id,
          completedAt: s.completedAt.toISOString(),
          level: s.level,
          result: scoreSession(s, stored, orderedBs(s.itemIds, items), norm, orderedKinds(s.itemIds, items)),
        },
      ];
    });
  }
}

// Maktab paneli → "Ota-onalar xabarlari": xodim FAQAT o'ziga yozilgan
// yozishmalarni ko'radi (direktor ham boshqalarnikini ko'rmaydi — psixolog va
// o'qituvchi suhbati maxfiy). Ruxsat: `inbox.parents`. Javob ota-onaga push
// bilan boradi; auditda faqat metama'lumot (matn yo'q).

import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { notFound } from '../common/school-errors';
import { paginate, parseOrThrow } from '../common/school-zod';
import { CommsPushService } from '../comms/comms-push.service';
import { replyPush } from './parent-connect.labels';
import { staffListQuerySchema, staffReplySchema, staffStatusSchema } from './parent-connect.schemas';
import { lastMessages, messageView, previewOf, studentLabel, threadMessages } from './parent-thread-views';

const threadInclude = {
  guardian: { select: { id: true, fullName: true, relation: true, userId: true, linkStatus: true } },
  student: { select: { id: true, firstName: true, lastName: true, class: { select: { name: true } } } },
} satisfies Prisma.SchoolParentThreadInclude;

type ThreadRow = Prisma.SchoolParentThreadGetPayload<{ include: typeof threadInclude }>;

@Injectable()
export class StaffThreadsService {
  private readonly logger = new Logger(StaffThreadsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
    private readonly audit: SchoolAuditService,
    private readonly push: CommsPushService,
  ) {}

  async list(actor: SchoolActor, raw: unknown) {
    assertCan(actor, 'inbox.parents');
    const query = parseOrThrow(staffListQuerySchema, raw ?? {});
    const where: Prisma.SchoolParentThreadWhereInput = {
      ...this.ownWhere(actor),
      ...(query.status !== 'ALL' && { status: query.status }),
      ...(query.search && {
        OR: [
          { guardian: { fullName: { contains: query.search, mode: 'insensitive' } } },
          { student: { lastName: { contains: query.search, mode: 'insensitive' } } },
          { student: { firstName: { contains: query.search, mode: 'insensitive' } } },
        ],
      }),
    };
    const [total, rows, counts] = await Promise.all([
      this.prisma.schoolParentThread.count({ where }),
      this.prisma.schoolParentThread.findMany({
        where,
        include: threadInclude,
        orderBy: [{ lastMessageAt: 'desc' }, { id: 'desc' }],
        skip: (query.page - 1) * query.limit,
        take: query.limit,
      }),
      this.summary(actor),
    ]);
    const last = await lastMessages(this.prisma, rows.map((r) => r.id));
    const items = rows.map((t) => ({ ...this.view(t), preview: previewOf(this.crypto, last.get(t.id)) }));
    return { ...paginate(items, total, { page: query.page, limit: query.limit }), counts };
  }

  /** Menyu nishoni: o'qilmagan yozishmalar va ochiqlari soni. */
  async summary(actor: SchoolActor) {
    assertCan(actor, 'inbox.parents');
    const own = this.ownWhere(actor);
    const [unread, open] = await Promise.all([
      this.prisma.schoolParentThread.count({ where: { ...own, staffUnread: { gt: 0 } } }),
      this.prisma.schoolParentThread.count({ where: { ...own, status: 'OPEN' } }),
    ]);
    return { unread, open };
  }

  async get(actor: SchoolActor, id: string) {
    assertCan(actor, 'inbox.parents');
    return this.detail(await this.own(actor, id));
  }

  async reply(actor: SchoolActor, id: string, body: unknown) {
    assertCan(actor, 'inbox.parents');
    const data = parseOrThrow(staffReplySchema, body ?? {});
    const thread = await this.own(actor, id);
    if (data.clientMessageId) {
      const dup = await this.prisma.schoolParentMessage.findUnique({
        where: { threadId_clientMessageId: { threadId: thread.id, clientMessageId: data.clientMessageId } },
        select: { id: true },
      });
      if (dup) return this.detail(await this.own(actor, id));
    }
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.schoolParentMessage.create({
        data: {
          threadId: thread.id,
          author: 'STAFF',
          staffId: actor.staffId,
          bodyEnc: this.crypto.encrypt(data.body),
          clientMessageId: data.clientMessageId ?? null,
          createdAt: now,
        },
      }),
      this.prisma.schoolParentThread.update({
        where: { id: thread.id },
        data: { lastAuthor: 'STAFF', lastMessageAt: now, staffReadAt: now, staffUnread: 0, parentUnread: { increment: 1 } },
      }),
    ]);
    await this.audit.write(actor, {
      module: 'MESSAGES',
      action: 'parentThread.reply',
      entityId: thread.id,
      summary: studentLabel(thread.student),
      params: { name: studentLabel(thread.student) },
    });
    await this.notifyParent(actor, thread, data.body);
    return this.detail(await this.own(actor, id));
  }

  async markRead(actor: SchoolActor, id: string) {
    assertCan(actor, 'inbox.parents');
    const thread = await this.own(actor, id);
    const now = new Date();
    await this.prisma.schoolParentThread.update({ where: { id: thread.id }, data: { staffReadAt: now, staffUnread: 0 } });
    return { id: thread.id, readAt: now.toISOString() };
  }

  async setStatus(actor: SchoolActor, id: string, body: unknown) {
    assertCan(actor, 'inbox.parents');
    const { status } = parseOrThrow(staffStatusSchema, body ?? {});
    const thread = await this.own(actor, id);
    if (thread.status !== status) {
      await this.prisma.schoolParentThread.update({
        where: { id: thread.id },
        data: { status, resolvedAt: status === 'RESOLVED' ? new Date() : null },
      });
      await this.audit.write(actor, {
        module: 'MESSAGES',
        action: status === 'RESOLVED' ? 'parentThread.resolve' : 'parentThread.reopen',
        entityId: thread.id,
        summary: studentLabel(thread.student),
        params: { name: studentLabel(thread.student) },
      });
    }
    return this.detail(await this.own(actor, id));
  }

  // ── ichki ───────────────────────────────────────────────────────────

  private ownWhere(actor: SchoolActor): Prisma.SchoolParentThreadWhereInput {
    return { schoolId: actor.schoolId, staffId: actor.staffId };
  }

  private async own(actor: SchoolActor, id: string): Promise<ThreadRow> {
    const thread = await this.prisma.schoolParentThread.findFirst({ where: { id, ...this.ownWhere(actor) }, include: threadInclude });
    if (!thread) throw notFound(id);
    return thread;
  }

  private view(t: ThreadRow) {
    return {
      id: t.id,
      status: t.status,
      guardian: { id: t.guardian.id, fullName: t.guardian.fullName, relation: t.guardian.relation },
      student: { id: t.student.id, name: studentLabel(t.student), className: t.student.class?.name ?? '' },
      lastAuthor: t.lastAuthor,
      lastMessageAt: t.lastMessageAt.toISOString(),
      unread: t.staffUnread,
      createdAt: t.createdAt.toISOString(),
    };
  }

  private async detail(thread: ThreadRow) {
    const messages = await threadMessages(this.prisma, thread.id);
    return {
      ...this.view(thread),
      parentReadAt: thread.parentReadAt?.toISOString() ?? null,
      messages: messages.map((m) => messageView(this.crypto, m, thread)),
    };
  }

  /** Ota-onaga push (ilovasi bo'lsa). Javob saqlangan — xato faqat log. */
  private async notifyParent(actor: SchoolActor, thread: ThreadRow, body: string) {
    const userId = thread.guardian.linkStatus === 'LINKED' ? thread.guardian.userId : null;
    if (!userId) return;
    try {
      const school = await this.push.schoolLabel(thread.schoolId);
      await this.push.sendOne(userId, (lang) => replyPush(lang, { threadId: thread.id, school, role: actor.role, body }));
    } catch (err) {
      this.logger.warn(`ota-ona javob push xatosi: ${err instanceof Error ? err.message : 'noma\'lum'}`);
    }
  }
}

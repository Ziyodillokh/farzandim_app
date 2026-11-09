// Parvoz Parents → "Maktab bilan bog'lanish": kontaktlar, yozishmalar, xabar
// yuborish. Ota-ona faqat O'Z vasiy yozuvi (`SchoolGuardian.userId`, LINKED)
// orqali bog'langan o'quvchi nomidan yozadi; begona o'quvchi / yozishma — 404.
// Xabar faqat shu o'quvchining kontaktlar ro'yxatidagi xodimga ketadi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { conflict, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { buildContacts, ContactStaff, ContactThreadInfo } from './parent-contacts';
import {
  contactsQuerySchema,
  PARENT_MESSAGES_PER_DAY,
  PARENT_NEW_THREADS_PER_DAY,
  parentMessageSchema,
  parentStartSchema,
  ParentTopic,
} from './parent-connect.schemas';
import { lastMessages, messageView, previewOf, rateLimited, studentLabel, threadMessages } from './parent-thread-views';

const DAY_MS = 24 * 3_600_000;
const pairKey = (guardianId: string, studentId: string) => `${guardianId}:${studentId}`;
/** Ota-ona "Murojaatlarim" ro'yxati chegarasi. */
const PARENT_THREADS_LIMIT = 100;

const staffSelect = {
  id: true,
  fullName: true,
  role: true,
  position: true,
  active: true,
  username: true,
  passwordHash: true,
  classes: { select: { classId: true } },
} satisfies Prisma.SchoolStaffSelect;

type StaffRow = Prisma.SchoolStaffGetPayload<{ select: typeof staffSelect }>;

const toContactStaff = (s: StaffRow): ContactStaff => ({
  id: s.id,
  fullName: s.fullName,
  role: s.role,
  position: s.position,
  active: s.active,
  hasAccount: Boolean(s.username && s.passwordHash),
  classIds: s.classes.map((c) => c.classId),
});

const threadInclude = {
  staff: { select: staffSelect },
  student: {
    select: {
      id: true,
      firstName: true,
      lastName: true,
      classId: true,
      archived: true,
      class: { select: { name: true, homeroomStaffId: true } },
    },
  },
  school: { select: { name: true, shortName: true } },
} satisfies Prisma.SchoolParentThreadInclude;

type ThreadRow = Prisma.SchoolParentThreadGetPayload<{ include: typeof threadInclude }>;

@Injectable()
export class ParentThreadsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** O'quvchi bo'yicha maktab kontaktlari (guruhlangan tartibda) va ular bilan yozishma holati. */
  async contacts(userId: string, query: unknown) {
    const { studentId } = parseOrThrow(contactsQuerySchema, query ?? {});
    const { guardian, student } = await this.link(userId, studentId);
    const [staff, threads] = await Promise.all([
      this.schoolStaff(student.schoolId),
      this.prisma.schoolParentThread.findMany({
        where: { guardianId: guardian.id, studentId: student.id },
        select: { id: true, staffId: true, parentUnread: true, lastMessageAt: true },
      }),
    ]);
    const byStaff = new Map<string, ContactThreadInfo>(
      threads.map((t) => [t.staffId, { threadId: t.id, unread: t.parentUnread, lastMessageAt: t.lastMessageAt }]),
    );
    return {
      student: {
        id: student.id,
        name: studentLabel(student),
        className: student.class?.name ?? '',
        schoolName: student.school.shortName || student.school.name,
      },
      contacts: buildContacts({
        classId: student.classId,
        homeroomStaffId: student.class?.homeroomStaffId ?? null,
        staff: staff.map(toContactStaff),
        threads: byStaff,
      }),
    };
  }

  /** "Murojaatlarim": barcha yozishmalar (yangisi oldin) va jami o'qilmaganlar. */
  async list(userId: string) {
    const [found, pairs] = await Promise.all([
      this.prisma.schoolParentThread.findMany({
        where: this.mineWhere(userId),
        include: threadInclude,
        orderBy: [{ lastMessageAt: 'desc' }, { id: 'desc' }],
        take: PARENT_THREADS_LIMIT,
      }),
      this.linkedPairs(userId),
    ]);
    const rows = found.filter((t) => pairs.has(pairKey(t.guardianId, t.studentId)));
    const last = await lastMessages(this.prisma, rows.map((r) => r.id));
    const items = rows.map((t) => ({ ...this.threadView(t), preview: previewOf(this.crypto, last.get(t.id)) }));
    return { items, unread: items.reduce((sum, t) => sum + t.unread, 0) };
  }

  async get(userId: string, threadId: string) {
    const thread = await this.mine(userId, threadId);
    return this.detail(thread);
  }

  /** Yangi xabar xodimga: yozishma bo'lmasa ochiladi, hal qilingan bo'lsa qayta ochiladi. */
  async start(userId: string, body: unknown) {
    const data = parseOrThrow(parentStartSchema, body ?? {});
    const { guardian, student } = await this.link(userId, data.studentId);
    const contacts = await this.contactsOf(student);
    if (!contacts.some((c) => c.staffId === data.staffId)) throw notFound(data.staffId);
    const existing = await this.prisma.schoolParentThread.findUnique({
      where: { guardianId_staffId_studentId: { guardianId: guardian.id, staffId: data.staffId, studentId: student.id } },
      select: { id: true },
    });
    if (!existing) await this.assertNewThreadAllowed(userId);
    const threadId =
      existing?.id ??
      (
        await this.prisma.schoolParentThread.upsert({
          where: { guardianId_staffId_studentId: { guardianId: guardian.id, staffId: data.staffId, studentId: student.id } },
          create: { schoolId: student.schoolId, staffId: data.staffId, studentId: student.id, guardianId: guardian.id },
          update: {},
          select: { id: true },
        })
      ).id;
    await this.append(userId, threadId, data.topic, data.body, data.clientMessageId);
    return this.detail(await this.mine(userId, threadId));
  }

  /** Mavjud yozishmaga xabar. Xodim endi kontakt emas (faolsizlangan, sinfdan olingan) — 409. */
  async send(userId: string, threadId: string, body: unknown) {
    const data = parseOrThrow(parentMessageSchema, body ?? {});
    const thread = await this.mine(userId, threadId);
    if (!this.threadView(thread).available) throw conflict('contact unavailable');
    await this.append(userId, thread.id, data.topic ?? null, data.body, data.clientMessageId);
    return this.detail(await this.mine(userId, threadId));
  }

  /** Ota-ona yozishmani ochdi — xodim javoblari o'qildi. */
  async markRead(userId: string, threadId: string) {
    const thread = await this.mine(userId, threadId);
    const now = new Date();
    await this.prisma.schoolParentThread.update({ where: { id: thread.id }, data: { parentReadAt: now, parentUnread: 0 } });
    return { id: thread.id, readAt: now.toISOString() };
  }

  // ── ichki ───────────────────────────────────────────────────────────

  private async append(userId: string, threadId: string, topic: ParentTopic | null, text: string, clientMessageId?: string) {
    if (clientMessageId) {
      const dup = await this.prisma.schoolParentMessage.findUnique({
        where: { threadId_clientMessageId: { threadId, clientMessageId } },
        select: { id: true },
      });
      if (dup) return;
    }
    await this.assertMessageAllowed(userId);
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.schoolParentMessage.create({
        data: { threadId, author: 'PARENT', topic, bodyEnc: this.crypto.encrypt(text), clientMessageId: clientMessageId ?? null, createdAt: now },
      }),
      this.prisma.schoolParentThread.update({
        where: { id: threadId },
        data: {
          status: 'OPEN',
          resolvedAt: null,
          lastAuthor: 'PARENT',
          lastMessageAt: now,
          parentReadAt: now,
          parentUnread: 0,
          staffUnread: { increment: 1 },
        },
      }),
    ]);
  }

  private async assertNewThreadAllowed(userId: string) {
    const since = new Date(Date.now() - DAY_MS);
    const created = await this.prisma.schoolParentThread.count({ where: { guardian: { userId }, createdAt: { gte: since } } });
    if (created >= PARENT_NEW_THREADS_PER_DAY) throw rateLimited('threads per day');
  }

  private async assertMessageAllowed(userId: string) {
    const since = new Date(Date.now() - DAY_MS);
    const sent = await this.prisma.schoolParentMessage.count({
      where: { author: 'PARENT', createdAt: { gte: since }, thread: { guardian: { userId } } },
    });
    if (sent >= PARENT_MESSAGES_PER_DAY) throw rateLimited('messages per day');
  }

  /** Ota-onaning bog'langan (arxivlanmagan) o'quvchisi — eng eski vasiy yozuvi orqali. */
  private async link(userId: string, studentId: string) {
    const link = await this.prisma.schoolStudentGuardian.findFirst({
      where: {
        studentId,
        guardian: { userId, linkStatus: 'LINKED', school: { status: 'ACTIVE' } },
        student: { archived: false },
      },
      include: {
        guardian: { select: { id: true } },
        student: {
          select: {
            id: true,
            schoolId: true,
            classId: true,
            firstName: true,
            lastName: true,
            class: { select: { name: true, homeroomStaffId: true } },
            school: { select: { name: true, shortName: true } },
          },
        },
      },
      orderBy: { guardian: { createdAt: 'asc' } },
    });
    if (!link) throw notFound(studentId);
    return link;
  }

  /** Yozishma ota-onaniki: vasiy yozuvi LINKED va o'quvchi bilan bog'lanish hali bor. */
  private mineWhere(userId: string): Prisma.SchoolParentThreadWhereInput {
    return {
      guardian: { userId, linkStatus: 'LINKED', school: { status: 'ACTIVE' } },
      student: { archived: false },
    };
  }

  /** Vasiy ↔ o'quvchi bog'lanishlari (o'quvchi vasiydan uzilsa, eski yozishma ko'rinmaydi). */
  private async linkedPairs(userId: string): Promise<Set<string>> {
    const links = await this.prisma.schoolStudentGuardian.findMany({
      where: { guardian: { userId, linkStatus: 'LINKED' } },
      select: { guardianId: true, studentId: true },
    });
    return new Set(links.map((l) => pairKey(l.guardianId, l.studentId)));
  }

  private async mine(userId: string, threadId: string): Promise<ThreadRow> {
    const thread = await this.prisma.schoolParentThread.findFirst({
      where: { id: threadId, ...this.mineWhere(userId) },
      include: threadInclude,
    });
    if (!thread) throw notFound(threadId);
    const linked = await this.prisma.schoolStudentGuardian.count({
      where: { guardianId: thread.guardianId, studentId: thread.studentId },
    });
    if (linked === 0) throw notFound(threadId);
    return thread;
  }

  private schoolStaff(schoolId: string) {
    return this.prisma.schoolStaff.findMany({
      where: { schoolId, active: true, role: { not: 'DUTY' } },
      select: staffSelect,
    });
  }

  private async contactsOf(student: { schoolId: string; classId: string | null; class: { homeroomStaffId: string | null } | null }) {
    const staff = await this.schoolStaff(student.schoolId);
    return buildContacts({
      classId: student.classId,
      homeroomStaffId: student.class?.homeroomStaffId ?? null,
      staff: staff.map(toContactStaff),
      threads: new Map(),
    });
  }

  private threadView(t: ThreadRow) {
    return {
      id: t.id,
      status: t.status,
      schoolName: t.school.shortName || t.school.name,
      staff: { id: t.staff.id, fullName: t.staff.fullName, role: t.staff.role, position: t.staff.position },
      student: { id: t.student.id, name: studentLabel(t.student), className: t.student.class?.name ?? '' },
      lastAuthor: t.lastAuthor,
      lastMessageAt: t.lastMessageAt.toISOString(),
      unread: t.parentUnread,
      // Xodim hali shu o'quvchining kontakti (faol, hisobi bor, sinf doirasida).
      available:
        buildContacts({
          classId: t.student.classId,
          homeroomStaffId: t.student.class?.homeroomStaffId ?? null,
          staff: [toContactStaff(t.staff)],
          threads: new Map(),
        }).length > 0,
    };
  }

  private async detail(thread: ThreadRow) {
    const messages = await threadMessages(this.prisma, thread.id);
    return {
      ...this.threadView(thread),
      staffReadAt: thread.staffReadAt?.toISOString() ?? null,
      messages: messages.map((m) => messageView(this.crypto, m, thread)),
    };
  }
}

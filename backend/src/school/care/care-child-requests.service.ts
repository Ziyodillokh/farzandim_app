// Parvoz Growth bola ilovasi ↔ psixologga murojaat: yaratish (idempotent, kuniga 5 ta), ro'yxat,
// tafsilot (xodim xabarlari o'qilgan deb belgilanadi) va yozishmaga xabar (kuniga 30 ta).
// Bola faqat O'Z murojaatlarini ko'radi (boshqasi — 404). Ichki eslatmalar bolaga HECH QACHON
// qaytmaydi. Matnlar bazada shifrlangan (`SchoolCryptoService`).

import { ConflictException, HttpException, HttpStatus, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, SchoolCareRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { EnrolledStudent, findEnrolledStudent, requireEnrolledStudent } from '../common/child-student';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { parseOrThrow } from '../common/school-zod';
import { CareNotifyService } from './care-notify.service';
import { buildContact } from './care-settings';
import { CareSettingsService } from './care-settings.service';
import { stageOf, threadOf, toMessageView } from './care-thread';
import { careChildMessageSchema, careRequestInputSchema } from './care.schemas';

/** Bitta bola kuniga ko'pi bilan shuncha murojaat yubora oladi (takroriy `clientRequestId` hisoblanmaydi). */
export const MAX_REQUESTS_PER_DAY = 5;
/** Bitta bola kuniga ko'pi bilan shuncha xabar yozishi mumkin (boshlang'ich xabarlar ham hisobda). */
export const MAX_CHILD_MESSAGES_PER_DAY = 30;
const LIST_LIMIT = 20;

type Tx = Prisma.TransactionClient;

/**
 * Bola faqat O'Z murojaatlarini ko'radi: o'quvchi yozuvi + shu bola profili (`childId`). O'quvchi yozuvi
 * boshqa bola profiliga qayta bog'lansa, avvalgi bolaning yozishmasi yangisiga ko'rinmaydi.
 * Eski qatorlarda (`childId` yo'q — kimniki ekani noma'lum) RO'YXATDA faqat holat ko'rinadi: matn, yozishma,
 * xabar yozish va push yo'q (qarang `detailView`, `addMessage`, `CareRequestsService.childUserOf`).
 */
const ownedBy = (student: Pick<EnrolledStudent, 'studentId' | 'childId'>) => ({
  studentId: student.studentId,
  OR: [{ childId: student.childId }, { childId: null }],
});

const tooMany = (message: string) => new HttpException({ code: 'TOO_MANY_REQUESTS', message }, HttpStatus.TOO_MANY_REQUESTS);
const notFound = () => new NotFoundException({ code: 'REQUEST_NOT_FOUND', message: 'Request not found' });

@Injectable()
export class CareChildRequestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
    private readonly settings: CareSettingsService,
    private readonly notify: CareNotifyService,
  ) {}

  /** Murojaat + birinchi bola xabari. Bir xil `clientRequestId` — mavjud murojaat (dublikat va limit hisobisiz). */
  async create(childUserId: string, input: unknown) {
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const data = parseOrThrow(careRequestInputSchema, input);
    const request = await this.prisma.$transaction(async (tx) => {
      // Bir bolaning parallel yuborishlari (murojaat va xabar) navbat bilan: limitlar va idempotentlik aniq.
      await this.lock(tx, student.studentId);
      if (data.clientRequestId) {
        const existing = await tx.schoolCareRequest.findFirst({
          where: { ...ownedBy(student), clientRequestId: data.clientRequestId },
        });
        if (existing) return existing;
      }
      const today = await tx.schoolCareRequest.count({
        where: { studentId: student.studentId, createdAt: { gte: tashkentDayStart(tashkentDay()) } },
      });
      if (today >= MAX_REQUESTS_PER_DAY) throw tooMany('Daily request limit reached');
      const state = await this.settings.load(student.schoolId, tx);
      const now = new Date();
      const created = await tx.schoolCareRequest.create({
        data: {
          schoolId: student.schoolId,
          studentId: student.studentId,
          classId: student.classId,
          topic: data.topic,
          urgency: data.urgency,
          messageEnc: this.crypto.encrypt(data.message),
          clientRequestId: data.clientRequestId ?? null,
          childId: student.childId,
          assignedStaffId: state.settings.psychologistStaffId,
          lastMessageAt: now,
          createdAt: now,
          messages: { create: { author: 'CHILD', bodyEnc: this.crypto.encrypt(data.message), createdAt: now } },
        },
      });
      if (created.urgency === 'URGENT') {
        const targets = [state.settings.psychologistStaffId, state.settings.deputyStaffId].filter((id): id is string => id !== null);
        await this.notify.urgentCreated(tx, created, targets, student.className);
      }
      return created;
    });
    return this.detailView(student.schoolId, request);
  }

  /** Bolaning o'z murojaatlari — matnsiz: holat, bosqich va o'qilmagan xodim xabarlari soni. */
  async list(childUserId: string) {
    const student = await findEnrolledStudent(this.prisma, childUserId);
    if (!student) return [];
    const rows = await this.prisma.schoolCareRequest.findMany({
      where: ownedBy(student),
      orderBy: { createdAt: 'desc' },
      take: LIST_LIMIT,
    });
    const unread = await this.prisma.schoolCareMessage.groupBy({
      by: ['requestId'],
      where: { requestId: { in: rows.map((r) => r.id) }, author: 'STAFF', readByChildAt: null },
      _count: { _all: true },
    });
    const unreadOf = new Map(unread.map((u) => [u.requestId, u._count._all]));
    return rows.map((r) => ({
      id: r.id,
      topic: r.topic,
      urgency: r.urgency,
      status: r.status,
      stage: stageOf(r),
      createdAt: r.createdAt.toISOString(),
      meetingAt: r.meetingAt?.toISOString() ?? null,
      lastMessageAt: (r.lastMessageAt ?? r.createdAt).toISOString(),
      // Eski murojaatda xodim xabarlari bolaga ko'rsatilmaydi — o'qilmagan hisobi ham 0.
      unread: r.childId === null ? 0 : (unreadOf.get(r.id) ?? 0),
    }));
  }

  /** Murojaat tafsiloti; xodim xabarlari o'qildi deb belgilanadi. Boshqa bolaning murojaati — 404. */
  async detail(childUserId: string, id: string) {
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const request = await this.prisma.schoolCareRequest.findFirst({ where: { id, ...ownedBy(student) } });
    if (!request) throw notFound();
    if (request.childId !== null) {
      await this.prisma.schoolCareMessage.updateMany({
        where: { requestId: id, author: 'STAFF', readByChildAt: null },
        data: { readByChildAt: new Date() },
      });
    }
    return this.detailView(student.schoolId, request);
  }

  /** Yozishmaga bola xabari. Yopilgan murojaat — 409; kuniga 30 ta; `clientMessageId` takrori — o'sha xabar. */
  async addMessage(childUserId: string, id: string, input: unknown) {
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const data = parseOrThrow(careChildMessageSchema, input);
    const message = await this.prisma.$transaction(async (tx) => {
      await this.lock(tx, student.studentId);
      // Murojaat qatori qulflanadi: xodim "hal qilindi" qilayotganda xabar o'tib ketmasin.
      const rows = await tx.$queryRaw<{ status: string }[]>`
        SELECT status FROM school_care_requests
        WHERE id = ${id} AND student_id = ${student.studentId} AND child_id = ${student.childId} FOR UPDATE`;
      const request = rows[0];
      if (!request) throw notFound();
      if (data.clientMessageId) {
        const existing = await tx.schoolCareMessage.findUnique({
          where: { requestId_clientMessageId: { requestId: id, clientMessageId: data.clientMessageId } },
        });
        if (existing) return existing;
      }
      if (request.status === 'RESOLVED') {
        throw new ConflictException({ code: 'REQUEST_CLOSED', message: 'Request is closed' });
      }
      const today = await tx.schoolCareMessage.count({
        where: { author: 'CHILD', createdAt: { gte: tashkentDayStart(tashkentDay()) }, request: { studentId: student.studentId } },
      });
      if (today >= MAX_CHILD_MESSAGES_PER_DAY) throw tooMany('Daily message limit reached');
      const now = new Date();
      const created = await tx.schoolCareMessage.create({
        data: { requestId: id, author: 'CHILD', bodyEnc: this.crypto.encrypt(data.text), clientMessageId: data.clientMessageId ?? null, createdAt: now },
      });
      await tx.schoolCareRequest.update({ where: { id }, data: { lastMessageAt: now } });
      return created;
    });
    return toMessageView(message, { decrypt: (t) => this.crypto.decrypt(t), nameOf: () => null });
  }

  /** Kim javob beradi va hozir ish vaqtimi (bayramlar yopiq hisoblanadi). */
  async contact(childUserId: string, now: Date = new Date()) {
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const state = await this.settings.load(student.schoolId);
    const [people, holidays] = await Promise.all([
      this.settings.people(student.schoolId, state),
      state.configured ? this.settings.holidays(student.schoolId, tashkentDay(now)) : new Set<string>(),
    ]);
    return buildContact({ ...state, psychologist: people.psychologist, deputy: people.deputy, holidays, now });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async detailView(schoolId: string, request: SchoolCareRequest) {
    // Eski murojaat (`childId` yo'q): yozuvi qaysi bolaniki ekani noma'lum — matn HECH QAYSI bolaga qaytmaydi.
    const legacy = request.childId === null;
    const rows = legacy ? [] : await this.prisma.schoolCareMessage.findMany({ where: { requestId: request.id } });
    const state = await this.settings.load(schoolId);
    const people = await this.settings.people(schoolId, state, rows.flatMap((m) => (m.staffId ? [m.staffId] : [])));
    const handler =
      request.escalatedAt && people.deputy
        ? { name: people.deputy.name, isDeputy: true }
        : people.psychologist
          ? { name: people.psychologist.name, isDeputy: false }
          : null;
    return {
      id: request.id,
      urgency: request.urgency,
      status: request.status,
      stage: stageOf(request),
      createdAt: request.createdAt.toISOString(),
      openedAt: request.openedAt?.toISOString() ?? null,
      repliedAt: request.repliedAt?.toISOString() ?? null,
      resolvedAt: request.resolvedAt?.toISOString() ?? null,
      meetingAt: request.meetingAt?.toISOString() ?? null,
      handler,
      messages: legacy ? [] : threadOf(request, rows, { decrypt: (t) => this.crypto.decrypt(t), nameOf: people.nameOf }),
    };
  }

  private async lock(tx: Tx, studentId: string): Promise<void> {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`care-child:${studentId}`}, 0))`;
  }
}

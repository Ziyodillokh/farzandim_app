// Bola ovozi murojaatlari — FAQAT psixolog (`care.individual`). Matn va
// eslatmalar bazada shifrlangan. Audit yozuvlarida bola ismi, sinfi, murojaat
// ID'si yoki matni YO'Q (audit jurnalini direktor / admin ham ko'radi).
// Birinchi ochgan xodim (`openedAt`) bir marta, poyga xavfsiz yoziladi; xodim javobi
// bolaga neytral push yuboradi (xato javobni yiqitmaydi).

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolCareRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { matchesSearch } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { CareNotifyService } from './care-notify.service';
import { CareRequestRows } from './care-request-rows';
import { toMessageView } from './care-thread';
import { CARE_REQUEST_STATUSES, careMeetingSchema, careNoteSchema, careRequestFilterSchema, careStaffMessageSchema, careStatusSchema } from './care.schemas';

export interface CareNote {
  at: string;
  byStaffId: string;
  text: string;
}

type Tx = Prisma.TransactionClient;

const REQUEST_AUDIT = {
  open: ['care.request.open', 'Bola ovozi: murojaat ochildi'],
  reply: ['care.request.reply', 'Bola ovozi: murojaatga javob yozildi'],
  status: ['care.request.status', 'Bola ovozi: murojaat holati yangilandi'],
  note: ['care.request.note', 'Bola ovozi: ichki eslatma qo\'shildi'],
  meeting: ['care.request.meeting', 'Bola ovozi: suhbat vaqti belgilandi'],
  protocol: ['care.protocol.activate', 'Bola ovozi: himoya protokoli ishga tushirildi'],
} as const;

/** "YYYY-MM-DDTHH:MM" (vaqt mintaqasisiz) — Toshkent vaqti sifatida o'qiladi. */
export function parseMeetingAt(value: string): Date {
  return /[zZ]|[+-]\d{2}:?\d{2}$/.test(value) ? new Date(value) : new Date(`${value.length === 16 ? `${value}:00` : value}+05:00`);
}

/** Shoshilinch va yopilmagan — tepada, keyin yangilari. */
const rank = (r: SchoolCareRequest) => (r.urgency === 'URGENT' && r.status !== 'RESOLVED' ? 0 : 1);

@Injectable()
export class CareRequestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
    private readonly audit: SchoolAuditService,
    private readonly rowsOf: CareRequestRows,
    private readonly notify: CareNotifyService,
  ) {}

  async listRequests(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'care.individual');
    const filter = parseOrThrow(careRequestFilterSchema, query);
    const requests = await this.prisma.schoolCareRequest.findMany({ where: { schoolId: actor.schoolId } });
    const rows = (await this.rowsOf.rows(actor.schoolId, requests)).sort(
      (a, b) => rank(a.raw) - rank(b.raw) || b.raw.createdAt.getTime() - a.raw.createdAt.getTime(),
    );
    const searched = rows.filter(
      (r) =>
        (!filter.urgency || r.view.urgency === filter.urgency) &&
        (!filter.search || matchesSearch(`${r.view.studentName} ${r.view.className} ${r.view.message}`, filter.search)),
    );
    const counts = Object.fromEntries(CARE_REQUEST_STATUSES.map((s) => [s, searched.filter((r) => r.view.status === s).length]));
    const items = (filter.status ? searched.filter((r) => r.view.status === filter.status) : searched).map((r) => r.view);
    return { items, counts };
  }

  /**
   * Tafsilot. Murojaatni BIRINCHI ko'rgan `care.individual` xodimi `openedAt` / `openedByStaffId`
   * ni yozadi (faqat bir marta — shartli UPDATE poygada bitta g'olibni beradi); bolaning xabarlari
   * xodim tomonidan o'qilgan deb belgilanadi.
   */
  async getRequest(actor: SchoolActor, id: string) {
    assertCan(actor, 'care.individual');
    await this.find(actor.schoolId, id);
    const request = await this.prisma.$transaction(async (tx) => {
      await this.markOpened(tx, actor, id);
      await tx.schoolCareMessage.updateMany({ where: { requestId: id, author: 'CHILD', readByStaffAt: null }, data: { readByStaffAt: new Date() } });
      return tx.schoolCareRequest.findFirstOrThrow({ where: { id, schoolId: actor.schoolId } });
    });
    const [row] = await this.rowsOf.rows(actor.schoolId, [request]);
    const notes = this.notesOf(request);
    const names = await this.rowsOf.staffNames(actor.schoolId, notes.map((n) => n.byStaffId));
    return {
      ...row!.view,
      resolvedAt: request.resolvedAt?.toISOString() ?? null,
      openedBy: row!.openedBy,
      messages: await this.rowsOf.thread(actor.schoolId, request),
      notes: [...notes].sort((a, b) => Date.parse(a.at) - Date.parse(b.at)).map((n) => ({ ...n, byName: names.get(n.byStaffId) ?? '—' })),
      notified: request.protocolActivated ? await this.protocolRecipients(actor.schoolId) : [],
    };
  }

  async updateRequestStatus(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.individual');
    const { status } = parseOrThrow(careStatusSchema, input);
    return this.mutate(actor, id, REQUEST_AUDIT.status, (request) => {
      if (status === 'SCHEDULED' && !request.meetingAt) throw invalid('meetingAt: errors.form.required');
      // Hal qilindi — `resolvedAt` (birinchi marta); qayta ochilsa — tozalanadi.
      return { status, resolvedAt: status === 'RESOLVED' ? (request.resolvedAt ?? new Date()) : null };
    });
  }

  async addRequestNote(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.individual');
    const { text } = parseOrThrow(careNoteSchema, input);
    return this.mutate(actor, id, REQUEST_AUDIT.note, (request) => ({
      notesEnc: this.crypto.encryptJson([...this.notesOf(request), { at: new Date().toISOString(), byStaffId: actor.staffId, text }]),
    }));
  }

  /** Suhbat vaqti. Vaqt o'zgargan bo'lsa bolaga NEYTRAL push (tranzaksiyadan KEYIN; xatosi yiqitmaydi). */
  async scheduleMeeting(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.individual');
    const { meetingAt } = parseOrThrow(careMeetingSchema, input);
    const at = parseMeetingAt(meetingAt);
    let notifyUserId: string | null = null;
    const view = await this.mutate(actor, id, REQUEST_AUDIT.meeting, async (request, tx) => {
      if (request.meetingAt?.getTime() !== at.getTime()) notifyUserId = await this.childUserOf(tx, request);
      return { meetingAt: at, ...(request.status !== 'RESOLVED' && { status: 'SCHEDULED' }) };
    });
    await this.notify.notifyChildOfReply(notifyUserId, id);
    return view;
  }

  /**
   * Himoya protokoli (faqat shoshilinch murojaat): direktor va navbatchi xabardor
   * qilinadi — matn va bola ismi ularga BERILMAYDI; shikoyat qilingan shaxsga hech narsa.
   */
  async activateProtocol(actor: SchoolActor, id: string) {
    assertCan(actor, 'care.individual');
    const recipients = await this.protocolRecipients(actor.schoolId);
    const who = recipients.map((r) => `${r.name} (${r.role === 'DIRECTOR' ? 'direktor' : 'navbatchi'})`).join(', ');
    return this.mutate(actor, id, REQUEST_AUDIT.protocol, async (request, tx) => {
      if (request.urgency !== 'URGENT') throw invalid('urgency');
      if (request.protocolActivated) throw conflict('protocol already active');
      const note: CareNote = {
        at: new Date().toISOString(),
        byStaffId: actor.staffId,
        text: `Himoya protokoli ishga tushirildi. Xabardor qilindi: ${who}. Murojaat matni va bolaning ismi ularga berilmadi; shikoyat qilingan shaxsga hech narsa yuborilmadi.`,
      };
      // Xavfsizlik signali: ism, sinf yoki matn YO'Q — faqat "e'tibor kerak" fakti.
      await tx.schoolStaffNotification.create({
        data: { schoolId: actor.schoolId, kind: 'SAFETY_SIGNAL', roles: ['DIRECTOR', 'DUTY'], classIds: [], params: {} },
      });
      return {
        protocolActivated: true,
        ...(request.status === 'NEW' && { status: 'IN_PROGRESS' }),
        notesEnc: this.crypto.encryptJson([...this.notesOf(request), note]),
      };
    });
  }

  /**
   * Bolaga javob. Hal qilingan murojaat — 409. Birinchi javob `repliedAt` ni, har javob
   * `lastMessageAt` ni yozadi; `NEW` → `IN_PROGRESS`. Audit va push'da matn YO'Q; push
   * tranzaksiyadan KEYIN yuboriladi va xatosi javobni yiqitmaydi.
   */
  async reply(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.individual');
    const { text } = parseOrThrow(careStaffMessageSchema, input);
    const { message, childUserId } = await this.locked(actor, id, async (request, tx) => {
      if (request.status === 'RESOLVED') throw conflict('REQUEST_CLOSED');
      const now = new Date();
      const created = await tx.schoolCareMessage.create({
        data: { requestId: id, author: 'STAFF', staffId: actor.staffId, bodyEnc: this.crypto.encrypt(text), createdAt: now, readByStaffAt: now },
      });
      const leavesNew = request.status === 'NEW';
      await tx.schoolCareRequest.update({
        where: { id },
        data: {
          repliedAt: request.repliedAt ?? now,
          lastMessageAt: now,
          ...(leavesNew && { status: 'IN_PROGRESS' }),
          ...(!request.openedAt && { openedAt: now, openedByStaffId: actor.staffId }),
        },
      });
      await this.afterChange(tx, actor, request, REQUEST_AUDIT.reply, leavesNew);
      return { message: created, childUserId: await this.childUserOf(tx, request) };
    });
    await this.notify.notifyChildOfReply(childUserId, id);
    return toMessageView(message, { decrypt: (t) => this.crypto.decrypt(t), nameOf: () => actor.name });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async find(schoolId: string, id: string) {
    const request = await this.prisma.schoolCareRequest.findFirst({ where: { id, schoolId } });
    if (!request) throw notFound(id);
    return request;
  }

  private notesOf(request: SchoolCareRequest): CareNote[] {
    return request.notesEnc ? this.crypto.decryptJson<CareNote[]>(request.notesEnc) : [];
  }

  /**
   * Push oluvchisi: murojaatni yozgan bola profili (`childId`). Eski murojaatda (`childId` yo'q) bola
   * ilovasi yozishmani ko'rsatmaydi va kimniki ekani noma'lum — push YO'Q. O'quvchi yozuvi boshqa bolaga
   * qayta bog'langan bo'lsa ham javob yangisiga bormaydi.
   */
  private async childUserOf(tx: Tx, request: SchoolCareRequest): Promise<string | null> {
    if (!request.childId) return null;
    return (await tx.child.findUnique({ where: { id: request.childId }, select: { childUserId: true } }))?.childUserId ?? null;
  }

  /** Birinchi ochish: shartli UPDATE (`openedAt IS NULL`) — parallel ko'rishda faqat bittasi yozadi va audit qiladi. */
  private async markOpened(tx: Tx, actor: SchoolActor, id: string): Promise<void> {
    const res = await tx.schoolCareRequest.updateMany({
      where: { id, schoolId: actor.schoolId, openedAt: null },
      data: { openedAt: new Date(), openedByStaffId: actor.staffId },
    });
    if (res.count === 1) await this.writeAudit(tx, actor, REQUEST_AUDIT.open);
  }

  private writeAudit(tx: Tx, actor: SchoolActor, [action, summary]: readonly [string, string]) {
    return this.audit.write(actor, { module: 'CARE', action, summary }, tx);
  }

  /** Qator qulfi: parallel eslatma / javob / holat o'zgarishi bir-birini yo'qotmasin (o'qish-o'zgartirish-yozish). */
  private locked<T>(actor: SchoolActor, id: string, fn: (request: SchoolCareRequest, tx: Tx) => Promise<T>): Promise<T> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM school_care_requests WHERE id = ${id} AND school_id = ${actor.schoolId} FOR UPDATE`;
      const request = await tx.schoolCareRequest.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!request) throw notFound(id);
      return fn(request, tx);
    });
  }

  /** Audit (+ birinchi ochilish auditi) va `NEW` dan chiqqan murojaatning saqlangan bildirishnomalarini tozalash. */
  private async afterChange(tx: Tx, actor: SchoolActor, before: SchoolCareRequest, audit: readonly [string, string], leavesNew: boolean) {
    await this.writeAudit(tx, actor, audit);
    if (!before.openedAt) await this.writeAudit(tx, actor, REQUEST_AUDIT.open);
    if (leavesNew) await this.notify.clearFor(tx, before.id);
  }

  private async mutate(
    actor: SchoolActor,
    id: string,
    action: readonly [string, string],
    change: (request: SchoolCareRequest, tx: Tx) => object | Promise<object>,
  ) {
    const updated = await this.locked(actor, id, async (request, tx) => {
      const data = await change(request, tx);
      const next = await tx.schoolCareRequest.update({
        where: { id },
        // Murojaatga tegingan xodim uni ko'rgan: hali ochilmagan bo'lsa — birinchi ochgan shu.
        data: { ...(!request.openedAt && { openedAt: new Date(), openedByStaffId: actor.staffId }), ...data },
      });
      await this.afterChange(tx, actor, request, action, request.status === 'NEW' && next.status !== 'NEW');
      return next;
    });
    const [row] = await this.rowsOf.rows(actor.schoolId, [updated]);
    return { ...row!.view, resolvedAt: updated.resolvedAt?.toISOString() ?? null, notes: this.notesOf(updated) };
  }

  /** Himoya protokolida xabardor qilinadiganlar: faol direktor va navbatchi (tafsilotsiz). */
  private async protocolRecipients(schoolId: string) {
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId, active: true, role: { in: ['DIRECTOR', 'DUTY'] } },
      orderBy: { createdAt: 'asc' },
      select: { role: true, fullName: true },
    });
    return (['DIRECTOR', 'DUTY'] as const).flatMap((role) => {
      const s = staff.find((x) => x.role === role);
      return s ? [{ role, name: s.fullName }] : [];
    });
  }
}

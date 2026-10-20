// Bola ovozi murojaatlari — FAQAT psixolog (`care.individual`). Matn va
// eslatmalar bazada shifrlangan. Audit yozuvlarida bola ismi, sinfi, murojaat
// ID'si yoki matni YO'Q (audit jurnalini direktor / admin ham ko'radi).

import { Injectable } from '@nestjs/common';
import { SchoolCareRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { matchesSearch } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { CARE_REQUEST_STATUSES, careMeetingSchema, careNoteSchema, careRequestFilterSchema, careStatusSchema } from './care.schemas';

export interface CareNote {
  at: string;
  byStaffId: string;
  text: string;
}

const REQUEST_AUDIT = {
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
  ) {}

  async listRequests(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'care.individual');
    const filter = parseOrThrow(careRequestFilterSchema, query);
    const requests = await this.prisma.schoolCareRequest.findMany({ where: { schoolId: actor.schoolId } });
    const rows = (await this.rows(actor.schoolId, requests)).sort(
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

  async getRequest(actor: SchoolActor, id: string) {
    assertCan(actor, 'care.individual');
    const request = await this.find(actor.schoolId, id);
    const [row] = await this.rows(actor.schoolId, [request]);
    const notes = this.notesOf(request);
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId: actor.schoolId, id: { in: notes.map((n) => n.byStaffId) } },
      select: { id: true, fullName: true },
    });
    const names = new Map(staff.map((s) => [s.id, s.fullName]));
    return {
      ...row!.view,
      notes: [...notes].sort((a, b) => Date.parse(a.at) - Date.parse(b.at)).map((n) => ({ ...n, byName: names.get(n.byStaffId) ?? '—' })),
      notified: request.protocolActivated ? await this.protocolRecipients(actor.schoolId) : [],
    };
  }

  async updateRequestStatus(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.individual');
    const { status } = parseOrThrow(careStatusSchema, input);
    return this.mutate(actor, id, REQUEST_AUDIT.status, (request) => {
      if (status === 'SCHEDULED' && !request.meetingAt) throw invalid('meetingAt: errors.form.required');
      return { status };
    });
  }

  async addRequestNote(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.individual');
    const { text } = parseOrThrow(careNoteSchema, input);
    return this.mutate(actor, id, REQUEST_AUDIT.note, (request) => ({
      notesEnc: this.crypto.encryptJson([...this.notesOf(request), { at: new Date().toISOString(), byStaffId: actor.staffId, text }]),
    }));
  }

  async scheduleMeeting(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'care.individual');
    const { meetingAt } = parseOrThrow(careMeetingSchema, input);
    return this.mutate(actor, id, REQUEST_AUDIT.meeting, (request) => ({
      meetingAt: parseMeetingAt(meetingAt),
      ...(request.status !== 'RESOLVED' && { status: 'SCHEDULED' }),
    }));
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

  // ── Ichki ──────────────────────────────────────────────────────────

  private async find(schoolId: string, id: string) {
    const request = await this.prisma.schoolCareRequest.findFirst({ where: { id, schoolId } });
    if (!request) throw notFound(id);
    return request;
  }

  private notesOf(request: SchoolCareRequest): CareNote[] {
    return request.notesEnc ? this.crypto.decryptJson<CareNote[]>(request.notesEnc) : [];
  }

  private async mutate(
    actor: SchoolActor,
    id: string,
    [action, summary]: readonly [string, string],
    change: (request: SchoolCareRequest, tx: Parameters<Parameters<PrismaService['$transaction']>[0]>[0]) => object | Promise<object>,
  ) {
    const updated = await this.prisma.$transaction(async (tx) => {
      const request = await tx.schoolCareRequest.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!request) throw notFound(id);
      const next = await tx.schoolCareRequest.update({ where: { id }, data: await change(request, tx) });
      await this.audit.write(actor, { module: 'CARE', action, summary }, tx);
      return next;
    });
    const [row] = await this.rows(actor.schoolId, [updated]);
    return { ...row!.view, notes: this.notesOf(updated) };
  }

  /** Panel `CareRequestRow`: shifr ochiladi, ism va sinf qo'shiladi. */
  private async rows(schoolId: string, requests: SchoolCareRequest[]) {
    const [students, classes] = await Promise.all([
      this.prisma.schoolStudent.findMany({ where: { schoolId, id: { in: requests.map((r) => r.studentId) } }, select: { id: true, lastName: true, firstName: true } }),
      this.prisma.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true } }),
    ]);
    const studentName = new Map(students.map((s) => [s.id, `${s.lastName} ${s.firstName}`]));
    const className = new Map(classes.map((c) => [c.id, c.name]));
    return requests.map((r) => ({
      raw: r,
      view: {
        id: r.id,
        studentId: r.studentId,
        classId: r.classId ?? '',
        createdAt: r.createdAt.toISOString(),
        topic: r.topic,
        message: this.crypto.decrypt(r.messageEnc),
        urgency: r.urgency,
        status: r.status,
        meetingAt: r.meetingAt?.toISOString() ?? null,
        protocolActivated: r.protocolActivated,
        studentName: studentName.get(r.studentId) ?? '—',
        className: (r.classId && className.get(r.classId)) || '—',
      },
    }));
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

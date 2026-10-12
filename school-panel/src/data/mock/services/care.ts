import type {
  CareAggregate,
  CareNote,
  CareRequest,
  CareRequestStatus,
  CareSurvey,
  CareUrgency,
  RoleKey,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import {
  careAggregateQuerySchema,
  careMeetingSchema,
  careNoteSchema,
  careStatusSchema,
  CARE_REQUEST_STATUSES,
  type CareAggregateQuery,
} from '@/data/schemas/care';
import { parseOrThrow } from '@/data/schemas/validate';
import { matchesSearch } from '@/lib/normalize-search';
import { clockNow, clockToday } from '../clock';
import { type Actor, assertCan, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes, studentName } from '../lookups';
import type { Tables } from '../tables';
import { computeCareAggregate, defaultSurvey } from './care-aggregate';
import { careSurveysService } from './care-surveys';

/**
 * Bola ovozi (Parvoz Care).
 * - `aggregate`, `surveyOptions` — `care.aggregate` (direktor, admin, psixolog): faqat anonim natija.
 * - Murojaatlar — `care.individual` (FAQAT psixolog). Audit yozuvlarida bola ismi,
 *   sinfi yoki murojaat matni YO'Q (audit jurnalini direktor/admin ko'radi).
 * - So'rovnomalar va savollar banki — `care.surveys` (`care-surveys.ts`).
 */
export type CareSurveyOption = Pick<CareSurvey, 'id' | 'title' | 'weekStart' | 'status'>;
export type CareRequestRow = CareRequest & { studentName: string; className: string };
export type CareNoteView = CareNote & { byName: string };
export type CareNotified = { role: RoleKey; name: string };
export type CareRequestDetail = Omit<CareRequestRow, 'notes'> & { notes: CareNoteView[]; notified: CareNotified[] };
export type CareRequestFilter = { status?: CareRequestStatus; urgency?: CareUrgency; search?: string };
export type CareRequestList = { items: CareRequestRow[]; counts: Record<CareRequestStatus, number> };

function requireIndividual(): Actor {
  const actor = currentActor();
  assertCan(actor, 'care.individual');
  return actor;
}

function toRow(t: Tables, request: CareRequest): CareRequestRow {
  const idx = buildIndexes(t);
  const student = idx.students.get(request.studentId);
  return {
    ...request,
    studentName: student ? studentName(student) : '—',
    className: idx.classes.get(request.classId)?.name ?? '—',
  };
}

/** Himoya protokolida xabardor qilinadiganlar: direktor va navbatchi (tafsilotsiz). */
function protocolRecipients(t: Tables): CareNotified[] {
  const pick = (role: RoleKey) => t.staff.find((s) => s.role === role && s.active);
  return (['DIRECTOR', 'DUTY'] as const)
    .map((role) => ({ role, staff: pick(role) }))
    .filter((r) => Boolean(r.staff))
    .map((r) => ({ role: r.role, name: r.staff?.fullName ?? '' }));
}

/** Shoshilinch va yopilmagan — tepada, keyin yangilari. */
function compareRequests(a: CareRequest, b: CareRequest): number {
  const rank = (r: CareRequest) => (r.urgency === 'URGENT' && r.status !== 'RESOLVED' ? 0 : 1);
  return rank(a) - rank(b) || Date.parse(b.createdAt) - Date.parse(a.createdAt);
}

function mutateRequest(id: string, fn: (t: Tables, request: CareRequest, actor: Actor) => void): CareRequest {
  const actor = requireIndividual();
  return transact((t) => {
    const request = t.careRequests.find((r) => r.id === id);
    if (!request) throw new ServiceError('NOT_FOUND', id);
    fn(t, request, actor);
    return { ...request, notes: [...request.notes] };
  });
}

function localStamp(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:00`;
}

export const careService = {
  /** So'rovnoma tanlovi uchun — faqat sarlavha/hafta/holat (shaxsiy ma'lumotsiz). */
  async surveyOptions(): Promise<CareSurveyOption[]> {
    await latency(40, 120);
    assertCan(currentActor(), 'care.aggregate');
    return getTables()
      .careSurveys.filter((s) => s.status !== 'DRAFT')
      .sort((a, b) => b.weekStart.localeCompare(a.weekStart))
      .map(({ id, title, weekStart, status }) => ({ id, title, weekStart, status }));
  },

  /** Umumlashgan natija — bir vaqtda bitta kesim; k ≥ 5; shaxsga bog'liq maydon yo'q. */
  async aggregate(query: CareAggregateQuery): Promise<CareAggregate> {
    await latency();
    assertCan(currentActor(), 'care.aggregate');
    const { surveyId, breakdown } = parseOrThrow(careAggregateQuerySchema, query);
    const t = getTables();
    const survey = surveyId ? t.careSurveys.find((s) => s.id === surveyId) : defaultSurvey(t.careSurveys);
    if (!survey) throw new ServiceError('NOT_FOUND', surveyId ?? 'survey');
    return computeCareAggregate(t, survey, breakdown, clockToday());
  },

  async listRequests(filter: CareRequestFilter = {}): Promise<CareRequestList> {
    await latency(60, 160);
    requireIndividual();
    const t = getTables();
    const rows = [...t.careRequests].sort(compareRequests).map((r) => toRow(t, r));
    const searched = rows.filter(
      (r) =>
        (!filter.urgency || r.urgency === filter.urgency) &&
        (!filter.search || matchesSearch(`${r.studentName} ${r.className} ${r.message}`, filter.search)),
    );
    const counts = Object.fromEntries(CARE_REQUEST_STATUSES.map((s) => [s, searched.filter((r) => r.status === s).length])) as Record<
      CareRequestStatus,
      number
    >;
    return { items: filter.status ? searched.filter((r) => r.status === filter.status) : searched, counts };
  },

  async getRequest(id: string): Promise<CareRequestDetail> {
    await latency(60, 140);
    requireIndividual();
    const t = getTables();
    const request = t.careRequests.find((r) => r.id === id);
    if (!request) throw new ServiceError('NOT_FOUND', id);
    const staff = buildIndexes(t).staff;
    return {
      ...toRow(t, request),
      notes: [...request.notes]
        .sort((a, b) => Date.parse(a.at) - Date.parse(b.at))
        .map((n) => ({ ...n, byName: staff.get(n.byStaffId)?.fullName ?? '—' })),
      notified: request.protocolActivated ? protocolRecipients(t) : [],
    };
  },

  async updateRequestStatus(id: string, status: CareRequestStatus): Promise<CareRequest> {
    await latency();
    const data = parseOrThrow(careStatusSchema, { status });
    return mutateRequest(id, (t, request, actor) => {
      if (data.status === 'SCHEDULED' && !request.meetingAt) throw new ServiceError('VALIDATION', 'meetingAt: errors.form.required');
      const before = request.status;
      request.status = data.status;
      writeAudit(t, actor, 'CARE', 'care.request.status', 'Murojaat holati o\'zgartirildi', id, { status: before }, { status: data.status });
    });
  },

  async addRequestNote(id: string, text: string): Promise<CareRequest> {
    await latency();
    const data = parseOrThrow(careNoteSchema, { text });
    return mutateRequest(id, (t, request, actor) => {
      request.notes = [...request.notes, { at: localStamp(clockNow()), byStaffId: actor.staffId, text: data.text }];
      writeAudit(t, actor, 'CARE', 'care.request.note', 'Murojaatga ichki eslatma qo\'shildi', id);
    });
  },

  async scheduleMeeting(id: string, meetingAt: string): Promise<CareRequest> {
    await latency();
    const data = parseOrThrow(careMeetingSchema, { meetingAt });
    return mutateRequest(id, (t, request, actor) => {
      request.meetingAt = localStamp(new Date(data.meetingAt));
      if (request.status !== 'RESOLVED') request.status = 'SCHEDULED';
      writeAudit(t, actor, 'CARE', 'care.request.meeting', 'Murojaat bo\'yicha suhbat vaqti belgilandi', id);
    });
  },

  /**
   * Himoya protokoli (faqat shoshilinch murojaat): direktor va navbatchi xabardor
   * qilinadi — murojaat matni va bola ismi ularga BERILMAYDI; shikoyat qilingan
   * shaxsga hech narsa yuborilmaydi.
   */
  async activateProtocol(id: string): Promise<CareRequest> {
    await latency();
    return mutateRequest(id, (t, request, actor) => {
      if (request.urgency !== 'URGENT') throw new ServiceError('VALIDATION', 'urgency');
      if (request.protocolActivated) throw new ServiceError('CONFLICT', 'protocol already active');
      const who = protocolRecipients(t)
        .map((r) => `${r.name} (${r.role === 'DIRECTOR' ? 'direktor' : 'navbatchi'})`)
        .join(', ');
      request.protocolActivated = true;
      if (request.status === 'NEW') request.status = 'IN_PROGRESS';
      request.notes = [
        ...request.notes,
        {
          at: localStamp(clockNow()),
          byStaffId: actor.staffId,
          text: `Himoya protokoli ishga tushirildi. Xabardor qilindi: ${who}. Murojaat matni va bolaning ismi ularga berilmadi; shikoyat qilingan shaxsga hech narsa yuborilmadi.`,
        },
      ];
      writeAudit(t, actor, 'CARE', 'care.protocol.activate', 'Shoshilinch murojaat: himoya protokoli ishga tushirildi (direktor va navbatchi xabardor qilindi)', id);
    });
  },

  ...careSurveysService,
};

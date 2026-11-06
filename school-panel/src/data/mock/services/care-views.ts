import type {
  CareMessage,
  CareNotified,
  CareRequest,
  CareRequestDetail,
  CareRequestRow,
  CareStaffRef,
  RoleKey,
} from '@/data/contracts';
import { buildIndexes, studentName } from '../lookups';
import type { Tables } from '../tables';

/**
 * Saqlangan murojaat (`CareRequest`) → panel ko'rinishi. Yozishma va ichki eslatma ALOHIDA:
 * `messages` bolaga ko'rinadigan yozishma, `notes` — faqat psixologlar ko'radigan ichki eslatmalar.
 */

const NO_NAME = '—';

function staffRef(t: Tables, id: string | null): CareStaffRef | null {
  if (!id) return null;
  return { id, name: buildIndexes(t).staff.get(id)?.fullName ?? NO_NAME };
}

/** Bola yozgan, xodim hali o'qimagan xabarlar. */
export function unreadFromChild(request: Pick<CareRequest, 'messages'>): number {
  return request.messages.filter((m) => m.author === 'CHILD' && !m.readByStaffAt).length;
}

export function toRow(t: Tables, request: CareRequest): CareRequestRow {
  const idx = buildIndexes(t);
  const student = idx.students.get(request.studentId);
  return {
    id: request.id,
    studentId: request.studentId,
    classId: request.classId,
    createdAt: request.createdAt,
    topic: request.topic,
    message: request.message,
    urgency: request.urgency,
    status: request.status,
    meetingAt: request.meetingAt,
    protocolActivated: request.protocolActivated,
    studentName: student ? studentName(student) : NO_NAME,
    className: idx.classes.get(request.classId)?.name ?? NO_NAME,
    notesCount: request.notes.length,
    openedAt: request.openedAt,
    repliedAt: request.repliedAt,
    escalatedAt: request.escalatedAt,
    unreadFromChild: unreadFromChild(request),
    assignedTo: staffRef(t, request.assignedStaffId),
  };
}

/** Himoya protokolida xabardor qilinadiganlar: direktor va navbatchi (tafsilotsiz). */
export function protocolRecipients(t: Tables): CareNotified[] {
  const pick = (role: RoleKey) => t.staff.find((s) => s.role === role && s.active);
  return (['DIRECTOR', 'DUTY'] as const)
    .map((role) => ({ role, staff: pick(role) }))
    .filter((r) => Boolean(r.staff))
    .map((r) => ({ role: r.role, name: r.staff?.fullName ?? '' }));
}

function messageViews(t: Tables, request: CareRequest): CareMessage[] {
  const staff = buildIndexes(t).staff;
  return [...request.messages]
    .sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt))
    .map((m) => ({
      id: m.id,
      author: m.author,
      authorName: m.author === 'STAFF' ? (staff.get(m.staffId ?? '')?.fullName ?? NO_NAME) : null,
      text: m.text,
      createdAt: m.createdAt,
    }));
}

export function toDetail(t: Tables, request: CareRequest): CareRequestDetail {
  const staff = buildIndexes(t).staff;
  const { notesCount: _count, ...row } = toRow(t, request);
  void _count;
  return {
    ...row,
    notesCount: request.notes.length,
    notes: [...request.notes]
      .sort((a, b) => Date.parse(a.at) - Date.parse(b.at))
      .map((n) => ({ ...n, byName: staff.get(n.byStaffId)?.fullName ?? NO_NAME })),
    notified: request.protocolActivated ? protocolRecipients(t) : [],
    messages: messageViews(t, request),
    openedBy: staffRef(t, request.openedByStaffId),
    resolvedAt: request.resolvedAt,
  };
}

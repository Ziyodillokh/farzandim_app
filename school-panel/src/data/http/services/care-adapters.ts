import type {
  CareMessage,
  CareNoteView,
  CareNotified,
  CareRequestDetail,
  CareRequestList,
  CareRequestRow,
  CareRequestStatus,
  CareSettings,
  CareSettingsView,
  CareStaffOption,
  CareStaffRef,
  CareTopicTag,
  CareUrgency,
  RoleKey,
} from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import type { CareSettingsInput } from '@/data/schemas/care';

/**
 * Bola ovozi: backend (kontrakt) javoblarini panel turlariga keltiruvchi ADAPTERLAR.
 * Har biri aniq funksiya va unit-test bilan qoplangan (`__tests__/care.test.ts`): http qatlami
 * "taxminiy" shaklga tayanmasin. Majburiy maydon yo'q yoki turi noto'g'ri bo'lsa — jim standart qiymat
 * EMAS, aniq xato (aks holda forma standart qiymatni backend ustiga yozib yuborishi mumkin).
 */

export type Wire = Record<string, unknown>;

export function isRecord(value: unknown): value is Wire {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function malformed(what: string): ServiceError {
  return new ServiceError('UNKNOWN', `${what}: kutilmagan javob shakli`);
}

/** Bo'sh bo'lmagan satr yoki null (aks holda — shakl xatosi). */
export function nullableString(value: unknown, what: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value === 'string') return value === '' ? null : value;
  throw malformed(what);
}

export function requiredString(value: unknown, what: string): string {
  if (typeof value === 'string' && value !== '') return value;
  throw malformed(what);
}

export function requiredInt(value: unknown, what: string): number {
  if (typeof value === 'number' && Number.isInteger(value)) return value;
  throw malformed(what);
}

export function nullableDateTime(value: unknown, what: string): string | null {
  return nullableString(value, what);
}

const HH_MM = /^(\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?$/;

/** "09:00" yoki "09:00:00" → "09:00". */
function clockTime(value: unknown, what: string): string {
  const match = typeof value === 'string' ? HH_MM.exec(value) : null;
  if (!match?.[1]) throw malformed(what);
  return match[1];
}

function workDays(value: unknown): number[] {
  if (!Array.isArray(value)) throw malformed('workDays');
  const days = value.map((d) => (typeof d === 'number' && Number.isInteger(d) && d >= 1 && d <= 7 ? d : null));
  if (days.includes(null)) throw malformed('workDays');
  return [...new Set(days as number[])].sort((a, b) => a - b);
}

function staffOptions(value: unknown): CareStaffOption[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw malformed('staffOptions');
  return value.map((item) => {
    if (!isRecord(item)) throw malformed('staffOptions');
    return { id: requiredString(item.id, 'staffOptions.id'), fullName: requiredString(item.fullName, 'staffOptions.fullName') };
  });
}

/**
 * `GET /school/care/settings` (kontrakt C): tekis obyekt — sozlama maydonlari + `staffOptions`.
 * Sozlamalar `settings` ichida joylashgan shakl ham qabul qilinadi (`{ settings, staffOptions }`).
 */
export function toCareSettingsView(raw: unknown): CareSettingsView {
  if (!isRecord(raw)) throw malformed('settings');
  const source = isRecord(raw.settings) ? raw.settings : raw;
  const settings: CareSettings = {
    psychologistStaffId: nullableString(source.psychologistStaffId, 'psychologistStaffId'),
    psychologistDisplayName: nullableString(source.psychologistDisplayName, 'psychologistDisplayName'),
    deputyStaffId: nullableString(source.deputyStaffId, 'deputyStaffId'),
    deputyDisplayName: nullableString(source.deputyDisplayName, 'deputyDisplayName'),
    workDays: workDays(source.workDays),
    workStart: clockTime(source.workStart, 'workStart'),
    workEnd: clockTime(source.workEnd, 'workEnd'),
    urgentSlaMinutes: requiredInt(source.urgentSlaMinutes, 'urgentSlaMinutes'),
    normalSlaHours: requiredInt(source.normalSlaHours, 'normalSlaHours'),
    updatedAt: nullableDateTime(source.updatedAt, 'updatedAt'),
  };
  return { ...settings, staffOptions: staffOptions(raw.staffOptions ?? source.staffOptions) };
}

const cleanName = (value: string | null): string | null => value?.trim() || null;

/** `PUT /school/care/settings` tanasi: to'liq almashtirish, tozalangan maydonlar `null`. */
export function toCareSettingsBody(input: CareSettingsInput): Record<string, unknown> {
  return {
    psychologistStaffId: input.psychologistStaffId,
    psychologistDisplayName: cleanName(input.psychologistDisplayName),
    deputyStaffId: input.deputyStaffId,
    deputyDisplayName: cleanName(input.deputyDisplayName),
    workDays: [...input.workDays].sort((a, b) => a - b),
    workStart: input.workStart,
    workEnd: input.workEnd,
    urgentSlaMinutes: input.urgentSlaMinutes,
    normalSlaHours: input.normalSlaHours,
  };
}

// ── Murojaatlar (kontrakt B) ─────────────────────────────────────────────

const URGENCIES: readonly CareUrgency[] = ['NORMAL', 'URGENT'];
const STATUSES: readonly CareRequestStatus[] = ['NEW', 'IN_PROGRESS', 'SCHEDULED', 'RESOLVED'];
const TOPICS: readonly CareTopicTag[] = ['LEARNING', 'PEERS', 'BULLYING', 'FAMILY', 'EMOTIONS', 'SAFETY', 'OTHER'];
const ROLES: readonly RoleKey[] = ['DIRECTOR', 'ADMIN', 'HOMEROOM', 'PSYCHOLOGIST', 'DUTY', 'TEACHER'];
const INITIAL_MESSAGE_ID = 'initial';

function oneOf<T extends string>(value: unknown, allowed: readonly T[], what: string): T {
  const found = allowed.find((a) => a === value);
  if (found === undefined) throw malformed(what);
  return found;
}

function requiredText(value: unknown, what: string): string {
  if (typeof value === 'string') return value;
  throw malformed(what);
}

function requiredBool(value: unknown, what: string): boolean {
  if (typeof value === 'boolean') return value;
  throw malformed(what);
}

/** `{ id, name }` yoki null/yo'q. */
function staffRef(value: unknown, what: string): CareStaffRef | null {
  if (value === undefined || value === null) return null;
  if (!isRecord(value)) throw malformed(what);
  return { id: requiredString(value.id, `${what}.id`), name: requiredString(value.name, `${what}.name`) };
}

/** Bola xabarlari soni: son (`unreadFromChild: 2`) yoki bayroq (`true` → 1); yo'q → 0. */
function unreadCount(value: unknown): number {
  if (value === undefined || value === null || value === false) return 0;
  if (value === true) return 1;
  if (typeof value === 'number' && Number.isInteger(value) && value >= 0) return value;
  throw malformed('unreadFromChild');
}

/** `{ id, author, authorName, text, createdAt }` (kontrakt B). */
export function toCareMessage(raw: unknown): CareMessage {
  if (!isRecord(raw)) throw malformed('message');
  const author = oneOf(raw.author, ['CHILD', 'STAFF'] as const, 'message.author');
  return {
    id: requiredString(raw.id, 'message.id'),
    author,
    authorName: author === 'STAFF' ? nullableString(raw.authorName, 'message.authorName') : null,
    text: requiredText(raw.text, 'message.text'),
    createdAt: requiredString(raw.createdAt, 'message.createdAt'),
  };
}

type RowBase = { row: Omit<CareRequestRow, 'notesCount'>; notes: unknown };

function rowBase(raw: unknown): RowBase {
  if (!isRecord(raw)) throw malformed('request');
  const row: Omit<CareRequestRow, 'notesCount'> = {
    id: requiredString(raw.id, 'id'),
    studentId: requiredString(raw.studentId, 'studentId'),
    classId: requiredText(raw.classId ?? '', 'classId'),
    createdAt: requiredString(raw.createdAt, 'createdAt'),
    topic: TOPICS.find((t) => t === raw.topic) ?? 'OTHER',
    message: requiredText(raw.message, 'message'),
    urgency: oneOf(raw.urgency, URGENCIES, 'urgency'),
    status: oneOf(raw.status, STATUSES, 'status'),
    meetingAt: nullableString(raw.meetingAt, 'meetingAt'),
    protocolActivated: requiredBool(raw.protocolActivated, 'protocolActivated'),
    studentName: requiredText(raw.studentName ?? '—', 'studentName'),
    className: requiredText(raw.className ?? '—', 'className'),
    openedAt: nullableDateTime(raw.openedAt, 'openedAt'),
    repliedAt: nullableDateTime(raw.repliedAt, 'repliedAt'),
    escalatedAt: nullableDateTime(raw.escalatedAt, 'escalatedAt'),
    unreadFromChild: unreadCount(raw.unreadFromChild),
    assignedTo: staffRef(raw.assignedTo, 'assignedTo'),
  };
  return { row, notes: raw.notes };
}

/**
 * Ro'yxat qatori. Backend ro'yxatda `notes` BERMAYDI (faqat tafsilotda) — shuning uchun `notesCount: null`
 * (chip ko'rsatilmaydi); massiv kelsa uzunligi olinadi.
 */
export function toCareRequestRow(raw: unknown): CareRequestRow {
  const { row, notes } = rowBase(raw);
  return { ...row, notesCount: Array.isArray(notes) ? notes.length : null };
}

const ZERO_COUNTS: Record<CareRequestStatus, number> = { NEW: 0, IN_PROGRESS: 0, SCHEDULED: 0, RESOLVED: 0 };

/** `GET /school/care/requests` → `{ items, counts }`. */
export function toCareRequestList(raw: unknown): CareRequestList {
  if (!isRecord(raw) || !Array.isArray(raw.items)) throw malformed('requests');
  const counts = { ...ZERO_COUNTS };
  if (isRecord(raw.counts)) {
    for (const status of STATUSES) {
      const n = raw.counts[status];
      if (typeof n === 'number' && Number.isInteger(n) && n >= 0) counts[status] = n;
    }
  }
  return { items: raw.items.map(toCareRequestRow), counts };
}

function noteViews(value: unknown): CareNoteView[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw malformed('notes');
  return value.map((n) => {
    if (!isRecord(n)) throw malformed('notes');
    return {
      at: requiredString(n.at, 'notes.at'),
      byStaffId: requiredString(n.byStaffId, 'notes.byStaffId'),
      text: requiredText(n.text, 'notes.text'),
      byName: typeof n.byName === 'string' && n.byName !== '' ? n.byName : '—',
    };
  });
}

function notifiedList(value: unknown): CareNotified[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw malformed('notified');
  return value.map((n) => {
    if (!isRecord(n)) throw malformed('notified');
    return { role: oneOf(n.role, ROLES, 'notified.role'), name: requiredText(n.name, 'notified.name') };
  });
}

/**
 * Yozishma: xronologik tartib (eski → yangi). Backend yozishmasiz (eski) murojaat uchun `initial` xabarini o'zi
 * yasaydi (kontrakt B); bo'sh kelsa ham bolaning birinchi so'zi yo'qolmasin — shu id bilan yasaymiz.
 */
function threadOf(value: unknown, row: Pick<CareRequestRow, 'message' | 'createdAt'>): CareMessage[] {
  if (value !== undefined && value !== null && !Array.isArray(value)) throw malformed('messages');
  const messages = (value ?? []).map(toCareMessage);
  if (messages.length === 0) {
    return [{ id: INITIAL_MESSAGE_ID, author: 'CHILD', authorName: null, text: row.message, createdAt: row.createdAt }];
  }
  return messages.map((m, i) => ({ m, i })).sort((a, b) => Date.parse(a.m.createdAt) - Date.parse(b.m.createdAt) || a.i - b.i).map(({ m }) => m);
}

/**
 * `GET /school/care/requests/:id`: qator maydonlari + `notes`, `notified`, `messages`, `openedBy`, `resolvedAt`.
 * Ochilganda backend bola xabarlarini o'qilgan qiladi — shuning uchun tafsilotda `unreadFromChild` yo'q (0).
 */
export function toCareRequestDetail(raw: unknown): CareRequestDetail {
  const { row } = rowBase(raw);
  const source = raw as Wire;
  const notes = noteViews(source.notes);
  return {
    ...row,
    notesCount: notes.length,
    notes,
    notified: notifiedList(source.notified),
    messages: threadOf(source.messages, row),
    openedBy: staffRef(source.openedBy, 'openedBy'),
    resolvedAt: nullableDateTime(source.resolvedAt, 'resolvedAt'),
  };
}

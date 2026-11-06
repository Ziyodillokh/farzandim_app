import { describe, expect, it } from 'vitest';

import { toServiceError } from '../client';
import { toCareMessage, toCareRequestDetail, toCareRequestList, toCareRequestRow, toCareSettingsBody, toCareSettingsView } from '../services/care-adapters';

/** Kontrakt C: `GET /school/care/settings` — sozlama maydonlari + `staffOptions` (tekis obyekt). */
const WIRE = {
  psychologistStaffId: 'stf-1',
  psychologistDisplayName: 'Dilnoza opa',
  deputyStaffId: 'stf-2',
  deputyDisplayName: null,
  workDays: [1, 2, 3, 4, 5],
  workStart: '09:00',
  workEnd: '17:00',
  urgentSlaMinutes: 60,
  normalSlaHours: 24,
  updatedAt: '2026-11-06T04:00:00.000Z',
  updatedByStaffId: 'stf-1',
  staffOptions: [
    { id: 'stf-1', fullName: 'Sobirova Lola' },
    { id: 'stf-2', fullName: 'Karimova Kamola' },
  ],
};

describe('toCareSettingsView', () => {
  it('kontrakt shaklini (tekis obyekt) panel turiga keltiradi; ortiqcha maydonlar tashlanadi', () => {
    const view = toCareSettingsView(WIRE);
    expect(view).toEqual({
      psychologistStaffId: 'stf-1',
      psychologistDisplayName: 'Dilnoza opa',
      deputyStaffId: 'stf-2',
      deputyDisplayName: null,
      workDays: [1, 2, 3, 4, 5],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 60,
      normalSlaHours: 24,
      updatedAt: '2026-11-06T04:00:00.000Z',
      staffOptions: WIRE.staffOptions,
    });
    expect('updatedByStaffId' in view).toBe(false);
  });

  it('`{ settings, staffOptions }` ichma-ich shaklini ham qabul qiladi', () => {
    const { staffOptions, ...settings } = WIRE;
    expect(toCareSettingsView({ settings, staffOptions })).toEqual(toCareSettingsView(WIRE));
  });

  it('saqlangan yozuv yo\'q: updatedAt null/yo\'q, ismlar null — "sozlanmagan"', () => {
    const view = toCareSettingsView({ ...WIRE, psychologistStaffId: null, deputyStaffId: null, psychologistDisplayName: null, updatedAt: null });
    expect(view).toMatchObject({ psychologistStaffId: null, deputyStaffId: null, updatedAt: null });
    const { updatedAt: _omit, ...withoutUpdatedAt } = WIRE;
    void _omit;
    expect(toCareSettingsView(withoutUpdatedAt).updatedAt).toBeNull();
  });

  it('bo\'sh qator ismlari null ga aylanadi; kunlar tartiblanadi va takrorlanmaydi; "HH:MM:SS" → "HH:MM"', () => {
    const view = toCareSettingsView({ ...WIRE, psychologistDisplayName: '', workDays: [5, 1, 1, 3], workStart: '09:00:00', workEnd: '17:30:00' });
    expect(view).toMatchObject({ psychologistDisplayName: null, workDays: [1, 3, 5], workStart: '09:00', workEnd: '17:30' });
  });

  it('staffOptions yo\'q bo\'lsa — bo\'sh ro\'yxat (tahrirlash tanlovi bo\'sh)', () => {
    const { staffOptions: _omit, ...rest } = WIRE;
    void _omit;
    expect(toCareSettingsView(rest).staffOptions).toEqual([]);
  });

  const broken: Array<[string, unknown]> = [
    ['javob obyekt emas', 'ok'],
    ['workDays massiv emas', { ...WIRE, workDays: '1,2' }],
    ['workDays 8', { ...WIRE, workDays: [1, 8] }],
    ['workStart noto\'g\'ri', { ...WIRE, workStart: '9am' }],
    ['SLA son emas', { ...WIRE, urgentSlaMinutes: '60' }],
    ['SLA kasr', { ...WIRE, normalSlaHours: 1.5 }],
    ['staffOptions elementida fullName yo\'q', { ...WIRE, staffOptions: [{ id: 'stf-1', name: 'x' }] }],
    ['psychologistStaffId son', { ...WIRE, psychologistStaffId: 5 }],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi (standart qiymat o\'rniga): %s', (_name, wire) => {
    expect(() => toCareSettingsView(wire)).toThrowError(/kutilmagan javob shakli/);
  });
});

describe('toCareSettingsBody', () => {
  it('PUT tanasi: aynan 9 maydon, to\'liq almashtirish; bo\'sh ism va tanlanmagan xodim — null', () => {
    const body = toCareSettingsBody({
      psychologistStaffId: 'stf-1',
      psychologistDisplayName: '  ',
      deputyStaffId: null,
      deputyDisplayName: ' Kamola opa ',
      workDays: [3, 1],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 45,
      normalSlaHours: 12,
    });
    expect(body).toEqual({
      psychologistStaffId: 'stf-1',
      psychologistDisplayName: null,
      deputyStaffId: null,
      deputyDisplayName: 'Kamola opa',
      workDays: [1, 3],
      workStart: '09:00',
      workEnd: '17:00',
      urgentSlaMinutes: 45,
      normalSlaHours: 12,
    });
  });
});

/**
 * Mavjud backend (`care-requests.service.ts` → `rows()`) ro'yxat qatori: `notes` BERMAYDI.
 * Yangi maydonlar — kontrakt B: `openedAt`, `repliedAt`, `unreadFromChild`, `assignedTo`, `escalatedAt`.
 */
const ROW_WIRE = {
  id: 'r1',
  studentId: 'st1',
  classId: 'c1',
  createdAt: '2026-11-06T02:52:00.000Z',
  topic: 'BULLYING',
  message: 'Meni masxara qilishadi',
  urgency: 'URGENT',
  status: 'NEW',
  meetingAt: null,
  protocolActivated: false,
  studentName: 'Aliyev Vali',
  className: '8-B',
  openedAt: null,
  repliedAt: null,
  unreadFromChild: 1,
  assignedTo: { id: 'stf-1', name: 'Sobirova Lola' },
  escalatedAt: null,
};

describe('toCareRequestRow / toCareRequestList', () => {
  it('kontrakt B maydonlarini panel qatoriga keltiradi; ro\'yxatda `notes` yo\'q — notesCount null (eski xato: notes.length yiqilardi)', () => {
    const row = toCareRequestRow(ROW_WIRE);
    expect(row).toMatchObject({
      id: 'r1',
      studentName: 'Aliyev Vali',
      className: '8-B',
      openedAt: null,
      repliedAt: null,
      escalatedAt: null,
      unreadFromChild: 1,
      assignedTo: { id: 'stf-1', name: 'Sobirova Lola' },
      notesCount: null,
    });
    expect('notes' in row).toBe(false);
  });

  it('notes massivi kelsa soni olinadi; unreadFromChild son yoki bayroq; yo\'q — 0; assignedTo yo\'q — null', () => {
    expect(toCareRequestRow({ ...ROW_WIRE, notes: [{}, {}] }).notesCount).toBe(2);
    expect(toCareRequestRow({ ...ROW_WIRE, unreadFromChild: 3 }).unreadFromChild).toBe(3);
    expect(toCareRequestRow({ ...ROW_WIRE, unreadFromChild: true }).unreadFromChild).toBe(1);
    expect(toCareRequestRow({ ...ROW_WIRE, unreadFromChild: false }).unreadFromChild).toBe(0);
    const { unreadFromChild: _u, assignedTo: _a, openedAt: _o, ...older } = ROW_WIRE;
    void [_u, _a, _o];
    expect(toCareRequestRow(older)).toMatchObject({ unreadFromChild: 0, assignedTo: null, openedAt: null });
  });

  it('o\'rinbosarga o\'tgan murojaat: escalatedAt va assignedTo', () => {
    const row = toCareRequestRow({ ...ROW_WIRE, escalatedAt: '2026-11-06T04:00:00.000Z', assignedTo: { id: 'stf-2', name: 'Karimova Kamola' } });
    expect(row.escalatedAt).toBe('2026-11-06T04:00:00.000Z');
    expect(row.assignedTo?.name).toBe('Karimova Kamola');
  });

  it('noma\'lum mavzu — OTHER; noto\'g\'ri holat/shoshilinchlik — aniq xato', () => {
    expect(toCareRequestRow({ ...ROW_WIRE, topic: 'YANGI' }).topic).toBe('OTHER');
    expect(() => toCareRequestRow({ ...ROW_WIRE, status: 'DONE' })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toCareRequestRow({ ...ROW_WIRE, urgency: 'HIGH' })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toCareRequestRow({ ...ROW_WIRE, unreadFromChild: -1 })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toCareRequestRow({ ...ROW_WIRE, assignedTo: 'stf-1' })).toThrowError(/kutilmagan javob shakli/);
  });

  it('ro\'yxat: items + counts; counts yo\'q bo\'lsa nol', () => {
    const list = toCareRequestList({ items: [ROW_WIRE], counts: { NEW: 1, IN_PROGRESS: 0, SCHEDULED: 2, RESOLVED: 3 } });
    expect(list.items).toHaveLength(1);
    expect(list.counts).toEqual({ NEW: 1, IN_PROGRESS: 0, SCHEDULED: 2, RESOLVED: 3 });
    expect(toCareRequestList({ items: [] }).counts).toEqual({ NEW: 0, IN_PROGRESS: 0, SCHEDULED: 0, RESOLVED: 0 });
    expect(() => toCareRequestList({ rows: [] })).toThrowError(/kutilmagan javob shakli/);
  });
});

const MESSAGES_WIRE = [
  { id: 'm2', author: 'STAFF', authorName: 'Sobirova Lola', text: 'Salom', createdAt: '2026-11-06T05:00:00.000Z' },
  { id: 'm1', author: 'CHILD', authorName: null, text: 'Meni masxara qilishadi', createdAt: '2026-11-06T02:52:00.000Z' },
  { id: 'm3', author: 'CHILD', authorName: null, text: 'Rahmat', createdAt: '2026-11-06T05:10:00.000Z' },
];

/** Mavjud backend `getRequest`: `{ ...view, notes: [{ at, byStaffId, text, byName }], notified }` + kontrakt B maydonlari. */
const DETAIL_WIRE = {
  ...ROW_WIRE,
  status: 'IN_PROGRESS',
  openedAt: '2026-11-06T04:00:00.000Z',
  openedBy: { id: 'stf-1', name: 'Sobirova Lola' },
  repliedAt: '2026-11-06T05:00:00.000Z',
  resolvedAt: null,
  escalatedAt: null,
  unreadFromChild: undefined,
  notes: [{ at: '2026-11-06T05:05:00.000Z', byStaffId: 'stf-1', text: 'Ichki', byName: 'Sobirova Lola' }],
  notified: [{ role: 'DIRECTOR', name: 'Yusupova Nodira' }],
  messages: MESSAGES_WIRE,
};

describe('toCareRequestDetail', () => {
  it('yozishma xronologik tartibda; ichki eslatmalar ALOHIDA `notes`da qoladi', () => {
    const detail = toCareRequestDetail(DETAIL_WIRE);
    expect(detail.messages.map((m) => m.id)).toEqual(['m1', 'm2', 'm3']);
    expect(detail.messages.map((m) => m.author)).toEqual(['CHILD', 'STAFF', 'CHILD']);
    expect(detail.messages.find((m) => m.id === 'm2')?.authorName).toBe('Sobirova Lola');
    expect(detail.messages.find((m) => m.id === 'm1')?.authorName).toBeNull();
    expect(detail.notes).toEqual([{ at: '2026-11-06T05:05:00.000Z', byStaffId: 'stf-1', text: 'Ichki', byName: 'Sobirova Lola' }]);
    expect(JSON.stringify(detail.messages).includes('Ichki')).toBe(false);
    expect(detail.notesCount).toBe(1);
  });

  it('ochilgan/javob/yopilgan vaqtlari va kim ochgani', () => {
    const detail = toCareRequestDetail(DETAIL_WIRE);
    expect(detail).toMatchObject({
      openedAt: '2026-11-06T04:00:00.000Z',
      openedBy: { id: 'stf-1', name: 'Sobirova Lola' },
      repliedAt: '2026-11-06T05:00:00.000Z',
      resolvedAt: null,
      escalatedAt: null,
      assignedTo: { id: 'stf-1', name: 'Sobirova Lola' },
      unreadFromChild: 0,
      notified: [{ role: 'DIRECTOR', name: 'Yusupova Nodira' }],
    });
  });

  it('o\'rinbosarga o\'tgan: escalatedAt + assignedTo (o\'rinbosar)', () => {
    const detail = toCareRequestDetail({ ...DETAIL_WIRE, escalatedAt: '2026-11-06T03:30:00.000Z', assignedTo: { id: 'stf-2', name: 'Karimova Kamola' } });
    expect(detail.escalatedAt).toBe('2026-11-06T03:30:00.000Z');
    expect(detail.assignedTo).toEqual({ id: 'stf-2', name: 'Karimova Kamola' });
  });

  it('yozishma bo\'sh/yo\'q (eski backend): bolaning birinchi so\'zi `initial` xabari sifatida saqlanadi', () => {
    for (const messages of [undefined, null, []]) {
      const detail = toCareRequestDetail({ ...DETAIL_WIRE, messages });
      expect(detail.messages).toEqual([
        { id: 'initial', author: 'CHILD', authorName: null, text: 'Meni masxara qilishadi', createdAt: '2026-11-06T02:52:00.000Z' },
      ]);
    }
  });

  it('notes/notified yo\'q bo\'lsa — bo\'sh; noto\'g\'ri shakl — aniq xato', () => {
    const { notes: _n, notified: _nt, ...bare } = DETAIL_WIRE;
    void [_n, _nt];
    expect(toCareRequestDetail(bare)).toMatchObject({ notes: [], notified: [], notesCount: 0 });
    expect(() => toCareRequestDetail({ ...DETAIL_WIRE, messages: 'x' })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toCareRequestDetail({ ...DETAIL_WIRE, messages: [{ id: 'm', author: 'ADMIN', text: 'x', createdAt: 'z' }] })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toCareRequestDetail({ ...DETAIL_WIRE, openedBy: { id: 'x' } })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toCareRequestDetail(null)).toThrowError(/kutilmagan javob shakli/);
  });
});

describe('toCareMessage', () => {
  it('POST /messages javobi (kontrakt B): { id, author, authorName, text, createdAt }', () => {
    expect(toCareMessage({ id: 'm9', author: 'STAFF', authorName: 'Sobirova Lola', text: 'Salom', createdAt: '2026-11-06T05:00:00.000Z' })).toEqual({
      id: 'm9',
      author: 'STAFF',
      authorName: 'Sobirova Lola',
      text: 'Salom',
      createdAt: '2026-11-06T05:00:00.000Z',
    });
  });

  it('bola xabarida authorName doim null; muallif noma\'lum bo\'lsa xato', () => {
    expect(toCareMessage({ id: 'm', author: 'CHILD', authorName: 'Aliyev', text: 'x', createdAt: 'z' }).authorName).toBeNull();
    expect(() => toCareMessage({ id: 'm', author: 'PARENT', text: 'x', createdAt: 'z' })).toThrowError(/kutilmagan javob shakli/);
    expect(() => toCareMessage('x')).toThrowError(/kutilmagan javob shakli/);
  });
});

describe('backend xatolari (kontrakt B/C) → panel xatolari', () => {
  it('yopilgan murojaatga javob: 409 REQUEST_CLOSED → CONFLICT (kod ro\'yxatda yo\'q — status bo\'yicha)', () => {
    const error = toServiceError(409, { statusCode: 409, code: 'REQUEST_CLOSED', message: 'Murojaat yopilgan' });
    expect(error).toMatchObject({ code: 'CONFLICT', message: 'Murojaat yopilgan' });
  });

  it('sozlama tekshiruvi: 400 `maydon: errors.form.kalit` xabari saqlanadi (forma maydonga bog\'laydi)', () => {
    const error = toServiceError(400, { statusCode: 400, code: 'VALIDATION', message: 'workEnd: errors.form.endBeforeStart' });
    expect(error).toMatchObject({ code: 'VALIDATION', message: 'workEnd: errors.form.endBeforeStart' });
  });

  it('kunlik limit (429) va boshqa kodlar — UNKNOWN; ruxsat yo\'q — FORBIDDEN', () => {
    expect(toServiceError(429, { code: 'TOO_MANY' }).code).toBe('UNKNOWN');
    expect(toServiceError(403, { code: 'FORBIDDEN' }).code).toBe('FORBIDDEN');
  });
});

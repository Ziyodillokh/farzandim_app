import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { setAccessToken, setRefreshHandler, setSessionLostHandler } from '../client';
import { accessHttp, linkRequestsHttp } from '../services/access';
import {
  asStudentArchived,
  isNotLinked,
  toChildCredentials,
  toGeneratedInviteCode,
  toInviteCode,
  toIssueBody,
  toIssuedCredentials,
  toLinkDecision,
  toLinkRequests,
  toRecoveryRequests,
  toStudentRecoveryRequests,
} from '../services/access-adapters';

const MALFORMED = /kutilmagan javob shakli/;

/*
 * Quyidagi JSON'lar backend hujjatlaridan AYNAN ko'chirilgan:
 *  K1 `docs/KIRISH-AUTH-API.md` §2, §5, §8   |   K2 `docs/KIRISH-SCHOOL-API.md` §2, §5.
 * (Hujjatdagi qisqartirilgan id'lar — «5d3c…» — ham o'zgartirilmagan.)
 */

/** K1 §2: `GET …/credentials`. */
const K1_CREDENTIALS = { login: 'aziza.k24', issuedBy: 'PARENT', issuedAt: '2026-11-09T09:00:00.000Z', mustChangePassword: true, lastLoginAt: null };
/** K1 §2: `POST …/credentials` → 201. */
const K1_ISSUED = { login: 'aziza.k24', temporaryPassword: 'k7m2qx9d', issuedAt: '2026-11-09T09:00:00.000Z' };
/** K1 §5: o'quvchi kartasidagi `recoveryRequests` elementi. */
const K1_RECOVERY = { id: 'f1c2…', channel: 'SCHOOL', status: 'RECEIVED', createdAt: '2026-11-09T09:00:00.000Z' };
/** K2 §2: `GET …/invite-code` (faol kod). */
const K2_INVITE = {
  id: '5d3c…',
  code: '048213',
  expiresAt: '2026-11-10T09:30:12.345Z',
  createdAt: '2026-11-09T09:30:12.345Z',
  student: { status: 'FREE', usedAt: null },
  parent: { status: 'USED', usedAt: '2026-11-09T10:02:44.001Z' },
};
/** K2 §2: `POST …/invite-code` → 201. */
const K2_GENERATED = { code: '048213', expiresAt: '2026-11-10T09:30:12.345Z' };
/** K2 §5: `GET /school/link-requests` (ikki tur). */
const K2_REVIEW = {
  id: '5d3c…:7a21…',
  kind: 'REVIEW',
  createdAt: '2026-11-09T10:01:02.000Z',
  student: { id: '…', fullName: 'Karimov Aziz', classId: '…', className: '7-A' },
  child: { name: 'Aziz' },
  parentLinked: false,
  reason: null,
  note: null,
};
const K2_CORRECTION = {
  id: '9b8f…',
  kind: 'CORRECTION',
  createdAt: '2026-11-09T11:20:00.000Z',
  student: { id: '…', fullName: 'Rahimov Bobur', classId: '…', className: '7-A' },
  child: { name: 'Bobur' },
  parentLinked: true,
  reason: 'WRONG_SCHOOL_OR_CLASS',
  note: 'Men 7-B sinfdaman',
};
const K2_LIST = [K2_REVIEW, K2_CORRECTION];

/** Backend xato tanalari (`{ statusCode, code, message }`; xabarlar backend kodidan). */
const ERR = {
  notLinked: { statusCode: 409, code: 'NOT_LINKED', message: 'Student is not linked to a Parvoz child profile' },
  archived: { statusCode: 409, code: 'STUDENT_ARCHIVED', message: 'Student is archived' },
  loginTaken: { statusCode: 409, code: 'LOGIN_TAKEN', message: 'Login is taken' },
  inviteArchived: { statusCode: 409, code: 'CONFLICT', message: 'archived' },
  stale: { statusCode: 409, code: 'REQUEST_STALE', message: 'Link request is no longer open' },
  elsewhere: { statusCode: 409, code: 'STUDENT_LINKED_ELSEWHERE', message: 'Linked by another family member' },
  enrolled: { statusCode: 409, code: 'ALREADY_ENROLLED', message: 'Child is already linked to a student' },
  gone: { statusCode: 404, code: 'NOT_FOUND', message: 'Link request not found' },
  forbidden: { statusCode: 403, code: 'FORBIDDEN', message: 'class c1' },
};

describe('toChildCredentials (K1 §2)', () => {
  it('hujjatdagi JSON aynan shu maydonlarga; ortiqcha (parol xeshi kabi) maydonlar o\'tkazilmaydi', () => {
    expect(toChildCredentials(K1_CREDENTIALS)).toEqual(K1_CREDENTIALS);
    const view = toChildCredentials({ ...K1_CREDENTIALS, passwordHash: '$2b$12$x', childId: 'c1', failedLogins: 2, lastLoginAt: '2026-11-10T10:00:00.000Z' });
    expect(view).toEqual({ ...K1_CREDENTIALS, lastLoginAt: '2026-11-10T10:00:00.000Z' });
    expect(Object.keys(view ?? {}).sort()).toEqual(['issuedAt', 'issuedBy', 'lastLoginAt', 'login', 'mustChangePassword']);
  });

  it('maktab bergan; null va bo\'sh tana — "berilmagan"', () => {
    expect(toChildCredentials({ ...K1_CREDENTIALS, issuedBy: 'SCHOOL' })?.issuedBy).toBe('SCHOOL');
    expect(toChildCredentials(null)).toBeNull();
    expect(toChildCredentials(undefined)).toBeNull();
  });

  const broken: Array<[string, unknown]> = [
    ['obyekt emas', 'ok'],
    ['massiv', []],
    ['login yo\'q', { ...K1_CREDENTIALS, login: undefined }],
    ['login bo\'sh', { ...K1_CREDENTIALS, login: '' }],
    ['issuedBy noma\'lum', { ...K1_CREDENTIALS, issuedBy: 'ADMIN' }],
    ['issuedBy kichik harf', { ...K1_CREDENTIALS, issuedBy: 'school' }],
    ['issuedAt yo\'q', { ...K1_CREDENTIALS, issuedAt: null }],
    ['mustChangePassword satr', { ...K1_CREDENTIALS, mustChangePassword: 'true' }],
    ['mustChangePassword yo\'q', { ...K1_CREDENTIALS, mustChangePassword: undefined }],
    ['lastLoginAt son', { ...K1_CREDENTIALS, lastLoginAt: 1730000000 }],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toChildCredentials(wire)).toThrowError(MALFORMED);
  });
});

describe('toIssuedCredentials (K1 §2: 201 { login, temporaryPassword, issuedAt })', () => {
  it('hujjatdagi JSON; ortiqchasi tashlanadi', () => {
    expect(toIssuedCredentials(K1_ISSUED)).toEqual(K1_ISSUED);
    expect(toIssuedCredentials({ ...K1_ISSUED, passwordHash: 'x', childId: 'c1' })).toEqual(K1_ISSUED);
  });

  it('parol yo\'q yoki noto\'g\'ri tur — xato, va xato matnida parol/qiymat YO\'Q', () => {
    for (const wire of [{ ...K1_ISSUED, temporaryPassword: undefined }, { ...K1_ISSUED, temporaryPassword: '' }, { ...K1_ISSUED, temporaryPassword: 12345678 }, null, 'k7m2qx9d']) {
      expect(() => toIssuedCredentials(wire)).toThrowError(MALFORMED);
    }
    let thrown: unknown;
    try {
      toIssuedCredentials({ ...K1_ISSUED, login: 5 });
    } catch (error) {
      thrown = error;
    }
    expect(thrown).toBeInstanceOf(ServiceError);
    expect((thrown as ServiceError).message).toMatch(MALFORMED);
    expect((thrown as ServiceError).message).not.toContain(K1_ISSUED.temporaryPassword);
  });
});

describe('toIssueBody (K1 §2: { login?, signOutDevices? })', () => {
  it('faqat berilganlari: bo\'sh login tushiriladi (tizim taklif qiladi), login kichik harfga', () => {
    expect(toIssueBody({})).toEqual({});
    expect(toIssueBody({ login: '' })).toEqual({});
    expect(toIssueBody({ login: '   ' })).toEqual({});
    expect(toIssueBody({ login: ' Aziza.K24 ' })).toEqual({ login: 'aziza.k24' });
    expect(toIssueBody({ signOutDevices: false })).toEqual({ signOutDevices: false });
    expect(toIssueBody({ login: 'ali.v10', signOutDevices: true })).toEqual({ login: 'ali.v10', signOutDevices: true });
  });
});

describe('toRecoveryRequests (K1 §5: o\'quvchi kartasidagi recoveryRequests)', () => {
  it('hujjatdagi element: { id, channel: SCHOOL, status: RECEIVED, createdAt } → panel turi', () => {
    expect(toRecoveryRequests([K1_RECOVERY])).toEqual([{ id: 'f1c2…', channel: 'SCHOOL', createdAt: '2026-11-09T09:00:00.000Z' }]);
    expect(toRecoveryRequests([])).toEqual([]);
  });

  it('faqat ochiq (RECEIVED) so\'rovlar, eng yangisi birinchi', () => {
    const list = toRecoveryRequests([
      { ...K1_RECOVERY, id: 'r1', createdAt: '2026-11-08T10:00:00.000Z', pollTokenHash: 'zzz' },
      { ...K1_RECOVERY, id: 'r2', status: 'RESTORED', createdAt: '2026-11-09T09:00:00.000Z' },
      { ...K1_RECOVERY, id: 'r3', createdAt: '2026-11-09T08:00:00.000Z' },
      { ...K1_RECOVERY, id: 'r4', status: 'REJECTED' },
      { ...K1_RECOVERY, id: 'r5', channel: 'PARENT', createdAt: '2026-11-07T08:00:00.000Z' },
    ]);
    expect(list.map((r) => r.id)).toEqual(['r3', 'r1', 'r5']);
    expect(list.every((r) => Object.keys(r).sort().join() === 'channel,createdAt,id')).toBe(true);
  });

  it('o\'quvchi kartasidan: maydon bo\'sh massiv ham bo\'lishi mumkin (`students.manage` bo\'lmagan rol)', () => {
    expect(toStudentRecoveryRequests({ id: 's1', recoveryRequests: [K1_RECOVERY] })).toHaveLength(1);
    expect(toStudentRecoveryRequests({ id: 's1', recoveryRequests: [] })).toEqual([]);
  });

  const broken: Array<[string, unknown]> = [
    ['massiv emas', { id: 'r1' }],
    ['maydon yo\'q (null)', null],
    ['element obyekt emas', ['r1']],
    ['id yo\'q', [{ ...K1_RECOVERY, id: undefined }]],
    ['createdAt yo\'q', [{ ...K1_RECOVERY, createdAt: undefined }]],
    ['kanal yo\'q', [{ ...K1_RECOVERY, channel: undefined }]],
    ['kanal noma\'lum', [{ ...K1_RECOVERY, channel: 'EMAIL' }]],
    ['status yo\'q', [{ ...K1_RECOVERY, status: undefined }]],
    ['status noma\'lum', [{ ...K1_RECOVERY, status: 'OPEN' }]],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toRecoveryRequests(wire)).toThrowError(MALFORMED);
  });

  it('o\'quvchi kartasi: obyekt emas yoki `recoveryRequests` yo\'q — xato (jim bo\'sh ro\'yxat emas)', () => {
    expect(() => toStudentRecoveryRequests(null)).toThrowError(MALFORMED);
    expect(() => toStudentRecoveryRequests({ id: 's1' })).toThrowError(MALFORMED);
  });
});

describe('toInviteCode / toGeneratedInviteCode (K2 §2)', () => {
  const FREE = { status: 'FREE', usedAt: null };

  it('GET: hujjatdagi JSON — o\'quvchi o\'rni FREE, ota-ona o\'rni USED (id va createdAt panelga kerak emas)', () => {
    expect(toInviteCode(K2_INVITE)).toEqual({
      code: '048213',
      expiresAt: '2026-11-10T09:30:12.345Z',
      student: { status: 'FREE', usedAt: null },
      parent: { status: 'USED', usedAt: '2026-11-09T10:02:44.001Z' },
    });
  });

  it.each(['FREE', 'UNDER_REVIEW', 'CONFIRMED'] as const)('o\'quvchi o\'rni uch holatdan biri: %s', (status) => {
    const usedAt = status === 'FREE' ? null : '2026-11-09T10:00:00.000Z';
    expect(toInviteCode({ ...K2_INVITE, student: { status, usedAt } })?.student).toEqual({ status, usedAt });
  });

  it('ota-ona o\'rni: FREE | USED', () => {
    expect(toInviteCode({ ...K2_INVITE, parent: FREE })?.parent).toEqual(FREE);
    expect(toInviteCode(K2_INVITE)?.parent.status).toBe('USED');
  });

  it('faol kod yo\'q: tana JSON `null` (K2 §2) yoki bo\'sh', () => {
    expect(toInviteCode(null)).toBeNull();
    expect(toInviteCode(undefined)).toBeNull();
  });

  it('POST: hujjatdagi `{ code, expiresAt }` → ikkala o\'rin bo\'sh, bosh nollar saqlanadi', () => {
    expect(toGeneratedInviteCode({ code: '000123', expiresAt: K2_GENERATED.expiresAt })).toEqual({
      code: '000123',
      expiresAt: K2_GENERATED.expiresAt,
      student: FREE,
      parent: FREE,
    });
    expect(toGeneratedInviteCode(K2_GENERATED)).toMatchObject({ code: '048213', student: FREE, parent: FREE });
  });

  const broken: Array<[string, unknown]> = [
    ['obyekt emas', 'ok'],
    ['kod 5 xonali', { ...K2_INVITE, code: '12345' }],
    ['kod harfli (8 belgili vasiy kodi)', { ...K2_INVITE, code: 'ABCD2345' }],
    ['kod son', { ...K2_INVITE, code: 48213 }],
    ['expiresAt yo\'q', { ...K2_INVITE, expiresAt: undefined }],
    ['o\'quvchi o\'rni yo\'q', { ...K2_INVITE, student: undefined }],
    ['ota-ona o\'rni yo\'q', { ...K2_INVITE, parent: undefined }],
    ['o\'quvchi holati noma\'lum', { ...K2_INVITE, student: { status: 'USED', usedAt: null } }],
    ['o\'quvchi holati yo\'q (eski mantiqiy shakl)', { ...K2_INVITE, student: { used: true, usedAt: null } }],
    ['ota-ona holati noma\'lum', { ...K2_INVITE, parent: { status: 'UNDER_REVIEW', usedAt: null } }],
    ['usedAt noto\'g\'ri tur', { ...K2_INVITE, parent: { status: 'USED', usedAt: 5 } }],
    ['tekis eski shakl (studentUsedAt/parentUsedAt)', { code: '048213', expiresAt: K2_INVITE.expiresAt, studentUsedAt: null, parentUsedAt: null }],
  ];
  it.each(broken)('GET kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toInviteCode(wire)).toThrowError(MALFORMED);
  });

  it('POST: kod yoki muddat yo\'q — xato', () => {
    expect(() => toGeneratedInviteCode({ expiresAt: K2_GENERATED.expiresAt })).toThrowError(MALFORMED);
    expect(() => toGeneratedInviteCode({ code: '123456' })).toThrowError(MALFORMED);
    expect(() => toGeneratedInviteCode({ code: 'ABC', expiresAt: K2_GENERATED.expiresAt })).toThrowError(MALFORMED);
    expect(() => toGeneratedInviteCode(null)).toThrowError(MALFORMED);
  });
});

describe('toLinkRequests (K2 §5: GET /school/link-requests)', () => {
  it('hujjatdagi massiv: ichma-ich o\'quvchi, bola ismi, parentLinked; tartib backendniki (eng eskilari birinchi)', () => {
    expect(toLinkRequests(K2_LIST)).toEqual([
      {
        id: '5d3c…:7a21…',
        kind: 'REVIEW',
        createdAt: '2026-11-09T10:01:02.000Z',
        student: { id: '…', fullName: 'Karimov Aziz', classId: '…', className: '7-A' },
        child: { name: 'Aziz' },
        parentLinked: false,
        reason: null,
        note: null,
      },
      {
        id: '9b8f…',
        kind: 'CORRECTION',
        createdAt: '2026-11-09T11:20:00.000Z',
        student: { id: '…', fullName: 'Rahimov Bobur', classId: '…', className: '7-A' },
        child: { name: 'Bobur' },
        parentLinked: true,
        reason: 'WRONG_SCHOOL_OR_CLASS',
        note: 'Men 7-B sinfdaman',
      },
    ]);
    // Adapter qayta tartiblamaydi: backend tartibi — navbat tartibi.
    expect(toLinkRequests([...K2_LIST].reverse()).map((r) => r.id)).toEqual(['9b8f…', '5d3c…:7a21…']);
  });

  it('REVIEW id\'si shaffof: o\'zgartirilmaydi (":" saqlanadi)', () => {
    const id = '5d3c9e1a-0b1c-4d2e-8f3a-1b2c3d4e5f60:7a21c3d4-5e6f-4a1b-9c2d-3e4f5a6b7c8d';
    expect(toLinkRequests([{ ...K2_REVIEW, id }])[0]?.id).toBe(id);
  });

  it('bo\'sh ro\'yxat', () => {
    expect(toLinkRequests([])).toEqual([]);
  });

  it('sinfsiz o\'quvchi: classId null, className bo\'sh satr (backend shunday beradi)', () => {
    expect(toLinkRequests([{ ...K2_REVIEW, student: { ...K2_REVIEW.student, classId: null, className: '' } }])[0]?.student).toEqual({
      id: '…',
      fullName: 'Karimov Aziz',
      classId: null,
      className: '',
    });
  });

  it('izoh kesiladi; bo\'sh izoh — null; yangi (noma\'lum) sabab butun ro\'yxatni buzmaydi', () => {
    expect(toLinkRequests([{ ...K2_CORRECTION, note: '  Men 7-B sinfdaman  ' }])[0]?.note).toBe('Men 7-B sinfdaman');
    expect(toLinkRequests([{ ...K2_CORRECTION, note: '   ' }])[0]?.note).toBeNull();
    expect(toLinkRequests([{ ...K2_CORRECTION, reason: 'WRONG_CHILD' }])[0]?.reason).toBeNull();
  });

  const broken: Array<[string, unknown]> = [
    ['javob massiv emas', 'ok'],
    ['{ items } o\'ramasi (hujjatda yo\'q)', { items: K2_LIST }],
    ['bo\'sh tana', undefined],
    ['element obyekt emas', ['x']],
    ['id yo\'q', [{ ...K2_REVIEW, id: undefined }]],
    ['tur yo\'q', [{ ...K2_REVIEW, kind: undefined }]],
    ['tur noma\'lum', [{ ...K2_REVIEW, kind: 'BOSHQA' }]],
    ['tur — prototip kaliti', [{ ...K2_REVIEW, kind: 'constructor' }]],
    ['tur sinonimi (LINK_REVIEW)', [{ ...K2_REVIEW, kind: 'LINK_REVIEW' }]],
    ['vaqt yo\'q', [{ ...K2_REVIEW, createdAt: undefined }]],
    ['o\'quvchi yo\'q (eski tekis shakl)', [{ ...K2_REVIEW, student: undefined, studentName: 'Karimov Aziz', className: '7-A' }]],
    ['o\'quvchi id\'si yo\'q', [{ ...K2_REVIEW, student: { ...K2_REVIEW.student, id: '' } }]],
    ['o\'quvchi ismi yo\'q', [{ ...K2_REVIEW, student: { ...K2_REVIEW.student, fullName: '' } }]],
    ['sinf noto\'g\'ri tur', [{ ...K2_REVIEW, student: { ...K2_REVIEW.student, className: 7 } }]],
    ['bola yo\'q', [{ ...K2_REVIEW, child: undefined }]],
    ['bola ismi yo\'q', [{ ...K2_REVIEW, child: { name: '' } }]],
    ['parentLinked yo\'q (eski parentUsed)', [{ ...K2_REVIEW, parentLinked: undefined, parentUsed: false }]],
    ['parentLinked satr', [{ ...K2_REVIEW, parentLinked: 'true' }]],
    ['izoh noto\'g\'ri tur', [{ ...K2_CORRECTION, note: 5 }]],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toLinkRequests(wire)).toThrowError(MALFORMED);
  });
});

describe('toLinkDecision (K2 §5: 200 { id, kind, status })', () => {
  it('confirm → CONFIRMED, reject → REJECTED (ikkala tur uchun)', () => {
    expect(toLinkDecision({ id: '5d3c…:7a21…', kind: 'REVIEW', status: 'CONFIRMED' }, 'confirm')).toEqual({ id: '5d3c…:7a21…', kind: 'REVIEW', status: 'CONFIRMED' });
    expect(toLinkDecision({ id: '5d3c…:7a21…', kind: 'REVIEW', status: 'REJECTED' }, 'reject').status).toBe('REJECTED');
    expect(toLinkDecision({ id: '9b8f…', kind: 'CORRECTION', status: 'CONFIRMED' }, 'confirm')).toMatchObject({ kind: 'CORRECTION', status: 'CONFIRMED' });
    expect(toLinkDecision({ id: '9b8f…', kind: 'CORRECTION', status: 'REJECTED' }, 'reject')).toMatchObject({ kind: 'CORRECTION', status: 'REJECTED' });
  });

  it('so\'ralgan amalga mos kelmaydigan natija — xato (UI teskari natijani "bajarildi" demasin)', () => {
    expect(() => toLinkDecision({ id: 'x', kind: 'REVIEW', status: 'REJECTED' }, 'confirm')).toThrowError(MALFORMED);
    expect(() => toLinkDecision({ id: 'x', kind: 'CORRECTION', status: 'CONFIRMED' }, 'reject')).toThrowError(MALFORMED);
  });

  const broken: Array<[string, unknown]> = [
    ['obyekt emas', 'ok'],
    ['bo\'sh tana', undefined],
    ['id yo\'q', { kind: 'REVIEW', status: 'CONFIRMED' }],
    ['tur noma\'lum', { id: 'x', kind: 'OTHER', status: 'CONFIRMED' }],
    ['status noma\'lum', { id: 'x', kind: 'REVIEW', status: 'OPEN' }],
    ['status yo\'q', { id: 'x', kind: 'REVIEW' }],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toLinkDecision(wire, 'confirm')).toThrowError(MALFORMED);
  });
});

describe('xato kodlari', () => {
  it('isNotLinked: aniq NOT_LINKED kodi (status qat\'iy emas); boshqa kod yoki oddiy xato — yo\'q', () => {
    expect(isNotLinked(new ServiceError('CONFLICT', 'x', 'NOT_LINKED'))).toBe(true);
    expect(isNotLinked(new ServiceError('NOT_FOUND', 'x', 'NOT_LINKED'))).toBe(true);
    expect(isNotLinked(new ServiceError('CONFLICT', 'x', 'LOGIN_TAKEN'))).toBe(false);
    expect(isNotLinked(new ServiceError('CONFLICT', 'x'))).toBe(false);
    expect(isNotLinked(new Error('NOT_LINKED'))).toBe(false);
  });

  it('asStudentArchived: faqat umumiy CONFLICT (aniq kodsiz 409) STUDENT_ARCHIVED bo\'ladi', () => {
    const generic = asStudentArchived(new ServiceError('CONFLICT', 'archived', 'CONFLICT'));
    expect(generic).toBeInstanceOf(ServiceError);
    expect(generic).toMatchObject({ code: 'CONFLICT', detail: 'STUDENT_ARCHIVED' });
    expect(asStudentArchived(new ServiceError('CONFLICT', 'archived', null))).toMatchObject({ detail: 'STUDENT_ARCHIVED' });
    // Aniq kod bor bo'lsa (yoki boshqa tur) — o'zgarishsiz.
    const specific = new ServiceError('CONFLICT', 'x', 'STUDENT_ARCHIVED');
    expect(asStudentArchived(specific)).toBe(specific);
    const other = new ServiceError('CONFLICT', 'x', 'REQUEST_STALE');
    expect(asStudentArchived(other)).toBe(other);
    const forbidden = new ServiceError('FORBIDDEN', 'x', 'FORBIDDEN');
    expect(asStudentArchived(forbidden)).toBe(forbidden);
    const plain = new Error('boom');
    expect(asStudentArchived(plain)).toBe(plain);
  });
});

// ── HTTP servislari (fetch soxta) ────────────────────────────────────────

type Call = { url: string; method: string; body: string | null };

function mockFetch(responses: Array<{ status: number; body?: unknown; text?: string }>): Call[] {
  const calls: Call[] = [];
  const queue = [...responses];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, method: String(init.method), body: typeof init.body === 'string' ? init.body : null });
      const next = queue.shift() ?? { status: 500 };
      const payload = next.text ?? (next.body === undefined ? null : JSON.stringify(next.body));
      return new Response(payload, { status: next.status });
    }),
  );
  return calls;
}

function useFakeSession(): void {
  beforeEach(() => {
    setAccessToken('t1');
    setRefreshHandler(async () => false);
    setSessionLostHandler(null);
  });
  afterEach(() => vi.unstubAllGlobals());
}

describe('accessHttp: kirish ma\'lumotlari (K1)', () => {
  useFakeSession();

  it('credentials: GET /school/students/:id/credentials → linked: true', async () => {
    const calls = mockFetch([{ status: 200, body: K1_CREDENTIALS }]);
    await expect(accessHttp.credentials('stu 1')).resolves.toEqual({ linked: true, credentials: K1_CREDENTIALS });
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/school/students/stu%201/credentials' });
  });

  it('credentials: matni `null` (K1 §2) yoki bo\'sh tana — ulangan, lekin berilmagan', async () => {
    mockFetch([{ status: 200, text: 'null' }]);
    await expect(accessHttp.credentials('s1')).resolves.toEqual({ linked: true, credentials: null });
    mockFetch([{ status: 200 }]);
    await expect(accessHttp.credentials('s1')).resolves.toEqual({ linked: true, credentials: null });
  });

  it('credentials: 409 NOT_LINKED xato emas — linked: false', async () => {
    mockFetch([{ status: 409, body: ERR.notLinked }]);
    await expect(accessHttp.credentials('s1')).resolves.toEqual({ linked: false, credentials: null });
  });

  it('credentials: boshqa 409, 403 va 404 — xato sifatida o\'tadi', async () => {
    mockFetch([{ status: 409, body: { statusCode: 409, code: 'SOMETHING_ELSE', message: 'x' } }]);
    await expect(accessHttp.credentials('s1')).rejects.toMatchObject({ code: 'CONFLICT', detail: 'SOMETHING_ELSE' });
    mockFetch([{ status: 403, body: ERR.forbidden }]);
    await expect(accessHttp.credentials('s1')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    mockFetch([{ status: 404, body: { statusCode: 404, code: 'NOT_FOUND', message: 's1' } }]);
    await expect(accessHttp.credentials('s1')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('issueCredentials: POST tanasi faqat berilganlar; 201 javobi adapterdan o\'tadi', async () => {
    const calls = mockFetch([{ status: 201, body: K1_ISSUED }, { status: 201, body: K1_ISSUED }]);
    await expect(accessHttp.issueCredentials('s1')).resolves.toEqual(K1_ISSUED);
    await accessHttp.issueCredentials('s1', { login: ' Aziza.K24 ', signOutDevices: false });
    expect(calls.map((c) => [c.method, c.url, c.body])).toEqual([
      ['POST', '/api/school/students/s1/credentials', '{}'],
      ['POST', '/api/school/students/s1/credentials', '{"login":"aziza.k24","signOutDevices":false}'],
    ]);
  });

  it('issueCredentials: 409 LOGIN_TAKEN, NOT_LINKED va STUDENT_ARCHIVED — aniq detail bilan', async () => {
    mockFetch([{ status: 409, body: ERR.loginTaken }]);
    await expect(accessHttp.issueCredentials('s1', { login: 'aziza.k24' })).rejects.toMatchObject({ code: 'CONFLICT', detail: 'LOGIN_TAKEN' });
    mockFetch([{ status: 409, body: ERR.notLinked }]);
    await expect(accessHttp.issueCredentials('s1')).rejects.toSatisfy(isNotLinked);
    mockFetch([{ status: 409, body: ERR.archived }]);
    await expect(accessHttp.issueCredentials('s1')).rejects.toMatchObject({ code: 'CONFLICT', detail: 'STUDENT_ARCHIVED' });
  });

  it('issueCredentials: javobda parol bo\'lmasa — xato (jim standart qiymat emas)', async () => {
    mockFetch([{ status: 201, body: { login: 'aziza.k24', issuedAt: '2026-11-09T09:00:00.000Z' } }]);
    await expect(accessHttp.issueCredentials('s1')).rejects.toThrowError(MALFORMED);
  });

  it('recoveryRequests: o\'quvchi kartasi (GET /school/students/:id) ichidagi `recoveryRequests`', async () => {
    const calls = mockFetch([{ status: 200, body: { id: 's1', lastName: 'Karimov', recoveryRequests: [K1_RECOVERY] } }]);
    await expect(accessHttp.recoveryRequests('s1')).resolves.toEqual([{ id: 'f1c2…', channel: 'SCHOOL', createdAt: '2026-11-09T09:00:00.000Z' }]);
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/school/students/s1' });
    mockFetch([{ status: 200, body: { id: 's1', recoveryRequests: [] } }]);
    await expect(accessHttp.recoveryRequests('s1')).resolves.toEqual([]);
    // Maydon yo'q — jim bo'sh ro'yxat emas, aniq xato.
    mockFetch([{ status: 200, body: { id: 's1' } }]);
    await expect(accessHttp.recoveryRequests('s1')).rejects.toThrowError(MALFORMED);
  });

  it('rejectRecovery: POST /school/students/:id/recovery-requests/:requestId/reject (200 REJECTED ko\'rinishi)', async () => {
    const calls = mockFetch([{ status: 200, body: { ...K1_RECOVERY, status: 'REJECTED' } }]);
    await expect(accessHttp.rejectRecovery('s1', 'r 1')).resolves.toBeUndefined();
    expect(calls[0]).toMatchObject({ method: 'POST', url: '/api/school/students/s1/recovery-requests/r%201/reject', body: null });
  });

  it('rejectRecovery: 404 REQUEST_NOT_FOUND va 409 ALREADY_RESOLVED / NOT_LINKED — aniq detail', async () => {
    mockFetch([{ status: 404, body: { statusCode: 404, code: 'REQUEST_NOT_FOUND', message: 'x' } }]);
    await expect(accessHttp.rejectRecovery('s1', 'r1')).rejects.toMatchObject({ code: 'NOT_FOUND', detail: 'REQUEST_NOT_FOUND' });
    mockFetch([{ status: 409, body: { statusCode: 409, code: 'ALREADY_RESOLVED', message: 'x' } }]);
    await expect(accessHttp.rejectRecovery('s1', 'r1')).rejects.toMatchObject({ code: 'CONFLICT', detail: 'ALREADY_RESOLVED' });
    mockFetch([{ status: 409, body: ERR.notLinked }]);
    await expect(accessHttp.rejectRecovery('s1', 'r1')).rejects.toSatisfy(isNotLinked);
  });
});

describe('accessHttp: maktab kodi (K2 §2)', () => {
  useFakeSession();

  it('inviteCode: faol kod hujjatdagi JSON\'dan', async () => {
    const calls = mockFetch([{ status: 200, body: K2_INVITE }]);
    await expect(accessHttp.inviteCode('s1')).resolves.toMatchObject({
      code: '048213',
      student: { status: 'FREE', usedAt: null },
      parent: { status: 'USED', usedAt: '2026-11-09T10:02:44.001Z' },
    });
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/school/students/s1/invite-code' });
  });

  it('inviteCode: faol kod yo\'q — matni `null` (200); bo\'sh tana ham shunday', async () => {
    mockFetch([{ status: 200, text: 'null' }]);
    await expect(accessHttp.inviteCode('s1')).resolves.toBeNull();
    mockFetch([{ status: 200 }]);
    await expect(accessHttp.inviteCode('s1')).resolves.toBeNull();
  });

  it('inviteCode: 404 (begona maktab / noma\'lum id) "kod yo\'q" EMAS — xato; 403 ham', async () => {
    mockFetch([{ status: 404, body: { statusCode: 404, code: 'NOT_FOUND', message: 's1' } }]);
    await expect(accessHttp.inviteCode('s1')).rejects.toMatchObject({ code: 'NOT_FOUND' });
    mockFetch([{ status: 403, body: ERR.forbidden }]);
    await expect(accessHttp.inviteCode('s1')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('inviteCode: eski taxminiy shakl (tekis studentUsedAt) endi aniq xato', async () => {
    mockFetch([{ status: 200, body: { code: '123456', expiresAt: '2026-11-10T09:30:12.345Z', studentUsedAt: null, parentUsedAt: null } }]);
    await expect(accessHttp.inviteCode('s1')).rejects.toThrowError(MALFORMED);
  });

  it('generateInviteCode: POST /school/students/:id/invite-code → 201 { code, expiresAt }', async () => {
    const calls = mockFetch([{ status: 201, body: K2_GENERATED }]);
    await expect(accessHttp.generateInviteCode('s1')).resolves.toEqual({
      code: '048213',
      expiresAt: '2026-11-10T09:30:12.345Z',
      student: { status: 'FREE', usedAt: null },
      parent: { status: 'FREE', usedAt: null },
    });
    expect(calls[0]).toMatchObject({ method: 'POST', url: '/api/school/students/s1/invite-code', body: null });
  });

  it('generateInviteCode: arxivdagi o\'quvchi — 409 CONFLICT → STUDENT_ARCHIVED; 403 o\'zgarishsiz', async () => {
    mockFetch([{ status: 409, body: ERR.inviteArchived }]);
    await expect(accessHttp.generateInviteCode('s1')).rejects.toMatchObject({ code: 'CONFLICT', detail: 'STUDENT_ARCHIVED' });
    mockFetch([{ status: 403, body: ERR.forbidden }]);
    await expect(accessHttp.generateInviteCode('s1')).rejects.toMatchObject({ code: 'FORBIDDEN', detail: 'FORBIDDEN' });
  });
});

describe('linkRequestsHttp (K2 §5)', () => {
  useFakeSession();

  it('list: GET /school/link-requests — hujjatdagi JSON adapterdan o\'tadi', async () => {
    const calls = mockFetch([{ status: 200, body: K2_LIST }]);
    const list = await linkRequestsHttp.list();
    expect(list.map((r) => [r.id, r.kind, r.student.fullName, r.child.name, r.parentLinked])).toEqual([
      ['5d3c…:7a21…', 'REVIEW', 'Karimov Aziz', 'Aziz', false],
      ['9b8f…', 'CORRECTION', 'Rahimov Bobur', 'Bobur', true],
    ]);
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/school/link-requests' });
  });

  it('confirm / reject: REVIEW id\'si ("<kod>:<bola>") o\'zgartirilmay URL-kodlanadi; 200 { id, kind, status }', async () => {
    const id = '5d3c9e1a-0b1c-4d2e-8f3a-1b2c3d4e5f60:7a21c3d4-5e6f-4a1b-9c2d-3e4f5a6b7c8d';
    const calls = mockFetch([
      { status: 200, body: { id, kind: 'REVIEW', status: 'CONFIRMED' } },
      { status: 200, body: { id, kind: 'REVIEW', status: 'REJECTED' } },
    ]);
    await expect(linkRequestsHttp.confirm(id)).resolves.toEqual({ id, kind: 'REVIEW', status: 'CONFIRMED' });
    await expect(linkRequestsHttp.reject(id)).resolves.toEqual({ id, kind: 'REVIEW', status: 'REJECTED' });
    const encoded = encodeURIComponent(id);
    expect(encoded).toContain('%3A');
    expect(calls.map((c) => [c.method, c.url, c.body])).toEqual([
      ['POST', `/api/school/link-requests/${encoded}/confirm`, null],
      ['POST', `/api/school/link-requests/${encoded}/reject`, null],
    ]);
  });

  it('CORRECTION: confirm = ulanishni SAQLASH (CONFIRMED), reject = UZISH (REJECTED)', async () => {
    const calls = mockFetch([
      { status: 200, body: { id: '9b8f…', kind: 'CORRECTION', status: 'CONFIRMED' } },
      { status: 200, body: { id: '9b8f…', kind: 'CORRECTION', status: 'REJECTED' } },
    ]);
    await expect(linkRequestsHttp.confirm('9b8f…')).resolves.toMatchObject({ kind: 'CORRECTION', status: 'CONFIRMED' });
    await expect(linkRequestsHttp.reject('9b8f…')).resolves.toMatchObject({ kind: 'CORRECTION', status: 'REJECTED' });
    expect(calls.map((c) => c.url.split('/').pop())).toEqual(['confirm', 'reject']);
  });

  it('confirm: teskari natija qaytsa — shakl xatosi', async () => {
    mockFetch([{ status: 200, body: { id: 'x', kind: 'REVIEW', status: 'REJECTED' } }]);
    await expect(linkRequestsHttp.confirm('x')).rejects.toThrowError(MALFORMED);
  });

  it.each([
    ['REQUEST_STALE', 409, ERR.stale, { code: 'CONFLICT', detail: 'REQUEST_STALE' }],
    ['STUDENT_LINKED_ELSEWHERE', 409, ERR.elsewhere, { code: 'CONFLICT', detail: 'STUDENT_LINKED_ELSEWHERE' }],
    ['ALREADY_ENROLLED', 409, ERR.enrolled, { code: 'CONFLICT', detail: 'ALREADY_ENROLLED' }],
    ['404 so\'rov topilmadi', 404, ERR.gone, { code: 'NOT_FOUND', detail: 'NOT_FOUND' }],
    ['403 sinf doirasidan tashqari', 403, ERR.forbidden, { code: 'FORBIDDEN', detail: 'FORBIDDEN' }],
  ])('xato: %s — ServiceError kodi va detail', async (_name, status, body, expected) => {
    mockFetch([{ status, body }, { status, body }]);
    await expect(linkRequestsHttp.confirm('l1')).rejects.toMatchObject(expected);
    await expect(linkRequestsHttp.reject('l1')).rejects.toMatchObject(expected);
  });
});

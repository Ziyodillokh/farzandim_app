import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { setAccessToken, setRefreshHandler, setSessionLostHandler } from '../client';
import { accessHttp, linkRequestsHttp } from '../services/access';
import {
  isLoginTaken,
  isNotLinked,
  toChildCredentials,
  toGeneratedInviteCode,
  toInviteCode,
  toIssueBody,
  toIssuedCredentials,
  toLinkRequests,
  toRecoveryRequests,
} from '../services/access-adapters';

const MALFORMED = /kutilmagan javob shakli/;

/** Kontrakt K1: `GET /school/students/:id/credentials`. */
const CREDENTIALS_WIRE = {
  login: 'aziza.k24',
  issuedBy: 'SCHOOL',
  issuedAt: '2026-11-06T04:00:00.000Z',
  mustChangePassword: true,
  lastLoginAt: null,
};

describe('toChildCredentials (kontrakt K1)', () => {
  it('aynan kontrakt maydonlari; ortiqcha (parol xeshi kabi) maydonlar o\'tkazilmaydi', () => {
    const view = toChildCredentials({ ...CREDENTIALS_WIRE, passwordHash: '$2b$12$x', childId: 'c1', failedLogins: 2, lastLoginAt: '2026-11-05T10:00:00.000Z' });
    expect(view).toEqual({ ...CREDENTIALS_WIRE, lastLoginAt: '2026-11-05T10:00:00.000Z' });
    expect(Object.keys(view ?? {}).sort()).toEqual(['issuedAt', 'issuedBy', 'lastLoginAt', 'login', 'mustChangePassword']);
  });

  it('null va bo\'sh javob — "berilmagan"', () => {
    expect(toChildCredentials(null)).toBeNull();
    expect(toChildCredentials(undefined)).toBeNull();
  });

  it('lastLoginAt yo\'q yoki bo\'sh — null; ota-ona bergan', () => {
    const { lastLoginAt: _omit, ...rest } = CREDENTIALS_WIRE;
    void _omit;
    expect(toChildCredentials({ ...rest, issuedBy: 'PARENT' })).toMatchObject({ issuedBy: 'PARENT', lastLoginAt: null });
    expect(toChildCredentials({ ...CREDENTIALS_WIRE, lastLoginAt: '' })?.lastLoginAt).toBeNull();
  });

  const broken: Array<[string, unknown]> = [
    ['obyekt emas', 'ok'],
    ['massiv', []],
    ['login yo\'q', { ...CREDENTIALS_WIRE, login: undefined }],
    ['login bo\'sh', { ...CREDENTIALS_WIRE, login: '' }],
    ['issuedBy noma\'lum', { ...CREDENTIALS_WIRE, issuedBy: 'ADMIN' }],
    ['issuedBy kichik harf', { ...CREDENTIALS_WIRE, issuedBy: 'school' }],
    ['issuedAt yo\'q', { ...CREDENTIALS_WIRE, issuedAt: null }],
    ['mustChangePassword satr', { ...CREDENTIALS_WIRE, mustChangePassword: 'true' }],
    ['mustChangePassword yo\'q', { ...CREDENTIALS_WIRE, mustChangePassword: undefined }],
    ['lastLoginAt son', { ...CREDENTIALS_WIRE, lastLoginAt: 1730000000 }],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toChildCredentials(wire)).toThrowError(MALFORMED);
  });
});

describe('toIssuedCredentials (kontrakt K1: 201 { login, temporaryPassword, issuedAt })', () => {
  const WIRE = { login: 'aziza.k24', temporaryPassword: 'k7m3pq9x', issuedAt: '2026-11-06T04:00:00.000Z' };

  it('uch maydon; ortiqchasi tashlanadi', () => {
    expect(toIssuedCredentials({ ...WIRE, passwordHash: 'x', childId: 'c1' })).toEqual(WIRE);
  });

  it('parol yo\'q yoki noto\'g\'ri tur — xato, va xato matnida parol/qiymat YO\'Q', () => {
    for (const wire of [{ ...WIRE, temporaryPassword: undefined }, { ...WIRE, temporaryPassword: '' }, { ...WIRE, temporaryPassword: 12345678 }, null, 'k7m3pq9x']) {
      expect(() => toIssuedCredentials(wire)).toThrowError(MALFORMED);
    }
    try {
      toIssuedCredentials({ ...WIRE, login: 5, temporaryPassword: 'k7m3pq9x' });
    } catch (error) {
      expect(String((error as Error).message)).not.toContain('k7m3pq9x');
    }
  });
});

describe('toIssueBody', () => {
  it('faqat berilganlari: bo\'sh login tushiriladi (tizim taklif qiladi), login kichik harfga', () => {
    expect(toIssueBody({})).toEqual({});
    expect(toIssueBody({ login: '' })).toEqual({});
    expect(toIssueBody({ login: '   ' })).toEqual({});
    expect(toIssueBody({ login: ' Aziza.K24 ' })).toEqual({ login: 'aziza.k24' });
    expect(toIssueBody({ signOutDevices: false })).toEqual({ signOutDevices: false });
    expect(toIssueBody({ login: 'ali.v10', signOutDevices: true })).toEqual({ login: 'ali.v10', signOutDevices: true });
  });
});

describe('toRecoveryRequests (o\'quvchi kartasi ichida)', () => {
  it('maydon yo\'q yoki null — bo\'sh ro\'yxat', () => {
    expect(toRecoveryRequests(undefined)).toEqual([]);
    expect(toRecoveryRequests(null)).toEqual([]);
    expect(toRecoveryRequests([])).toEqual([]);
  });

  it('faqat ochiq (RECEIVED yoki status yo\'q) so\'rovlar, eng yangisi birinchi; kanal ixtiyoriy', () => {
    const list = toRecoveryRequests([
      { id: 'r1', status: 'RECEIVED', channel: 'SCHOOL', createdAt: '2026-11-05T10:00:00.000Z', pollTokenHash: 'zzz' },
      { id: 'r2', status: 'RESTORED', channel: 'SCHOOL', createdAt: '2026-11-06T09:00:00.000Z' },
      { id: 'r3', createdAt: '2026-11-06T08:00:00.000Z' },
      { id: 'r4', status: 'REJECTED', createdAt: '2026-11-06T07:00:00.000Z' },
      { id: 'r5', status: 'RECEIVED', channel: 'PARENT', createdAt: '2026-11-04T08:00:00.000Z' },
    ]);
    expect(list).toEqual([
      { id: 'r3', channel: null, createdAt: '2026-11-06T08:00:00.000Z' },
      { id: 'r1', channel: 'SCHOOL', createdAt: '2026-11-05T10:00:00.000Z' },
      { id: 'r5', channel: 'PARENT', createdAt: '2026-11-04T08:00:00.000Z' },
    ]);
  });

  const broken: Array<[string, unknown]> = [
    ['massiv emas', { id: 'r1' }],
    ['element obyekt emas', ['r1']],
    ['id yo\'q', [{ createdAt: '2026-11-06T08:00:00.000Z' }]],
    ['createdAt yo\'q', [{ id: 'r1' }]],
    ['status noma\'lum', [{ id: 'r1', status: 'OPEN', createdAt: '2026-11-06T08:00:00.000Z' }]],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toRecoveryRequests(wire)).toThrowError(MALFORMED);
  });
});

describe('toInviteCode / toGeneratedInviteCode (kontrakt K2)', () => {
  const BASE = { code: '012345', expiresAt: '2026-11-07T04:00:00.000Z' };
  const PENDING = { used: false, usedAt: null };

  it('POST natijasi `{ code, expiresAt }`: ikkala o\'rin bo\'sh, bosh nollar saqlanadi', () => {
    expect(toGeneratedInviteCode({ ...BASE, id: 'x', studentId: 's1' })).toEqual({ ...BASE, student: PENDING, parent: PENDING });
  });

  it('GET: bo\'sh javob / null — faol kod yo\'q', () => {
    expect(toInviteCode(null)).toBeNull();
    expect(toInviteCode(undefined)).toBeNull();
  });

  it('GET shakl 1 (model maydonlari): studentUsedAt / parentUsedAt', () => {
    expect(toInviteCode({ ...BASE, studentUsedAt: '2026-11-06T05:00:00.000Z', parentUsedAt: null })).toEqual({
      ...BASE,
      student: { used: true, usedAt: '2026-11-06T05:00:00.000Z' },
      parent: PENDING,
    });
  });

  it('GET shakl 2 (mantiqiy): studentUsed / parentUsed', () => {
    expect(toInviteCode({ ...BASE, studentUsed: false, parentUsed: true })).toEqual({ ...BASE, student: PENDING, parent: { used: true, usedAt: null } });
  });

  it('GET shakl 3 (ichma-ich): student: { used | usedAt }, parent: { … }', () => {
    expect(toInviteCode({ ...BASE, student: { used: true }, parent: { usedAt: '2026-11-06T06:00:00.000Z' } })).toEqual({
      ...BASE,
      student: { used: true, usedAt: null },
      parent: { used: true, usedAt: '2026-11-06T06:00:00.000Z' },
    });
    expect(toInviteCode({ ...BASE, student: { used: false, usedAt: null }, parent: { used: false, usedAt: null } })).toEqual({ ...BASE, student: PENDING, parent: PENDING });
  });

  const broken: Array<[string, unknown]> = [
    ['obyekt emas', 'ok'],
    ['kod 5 xonali', { ...BASE, code: '12345', studentUsedAt: null, parentUsedAt: null }],
    ['kod harfli (8 belgili ota-ona kodi)', { ...BASE, code: 'ABCD2345', studentUsedAt: null, parentUsedAt: null }],
    ['kod son', { ...BASE, code: 123456, studentUsedAt: null, parentUsedAt: null }],
    ['expiresAt yo\'q', { code: '123456', studentUsedAt: null, parentUsedAt: null }],
    ['o\'rin holatlari yo\'q', BASE],
    ['faqat bitta o\'rin', { ...BASE, studentUsedAt: null }],
    ['o\'rin holati noto\'g\'ri tur', { ...BASE, studentUsedAt: 5, parentUsedAt: null }],
  ];
  it.each(broken)('GET kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toInviteCode(wire)).toThrowError(MALFORMED);
  });

  it('POST: kod yoki muddat yo\'q — xato', () => {
    expect(() => toGeneratedInviteCode({ expiresAt: BASE.expiresAt })).toThrowError(MALFORMED);
    expect(() => toGeneratedInviteCode({ code: '123456' })).toThrowError(MALFORMED);
    expect(() => toGeneratedInviteCode(null)).toThrowError(MALFORMED);
  });
});

describe('toLinkRequests (kontrakt K2: GET /school/link-requests)', () => {
  const REVIEW = { id: 'l1', kind: 'REVIEW', studentId: 's1', studentName: 'Karimova Aziza', className: '7-A', createdAt: '2026-11-06T04:00:00.000Z', parentUsed: true };
  const CORRECTION = {
    id: 'c1',
    kind: 'CORRECTION',
    studentId: 's2',
    studentName: 'Aliyev Vali',
    className: '8-B',
    createdAt: '2026-11-06T05:00:00.000Z',
    reason: 'WRONG_SCHOOL_OR_CLASS',
    note: '  Men 8-A da oʻqiyman  ',
  };

  it('massiv: tekshiruv va tuzatish; eng yangisi birinchi; maydonlar panel turiga', () => {
    expect(toLinkRequests([REVIEW, CORRECTION])).toEqual([
      { id: 'c1', kind: 'CORRECTION', studentId: 's2', studentName: 'Aliyev Vali', className: '8-B', createdAt: CORRECTION.createdAt, parentUsed: false, note: 'Men 8-A da oʻqiyman', reason: 'WRONG_SCHOOL_OR_CLASS' },
      { id: 'l1', kind: 'REVIEW', studentId: 's1', studentName: 'Karimova Aziza', className: '7-A', createdAt: REVIEW.createdAt, parentUsed: true, note: null, reason: null },
    ]);
  });

  it('`{ items }` va `{ links, corrections }` shakllari ham xuddi shunday', () => {
    const expected = toLinkRequests([REVIEW, CORRECTION]);
    expect(toLinkRequests({ items: [REVIEW, CORRECTION], pagination: { total: 2 } })).toEqual(expected);
    const { kind: _k1, ...review } = REVIEW;
    const { kind: _k2, ...correction } = CORRECTION;
    void _k1;
    void _k2;
    expect(toLinkRequests({ links: [review], corrections: [correction] })).toEqual(expected);
    expect(toLinkRequests({ links: [review] })).toHaveLength(1);
  });

  it('bo\'sh javob / bo\'sh ro\'yxat — bo\'sh', () => {
    expect(toLinkRequests([])).toEqual([]);
    expect(toLinkRequests({ items: [] })).toEqual([]);
    expect(toLinkRequests(null)).toEqual([]);
    expect(toLinkRequests({ links: [], corrections: [] })).toEqual([]);
  });

  it('tur sinonimlari (`type`, LINK, LINK_REVIEW, UNDER_REVIEW, LINK_CORRECTION)', () => {
    const { kind: _k, ...rest } = REVIEW;
    void _k;
    for (const declared of ['LINK', 'LINK_REVIEW', 'UNDER_REVIEW', 'REVIEW']) {
      expect(toLinkRequests([{ ...rest, type: declared }])[0]?.kind).toBe('REVIEW');
    }
    const { kind: _c, ...corr } = CORRECTION;
    void _c;
    expect(toLinkRequests([{ ...corr, type: 'LINK_CORRECTION' }])[0]?.kind).toBe('CORRECTION');
  });

  it('ota-ona o\'rni: `parentUsed` (mantiqiy) yoki `parentUsedAt` (model maydoni)', () => {
    const { parentUsed: _p, ...rest } = REVIEW;
    void _p;
    expect(toLinkRequests([{ ...rest, parentUsedAt: '2026-11-06T04:30:00.000Z' }])[0]?.parentUsed).toBe(true);
    expect(toLinkRequests([{ ...rest, parentUsedAt: null }])[0]?.parentUsed).toBe(false);
    expect(toLinkRequests([{ ...REVIEW, parentUsed: false }])[0]?.parentUsed).toBe(false);
  });

  it('ixtiyoriy qo\'shimchalar yumshoq: studentId/sinf/izoh/sabab yo\'q bo\'lsa ham ishlaydi', () => {
    const [item] = toLinkRequests([{ id: 'c9', kind: 'CORRECTION', studentName: 'Aliyev Vali', createdAt: CORRECTION.createdAt }]);
    expect(item).toMatchObject({ studentId: null, className: '—', note: null, reason: null, parentUsed: false });
    expect(toLinkRequests([{ ...CORRECTION, reason: 'BOSHQA', note: '   ' }])[0]).toMatchObject({ reason: null, note: null });
    // Tekshiruvda izoh bo'lmaydi.
    expect(toLinkRequests([{ ...REVIEW, note: 'yashirin' }])[0]?.note).toBeNull();
  });

  const broken: Array<[string, unknown]> = [
    ['javob obyekt/massiv emas', 'ok'],
    ['{ items } massiv emas', { items: 'x' }],
    ['{ links } massiv emas', { links: 'x' }],
    ['element obyekt emas', ['x']],
    ['id yo\'q', [{ ...REVIEW, id: undefined }]],
    ['tur yo\'q', [{ ...REVIEW, kind: undefined }]],
    ['tur noma\'lum', [{ ...REVIEW, kind: 'BOSHQA' }]],
    ['o\'quvchi ismi yo\'q', [{ ...REVIEW, studentName: '' }]],
    ['vaqt yo\'q', [{ ...REVIEW, createdAt: undefined }]],
    ['tekshiruvda ota-ona o\'rni holati yo\'q', [{ ...REVIEW, parentUsed: undefined }]],
  ];
  it.each(broken)('kutilmagan shakl aniq xato beradi: %s', (_name, wire) => {
    expect(() => toLinkRequests(wire)).toThrowError(MALFORMED);
  });
});

describe('xato kodlari', () => {
  it('isNotLinked / isLoginTaken faqat CONFLICT + aniq detail', () => {
    expect(isNotLinked(new ServiceError('CONFLICT', 'x', 'NOT_LINKED'))).toBe(true);
    expect(isNotLinked(new ServiceError('CONFLICT', 'x', 'LOGIN_TAKEN'))).toBe(false);
    expect(isNotLinked(new ServiceError('CONFLICT', 'x'))).toBe(false);
    expect(isNotLinked(new Error('NOT_LINKED'))).toBe(false);
    expect(isLoginTaken(new ServiceError('CONFLICT', 'x', 'LOGIN_TAKEN'))).toBe(true);
    expect(isLoginTaken(new ServiceError('NOT_FOUND', 'x', 'LOGIN_TAKEN'))).toBe(false);
  });
});

// ── HTTP servislari (fetch soxta) ────────────────────────────────────────

type Call = { url: string; method: string; body: string | null };

function mockFetch(responses: Array<{ status: number; body?: unknown }>): Call[] {
  const calls: Call[] = [];
  const queue = [...responses];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, method: String(init.method), body: typeof init.body === 'string' ? init.body : null });
      const next = queue.shift() ?? { status: 500 };
      return new Response(next.body === undefined ? null : JSON.stringify(next.body), { status: next.status });
    }),
  );
  return calls;
}

describe('accessHttp / linkRequestsHttp', () => {
  beforeEach(() => {
    setAccessToken('t1');
    setRefreshHandler(async () => false);
    setSessionLostHandler(null);
  });
  afterEach(() => vi.unstubAllGlobals());

  it('credentials: GET /school/students/:id/credentials → linked: true', async () => {
    const calls = mockFetch([{ status: 200, body: CREDENTIALS_WIRE }]);
    await expect(accessHttp.credentials('stu 1')).resolves.toEqual({ linked: true, credentials: CREDENTIALS_WIRE });
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/school/students/stu%201/credentials' });
  });

  it('credentials: `null` yoki bo\'sh javob — ulangan, lekin berilmagan', async () => {
    mockFetch([{ status: 200, body: null }]);
    await expect(accessHttp.credentials('s1')).resolves.toEqual({ linked: true, credentials: null });
    mockFetch([{ status: 200 }]);
    await expect(accessHttp.credentials('s1')).resolves.toEqual({ linked: true, credentials: null });
  });

  it('credentials: 409 NOT_LINKED xato emas — linked: false', async () => {
    mockFetch([{ status: 409, body: { statusCode: 409, code: 'NOT_LINKED', message: 'Student is not linked' } }]);
    await expect(accessHttp.credentials('s1')).resolves.toEqual({ linked: false, credentials: null });
  });

  it('credentials: boshqa 409 yoki 403 — xato sifatida o\'tadi', async () => {
    mockFetch([{ status: 409, body: { statusCode: 409, code: 'SOMETHING_ELSE', message: 'x' } }]);
    await expect(accessHttp.credentials('s1')).rejects.toMatchObject({ code: 'CONFLICT', detail: 'SOMETHING_ELSE' });
    mockFetch([{ status: 403, body: { statusCode: 403, code: 'FORBIDDEN', message: 'x' } }]);
    await expect(accessHttp.credentials('s1')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('issueCredentials: POST tanasi faqat berilganlar; 201 javobi adapterdan o\'tadi', async () => {
    const wire = { login: 'aziza.k24', temporaryPassword: 'k7m3pq9x', issuedAt: '2026-11-06T04:00:00.000Z' };
    const calls = mockFetch([{ status: 201, body: wire }, { status: 201, body: wire }]);
    await expect(accessHttp.issueCredentials('s1')).resolves.toEqual(wire);
    await accessHttp.issueCredentials('s1', { login: ' Aziza.K24 ', signOutDevices: false });
    expect(calls.map((c) => [c.method, c.url, c.body])).toEqual([
      ['POST', '/api/school/students/s1/credentials', '{}'],
      ['POST', '/api/school/students/s1/credentials', '{"login":"aziza.k24","signOutDevices":false}'],
    ]);
  });

  it('issueCredentials: 409 LOGIN_TAKEN va 409 NOT_LINKED — aniq detail bilan', async () => {
    mockFetch([{ status: 409, body: { statusCode: 409, code: 'LOGIN_TAKEN', message: 'taken' } }]);
    await expect(accessHttp.issueCredentials('s1', { login: 'aziza.k24' })).rejects.toSatisfy(isLoginTaken);
    mockFetch([{ status: 409, body: { statusCode: 409, code: 'NOT_LINKED', message: 'no' } }]);
    await expect(accessHttp.issueCredentials('s1')).rejects.toSatisfy(isNotLinked);
  });

  it('issueCredentials: javobda parol bo\'lmasa — xato (jim standart qiymat emas)', async () => {
    mockFetch([{ status: 201, body: { login: 'aziza.k24', issuedAt: '2026-11-06T04:00:00.000Z' } }]);
    await expect(accessHttp.issueCredentials('s1')).rejects.toThrowError(MALFORMED);
  });

  it('recoveryRequests: o\'quvchi kartasi (GET /school/students/:id) ichidagi `recoveryRequests`', async () => {
    const calls = mockFetch([{ status: 200, body: { id: 's1', lastName: 'K', recoveryRequests: [{ id: 'r1', status: 'RECEIVED', channel: 'SCHOOL', createdAt: '2026-11-06T04:00:00.000Z' }] } }]);
    await expect(accessHttp.recoveryRequests('s1')).resolves.toEqual([{ id: 'r1', channel: 'SCHOOL', createdAt: '2026-11-06T04:00:00.000Z' }]);
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/school/students/s1' });
    mockFetch([{ status: 200, body: { id: 's1' } }]);
    await expect(accessHttp.recoveryRequests('s1')).resolves.toEqual([]);
  });

  it('rejectRecovery: POST /school/students/:id/recovery-requests/:requestId/reject', async () => {
    const calls = mockFetch([{ status: 201, body: { ok: true } }]);
    await expect(accessHttp.rejectRecovery('s1', 'r 1')).resolves.toBeUndefined();
    expect(calls[0]).toMatchObject({ method: 'POST', url: '/api/school/students/s1/recovery-requests/r%201/reject', body: null });
  });

  it('inviteCode: faol kod; null/bo\'sh/404 — faol kod yo\'q; boshqa xato o\'tadi', async () => {
    const calls = mockFetch([{ status: 200, body: { code: '123456', expiresAt: '2026-11-07T04:00:00.000Z', studentUsedAt: null, parentUsedAt: null } }]);
    await expect(accessHttp.inviteCode('s1')).resolves.toMatchObject({ code: '123456' });
    expect(calls[0]).toMatchObject({ method: 'GET', url: '/api/school/students/s1/invite-code' });
    mockFetch([{ status: 200, body: null }]);
    await expect(accessHttp.inviteCode('s1')).resolves.toBeNull();
    mockFetch([{ status: 200 }]);
    await expect(accessHttp.inviteCode('s1')).resolves.toBeNull();
    mockFetch([{ status: 404, body: { statusCode: 404, code: 'NOT_FOUND', message: 'x' } }]);
    await expect(accessHttp.inviteCode('s1')).resolves.toBeNull();
    mockFetch([{ status: 403, body: { statusCode: 403, code: 'FORBIDDEN', message: 'x' } }]);
    await expect(accessHttp.inviteCode('s1')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('generateInviteCode: POST /school/students/:id/invite-code → { code, expiresAt }', async () => {
    const calls = mockFetch([{ status: 201, body: { code: '000123', expiresAt: '2026-11-07T04:00:00.000Z' } }]);
    await expect(accessHttp.generateInviteCode('s1')).resolves.toEqual({
      code: '000123',
      expiresAt: '2026-11-07T04:00:00.000Z',
      student: { used: false, usedAt: null },
      parent: { used: false, usedAt: null },
    });
    expect(calls[0]).toMatchObject({ method: 'POST', url: '/api/school/students/s1/invite-code', body: null });
  });

  it('linkRequestsHttp: ro\'yxat adapterdan o\'tadi; confirm/reject — POST /school/link-requests/:id/…', async () => {
    const calls = mockFetch([
      { status: 200, body: [{ id: 'l1', kind: 'REVIEW', studentName: 'Karimova Aziza', className: '7-A', createdAt: '2026-11-06T04:00:00.000Z', parentUsed: false }] },
      { status: 201, body: { ok: true } },
      { status: 204 },
    ]);
    await expect(linkRequestsHttp.list()).resolves.toHaveLength(1);
    await expect(linkRequestsHttp.confirm('l 1')).resolves.toBeUndefined();
    await expect(linkRequestsHttp.reject('l1')).resolves.toBeUndefined();
    expect(calls.map((c) => [c.method, c.url])).toEqual([
      ['GET', '/api/school/link-requests'],
      ['POST', '/api/school/link-requests/l%201/confirm'],
      ['POST', '/api/school/link-requests/l1/reject'],
    ]);
  });
});

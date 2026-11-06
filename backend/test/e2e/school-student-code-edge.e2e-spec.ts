// O'quvchi kodi (K2) — chekka holatlar: parallel urinishlar (limit va poyga), aloqa uzilgach eskirgan holat
// (ota-ona o'rni, tasdiqlangan o'rin, ochiq tuzatish), xodim qarorining eskirgan bolaga tegishli bo'lmasligi,
// aka-uka almashtirish, tuzatish ochiqligida yopiladigan yo'llar va bazadagi cheklovlar.

import { randomUUID } from 'node:crypto';
import { resetDb } from './db';
import { createChild } from './factories';
import { linkGuardian } from './school-attendance-fixtures';
import { appReq, schoolReq } from './school-child-fixtures';
import {
  buildCodeWorld,
  childLink,
  CodeWorld,
  confirm,
  confirmedLink,
  currentCode,
  Family,
  feed,
  issueCode,
  linkStatus,
  newFamily,
  parentLink,
  reject,
  requests,
  resetLinkLimits,
  trustParent,
} from './school-student-code-fixtures';
import { createTestApp, TestApp } from './test-app';
import { KioskTokenService } from '../../src/school/attendance/attendance-kiosk-token';

const wrongOf = (code: string) => (code === '000001' ? '000002' : '000001');

describe('School student code — edge cases (K2)', () => {
  let t: TestApp;
  let w: CodeWorld;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    resetLinkLimits(t);
    w = await buildCodeWorld(t);
  });

  afterAll(() => t.close());

  /** Alohida IP'dan (inject `remoteAddress`) bola kodi: IP bo'yicha ketma-ketlik bo'lmasin, poygani bazaning qulflari hal qilsin. */
  const childLinkFrom = (kid: Family['child'], code: string, ip: string) =>
    t.app.inject({
      method: 'POST',
      url: '/api/child/school/link',
      headers: { authorization: `Bearer ${kid.token}` },
      payload: { code },
      remoteAddress: ip,
    });

  const correction = (family: Family, over: Record<string, unknown> = {}) =>
    appReq(t, family.child.token, 'POST', '/child/school/correction', {
      reason: 'WRONG_SCHOOL_OR_CLASS',
      note: 'Xato',
      clientRequestId: randomUUID(),
      ...over,
    });

  const studentRow = (id: string) => t.prisma.schoolStudent.findUniqueOrThrow({ where: { id } });

  describe('parallel attempts', () => {
    it('25 parallel wrong codes from one child give exactly 5 CODE_INVALID, the rest LOCKED', async () => {
      const family = await newFamily(t);
      const code = await issueCode(t, w.director, w.aziz.id);

      const results = await Promise.all(Array.from({ length: 25 }, () => childLink(t, family.child, wrongOf(code))));

      const outcome = (status: number) => results.filter((r) => r.statusCode === status);
      expect(outcome(404)).toHaveLength(5);
      expect(outcome(429)).toHaveLength(20);
      expect(outcome(429).every((r) => r.json().code === 'LOCKED' && r.json().retryAfterSeconds > 0)).toBe(true);
      expect((await childLink(t, family.child, code)).statusCode).toBe(429);
    });

    it('70 parallel wrong codes from one IP (70 children) give exactly 60 CODE_INVALID, the rest LOCKED', async () => {
      const code = await issueCode(t, w.director, w.aziz.id);
      const families = await Promise.all(Array.from({ length: 70 }, () => newFamily(t)));

      const results = await Promise.all(families.map((f) => childLink(t, f.child, wrongOf(code))));

      expect(results.filter((r) => r.statusCode === 404)).toHaveLength(60);
      expect(results.filter((r) => r.statusCode === 429)).toHaveLength(10);
    });

    it('two children racing for one code from different IPs: exactly one wins the student slot', async () => {
      const a = await newFamily(t, 'Birinchi');
      const b = await newFamily(t, 'Ikkinchi');
      const code = await issueCode(t, w.director, w.aziz.id);

      const results = await Promise.all([childLinkFrom(a.child, code, '10.0.0.1'), childLinkFrom(b.child, code, '10.0.0.2')]);

      expect(results.map((r) => r.statusCode).sort()).toEqual([200, 404]);
      expect(await t.prisma.schoolStudentInvite.count({ where: { studentId: w.aziz.id, studentChildId: { not: null } } })).toBe(1);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(1);
    });

    it('one child entering two different codes in parallel ends up pending at exactly one student', async () => {
      const family = await newFamily(t);
      const a = await issueCode(t, w.director, w.aziz.id);
      const b = await issueCode(t, w.director, w.bobur.id);

      const results = await Promise.all([childLinkFrom(family.child, a, '10.0.1.1'), childLinkFrom(family.child, b, '10.0.1.2')]);

      expect(results.map((r) => r.statusCode)).toEqual([200, 200]);
      expect(await t.prisma.schoolStudentInvite.count({ where: { studentChildId: family.child.childId, studentConfirmedAt: null } })).toBe(1);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(1);
    });

    it('caps the child at 30 requests per 10 minutes (per child, not per IP)', async () => {
      const family = await newFamily(t);
      const other = await newFamily(t);

      for (let i = 0; i < 30; i += 1) expect((await appReq(t, family.child.token, 'POST', '/child/school/link', {})).statusCode).toBe(400);
      const capped = await appReq(t, family.child.token, 'POST', '/child/school/link', {});

      expect(capped.statusCode).toBe(429);
      expect(capped.json().code).not.toBe('LOCKED');
      // Boshqa bola (xuddi shu IP) ta'sirlanmaydi
      expect((await appReq(t, other.child.token, 'POST', '/child/school/link', {})).statusCode).toBe(400);
    });
  });

  describe('revoked parent and unlink clean-up', () => {
    it('a staff-unlinked parent no longer vouches: their child stays UNDER_REVIEW and shows up for staff', async () => {
      const stranger = await newFamily(t, 'Begona');
      await trustParent(t, w.aziz, stranger);
      const code = await issueCode(t, w.director, w.aziz.id);
      expect((await parentLink(t, stranger.parent, code)).statusCode).toBe(200);
      const guardian = await t.prisma.schoolGuardian.findFirstOrThrow({ where: { userId: stranger.parent.userId } });
      expect((await schoolReq(t, w.director, 'POST', `/guardians/${guardian.id}/unlink`)).statusCode).toBe(200);

      const res = await childLink(t, stranger.child, code);

      expect(res.json()).toMatchObject({ student: { status: 'UNDER_REVIEW' }, parent: { status: 'EXPIRED' } });
      expect((await studentRow(w.aziz.id)).childId).toBeNull();
      const list = (await requests(t, w.director)).json();
      expect(list).toHaveLength(1);
      expect(list[0]).toMatchObject({ kind: 'REVIEW', parentLinked: false, child: { name: 'Begona' } });
    });

    it('a parent who disconnected can enter the same still-open code again (re-linked through the school record, not a silent no-op)', async () => {
      const family = await newFamily(t);
      await trustParent(t, w.aziz, family);
      const code = await issueCode(t, w.director, w.aziz.id);
      await parentLink(t, family.parent, code);
      const guardian = await t.prisma.schoolGuardian.findFirstOrThrow({ where: { userId: family.parent.userId } });
      expect((await appReq(t, family.parent.token, 'DELETE', `/parent/school/links/${guardian.id}`)).statusCode).toBe(204);
      expect((await appReq(t, family.parent.token, 'GET', '/parent/school/links')).json().links).toEqual([]);

      const again = await parentLink(t, family.parent, code);

      expect(again.statusCode).toBe(200);
      expect(again.json().links).toHaveLength(1);
      expect(again.json().links[0].status).toBe('LINKED');
      expect(await t.prisma.schoolGuardian.count({ where: { userId: family.parent.userId, linkStatus: 'LINKED' } })).toBe(1);
      expect(await t.prisma.schoolGuardian.count({ where: { schoolId: w.schoolId } })).toBe(1);
    });

    it.each([
      ['parent disconnects', (g: { id: string }, f: Family) => appReq(t, f.parent.token, 'DELETE', `/parent/school/links/${g.id}`)],
      ['staff unlinks the guardian', (g: { id: string }) => schoolReq(t, w.director, 'POST', `/guardians/${g.id}/unlink`)],
    ])('%s: the child\'s code slots are freed and its open correction is cancelled with its notification', async (_name, unlink) => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      const id = (await correction(family)).json().id as string;
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_CORRECTION' } })).toBe(1);
      const guardian = await t.prisma.schoolGuardian.findFirstOrThrow({ where: { userId: family.parent.userId } });

      expect([200, 204]).toContain((await unlink(guardian, family)).statusCode);

      expect((await studentRow(w.aziz.id)).childId).toBeNull();
      expect((await linkStatus(t, family.child)).json().student.status).toBe('NONE');
      expect(await t.prisma.schoolLinkCorrection.findUniqueOrThrow({ where: { id } })).toMatchObject({ status: 'CANCELLED' });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_CORRECTION' } })).toBe(0);
      expect(await t.prisma.schoolStudentInvite.count({ where: { studentChildId: family.child.childId } })).toBe(0);
      expect((await requests(t, w.director)).json()).toEqual([]);

      // Uzilgan bola yangi kodni kirita oladi (eskirgan "tasdiqlangan" o'rin yo'q)
      const fresh = await issueCode(t, w.director, w.aziz.id);
      expect((await childLink(t, family.child, fresh)).json().student.status).toBe('UNDER_REVIEW');
    });

    it('parent PUT replacing a sibling cleans the sibling\'s open correction and notification', async () => {
      const family = await newFamily(t, 'Uka');
      await confirmedLink(t, w.director, w.aziz, family);
      const correctionId = (await correction(family)).json().id as string;
      const sibling = await createChild(t.prisma, family.parent, { name: 'Aka' });

      const put = await appReq(t, family.parent.token, 'PUT', `/parent/school/students/${w.aziz.id}/child`, { childId: sibling.childId });

      expect(put.statusCode).toBe(200);
      expect((await studentRow(w.aziz.id)).childId).toBe(sibling.childId);
      expect(await t.prisma.schoolLinkCorrection.findUniqueOrThrow({ where: { id: correctionId } })).toMatchObject({ status: 'CANCELLED' });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_CORRECTION' } })).toBe(0);
      expect((await linkStatus(t, family.child)).json().student.status).toBe('NONE');
      expect(await t.prisma.schoolStudentInvite.count({ where: { studentChildId: family.child.childId } })).toBe(0);
    });
  });

  describe('lifecycle', () => {
    it('a child linked by the parent PUT can enter the student\'s new code (slot marked CONFIRMED, no review)', async () => {
      const family = await newFamily(t, 'Aziz');
      await linkGuardian(t, w.schoolId, w.aziz.id, family.parent);
      await appReq(t, family.parent.token, 'PUT', `/parent/school/students/${w.aziz.id}/child`, { childId: family.child.childId });
      const code = await issueCode(t, w.director, w.aziz.id);

      const res = await childLink(t, family.child, code);

      expect(res.statusCode).toBe(200);
      expect(res.json().student.status).toBe('CONFIRMED');
      expect((await currentCode(t, w.director, w.aziz.id)).json()).toMatchObject({ student: { status: 'CONFIRMED' }, parent: { status: 'FREE' } });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
    });

    it('regenerating the code while a child waits: the trusted parent entering the NEW code still confirms that child', async () => {
      const family = await newFamily(t, 'Aziz');
      await trustParent(t, w.aziz, family);
      const first = await issueCode(t, w.director, w.aziz.id);
      expect((await childLink(t, family.child, first)).json().student.status).toBe('UNDER_REVIEW');
      const second = await issueCode(t, w.director, w.aziz.id);

      expect((await parentLink(t, family.parent, second)).statusCode).toBe(200);

      expect((await studentRow(w.aziz.id)).childId).toBe(family.child.childId);
      expect((await linkStatus(t, family.child)).json()).toMatchObject({ student: { status: 'CONFIRMED' }, parent: { status: 'CONFIRMED' } });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
    });

    it('a stale staff decision never applies to a different child that took the freed slot (ABA)', async () => {
      const first = await newFamily(t, 'Birinchi');
      const second = await newFamily(t, 'Ikkinchi');
      const code = await issueCode(t, w.director, w.aziz.id);
      await childLink(t, first.child, code);
      const [item] = (await requests(t, w.director)).json();
      expect(item.child.name).toBe('Birinchi');
      expect((await reject(t, w.admin, item.id)).statusCode).toBe(200);
      expect((await childLink(t, second.child, code)).json().student.status).toBe('UNDER_REVIEW');

      const stale = await confirm(t, w.director, item.id);
      const staleReject = await reject(t, w.director, item.id);

      expect([stale.statusCode, stale.json().code]).toEqual([409, 'REQUEST_STALE']);
      expect([staleReject.statusCode, staleReject.json().code]).toEqual([409, 'REQUEST_STALE']);
      expect((await studentRow(w.aziz.id)).childId).toBeNull();
      const current = (await requests(t, w.director)).json();
      expect(current.map((r: { child: { name: string } }) => r.child.name)).toEqual(['Ikkinchi']);
    });

    it('a correction replay after staff resolved it returns the same id with the final status (201)', async () => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      const clientRequestId = randomUUID();
      const created = (await correction(family, { clientRequestId })).json();
      await confirm(t, w.director, created.id);

      const replay = await correction(family, { clientRequestId });

      expect(replay.statusCode).toBe(201);
      expect(replay.json()).toEqual({ id: created.id, status: 'CONFIRMED' });
      expect(await t.prisma.schoolLinkCorrection.count()).toBe(1);
    });

    it('archived student / suspended school: the code is dead for both child and parent', async () => {
      const family = await newFamily(t);
      const code = await issueCode(t, w.director, w.aziz.id);
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { archived: true } });
      expect((await childLink(t, family.child, code)).json().code).toBe('CODE_INVALID');
      expect((await parentLink(t, family.parent, code)).json().code).toBe('INVITE_INVALID');
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { archived: false } });
      await t.prisma.school.update({ where: { id: w.schoolId }, data: { status: 'SUSPENDED' } });
      resetLinkLimits(t);

      expect((await childLink(t, family.child, code)).json().code).toBe('CODE_INVALID');
    });

    it('a Telegram placeholder phone (tg:…) never matches a school record and is never copied into the guardian created on confirmation', async () => {
      const family = await newFamily(t);
      await t.prisma.user.update({ where: { id: family.parent.userId }, data: { phone: 'tg:123456789' } });
      const stranger = await t.prisma.schoolGuardian.create({
        data: { schoolId: w.schoolId, fullName: 'Boshqa Ota', phone: '+998 12 345 67 89', relation: 'FATHER', students: { create: { studentId: w.aziz.id } } },
      });
      const code = await issueCode(t, w.director, w.aziz.id);

      const redeemed = await parentLink(t, family.parent, code);

      // tg: "telefon" hech kimga mos kelmaydi: vasiy ulanmaydi, so'rov xodim ko'rigida
      expect(redeemed.statusCode).toBe(200);
      expect(redeemed.json().links).toEqual([expect.objectContaining({ status: 'PENDING_REVIEW' })]);
      expect(await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: stranger.id } })).toMatchObject({ userId: null, linkStatus: 'NOT_INVITED' });
      const [item] = (await requests(t, w.director)).json();
      expect(item).toMatchObject({ kind: 'GUARDIAN', parent: { maskedPhone: null } });

      // Tasdiqlanganda yangi yozuv ochiladi, telefon ko'chirilmaydi
      expect((await confirm(t, w.director, item.id)).statusCode).toBe(200);
      const mine = await t.prisma.schoolGuardian.findFirstOrThrow({ where: { userId: family.parent.userId } });
      expect(mine.id).not.toBe(stranger.id);
      expect(mine.phone).toBe('');
      expect(await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: stranger.id } })).toMatchObject({ userId: null });
    });
  });

  describe('school data is closed while a correction is open', () => {
    it('check-in, attendance history, survey, care requests and school announcements/timetable all refuse', async () => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      const school = await t.prisma.school.findUniqueOrThrow({ where: { id: w.schoolId } });
      const kiosk = t.app.get(KioskTokenService).issue(w.schoolId, school.kioskSecret, new Date()).token;
      await correction(family);
      const token = family.child.token;

      const checkIn = await appReq(t, token, 'POST', '/child/school/check-in', { token: kiosk });
      expect([checkIn.statusCode, checkIn.json().code]).toEqual([403, 'NOT_ENROLLED']);
      const calls: Array<[string, string, object | undefined]> = [
        ['GET', '/child/school/attendance?month=2026-10', undefined],
        ['GET', '/child/school/timetable', undefined],
        ['GET', '/child/school/announcements', undefined],
        ['POST', `/child/school/care/survey/${randomUUID()}/responses`, { answers: {} }],
        ['POST', '/child/school/care/requests', { topic: 'OTHER', message: 'Salom' }],
      ];
      for (const [method, url, body] of calls) {
        const res = await appReq(t, token, method as 'GET' | 'POST', url, body);
        expect([res.statusCode, res.json().code]).toEqual([404, 'UNDER_REVIEW']);
      }
    });
  });

  describe('database guarantees', () => {
    const invite = (studentId: string, code: string, over: Record<string, unknown> = {}) =>
      t.prisma.schoolStudentInvite.create({
        data: { schoolId: w.schoolId, studentId, code, expiresAt: new Date(Date.now() + 3_600_000), createdByStaffId: 'staff', ...over },
      });

    it('allows one open invite per code and per student, but reuses codes of closed invites', async () => {
      await invite(w.aziz.id, '111111');
      await expect(invite(w.bobur.id, '111111')).rejects.toMatchObject({ code: 'P2002' });
      await expect(invite(w.aziz.id, '222222')).rejects.toMatchObject({ code: 'P2002' });

      await t.prisma.schoolStudentInvite.updateMany({ where: { studentId: w.aziz.id }, data: { closedAt: new Date() } });

      await expect(invite(w.bobur.id, '111111')).resolves.toMatchObject({ code: '111111' });
      await expect(invite(w.aziz.id, '222222')).resolves.toMatchObject({ code: '222222' });
    });

    it('rejects codes that are not six digits and a child waiting at two students', async () => {
      await expect(invite(w.aziz.id, 'ABC123')).rejects.toBeDefined();
      await expect(invite(w.aziz.id, '12345')).rejects.toBeDefined();
      const family = await newFamily(t);
      await invite(w.aziz.id, '333333', { studentChildId: family.child.childId, studentUsedAt: new Date() });
      await expect(invite(w.bobur.id, '444444', { studentChildId: family.child.childId, studentUsedAt: new Date() })).rejects.toMatchObject({ code: 'P2002' });
      // tasdiqlangan o'rinlar cheklanmaydi
      await expect(
        invite(w.sardor.id, '555555', { studentChildId: family.child.childId, studentUsedAt: new Date(), studentConfirmedAt: new Date() }),
      ).resolves.toBeDefined();
    });

    it('allows one open correction per child and only known statuses', async () => {
      const family = await newFamily(t);
      const data = { schoolId: w.schoolId, studentId: w.aziz.id, childId: family.child.childId, reason: 'WRONG_SCHOOL_OR_CLASS' };
      await t.prisma.schoolLinkCorrection.create({ data: { ...data, clientRequestId: randomUUID() } });
      await expect(t.prisma.schoolLinkCorrection.create({ data: { ...data, clientRequestId: randomUUID() } })).rejects.toMatchObject({ code: 'P2002' });
      await expect(t.prisma.schoolLinkCorrection.create({ data: { ...data, clientRequestId: randomUUID(), status: 'WHATEVER' } })).rejects.toBeDefined();
      await expect(t.prisma.schoolLinkCorrection.create({ data: { ...data, clientRequestId: randomUUID(), status: 'CONFIRMED' } })).resolves.toBeDefined();
    });
  });

  describe('notification feed', () => {
    it('shows at most 10 link notifications per kind so mass onboarding cannot crowd out urgent items', async () => {
      const base = Date.now() - 3_600_000;
      await t.prisma.schoolStaffNotification.createMany({
        data: Array.from({ length: 12 }, (_, i) => ({
          id: `link-review:bulk-${i}`,
          schoolId: w.schoolId,
          kind: 'LINK_REVIEW',
          at: new Date(base + i * 1000),
          roles: ['ADMIN'],
          classIds: [],
          params: { studentName: `Talaba ${i}`, className: '7-A' },
        })),
      });

      const items = (await feed(t, w.admin)).json() as Array<{ id: string; kind: string }>;

      const links = items.filter((n) => n.kind === 'LINK_REVIEW');
      expect(links).toHaveLength(10);
      expect(links.map((n) => n.id)).toEqual(Array.from({ length: 10 }, (_, i) => `link-review:bulk-${11 - i}`));
    });
  });
});

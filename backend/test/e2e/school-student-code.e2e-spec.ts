// O'quvchi kodi (K2): xodim kod yaratadi (6 raqam, 24 soat, faol kodlar orasida yagona), bola kiritadi (UNDER_REVIEW,
// maktab ma'lumoti yopiq), ota-ona kiritadi (ota-ona o'rni -> bola CONFIRMED), brute-force limitlari va eski
// 8 belgili vasiy kodi regressiyasi.

import { randomUUID } from 'node:crypto';
import { resetDb } from './db';
import { createParent } from './factories';
import { linkGuardian, staffSession } from './school-attendance-fixtures';
import { appReq, schoolReq } from './school-child-fixtures';
import { createSchool } from './school-fixtures';
import { createGuardian } from './school-students-fixtures';
import {
  buildCodeWorld,
  childLink,
  CodeWorld,
  currentCode,
  generateCode,
  issueCode,
  linkStatus,
  newFamily,
  parentLink,
  resetLinkLimits,
  SCHOOL_NAME,
  timetable,
  trustParent,
} from './school-student-code-fixtures';
import { createTestApp, TestApp } from './test-app';

const wrongOf = (code: string) => (code === '000001' ? '000002' : '000001');

/** `randomInt` ni vaqtincha qotiradi (kod to'qnashuvini sinash uchun); keyingi chaqiruvlar haqiqiy. */
async function withRandomCodes<T>(values: number[], fn: () => Promise<T>): Promise<T> {
  const crypto = jest.requireActual('node:crypto') as { randomInt: (...a: unknown[]) => number };
  const spy = jest.spyOn(crypto, 'randomInt');
  for (const v of values) spy.mockReturnValueOnce(v);
  try {
    return await fn();
  } finally {
    spy.mockRestore();
  }
}

describe('School student code (K2)', () => {
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

  describe('staff: invite code', () => {
    it('creates a 6-digit code valid for 24h; GET shows both slots; regenerating closes the previous code', async () => {
      const first = await generateCode(t, w.director, w.aziz.id);
      expect(first.statusCode).toBe(201);
      const { code, expiresAt } = first.json();
      expect(code).toMatch(/^\d{6}$/);
      const hours = (Date.parse(expiresAt) - Date.now()) / 3_600_000;
      expect(hours).toBeGreaterThan(23.9);
      expect(hours).toBeLessThanOrEqual(24);

      const current = await currentCode(t, w.director, w.aziz.id);
      expect(current.json()).toMatchObject({
        code,
        expiresAt,
        student: { status: 'FREE', usedAt: null },
        parent: { status: 'FREE', usedAt: null },
      });

      await generateCode(t, w.director, w.aziz.id);
      const rows = await t.prisma.schoolStudentInvite.findMany({ where: { studentId: w.aziz.id }, orderBy: { createdAt: 'asc' } });
      expect(rows).toHaveLength(2);
      expect(rows[0]!.closedAt).not.toBeNull();
      expect(rows[1]!.closedAt).toBeNull();
      expect((await currentCode(t, w.director, w.aziz.id)).json().code).toBe(rows[1]!.code);
    });

    it('keeps leading zeros and never repeats an active code (collision is retried; an expired unclosed row is closed)', async () => {
      const a = await withRandomCodes([5], async () => (await generateCode(t, w.director, w.aziz.id)).json().code);
      expect(a).toBe('000005');

      // 000005 faol (bobur'ga) — kutilmagan to'qnashuv qayta uriniladi.
      const b = await withRandomCodes([5, 5, 777], async () => (await generateCode(t, w.director, w.bobur.id)).json().code);
      expect(b).toBe('000777');

      // Muddati o'tgan, lekin yopilmagan qator kodni band qilmaydi: yopiladi va kod qayta beriladi.
      await t.prisma.schoolStudentInvite.updateMany({ where: { studentId: w.aziz.id }, data: { expiresAt: new Date(Date.now() - 1000) } });
      const c = await withRandomCodes([5], async () => (await generateCode(t, w.director, w.sardor.id)).json().code);
      expect(c).toBe('000005');
      const stale = await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } });
      expect(stale.closedAt).not.toBeNull();
    });

    it('gives parallel generations distinct codes', async () => {
      const students = [w.aziz, w.bobur, w.sardor];
      const codes = await Promise.all(students.map(async (s) => (await generateCode(t, w.director, s.id)).json().code as string));
      expect(new Set(codes).size).toBe(3);
      expect(await t.prisma.schoolStudentInvite.count({ where: { closedAt: null } })).toBe(3);
    });

    it('is limited to guardians.link and the actor class scope; other school / archived / unknown students are rejected', async () => {
      expect((await generateCode(t, w.homeroomA, w.aziz.id)).statusCode).toBe(201);
      expect((await currentCode(t, w.homeroomA, w.aziz.id)).statusCode).toBe(200);
      expect((await generateCode(t, w.admin, w.sardor.id)).statusCode).toBe(201);
      // Boshqa sinf rahbari / ruxsatsiz rollar
      expect((await generateCode(t, w.homeroomB, w.aziz.id)).statusCode).toBe(403);
      expect((await currentCode(t, w.homeroomB, w.aziz.id)).statusCode).toBe(403);
      for (const who of [w.teacher, w.duty, w.psych]) {
        expect((await generateCode(t, who, w.aziz.id)).statusCode).toBe(403);
        expect((await currentCode(t, who, w.aziz.id)).statusCode).toBe(403);
      }
      expect((await generateCode(t, w.director, randomUUID())).statusCode).toBe(404);
      await t.prisma.schoolStudent.update({ where: { id: w.bobur.id }, data: { archived: true } });
      const archived = await generateCode(t, w.director, w.bobur.id);
      expect([archived.statusCode, archived.json().code]).toEqual([409, 'STUDENT_ARCHIVED']);
      expect(await t.prisma.schoolStudentInvite.count({ where: { studentId: w.bobur.id } })).toBe(0);

      const other = await buildOtherSchool();
      expect((await generateCode(t, other.admin, w.aziz.id)).statusCode).toBe(404);
      expect((await currentCode(t, other.admin, w.aziz.id)).statusCode).toBe(404);
    });

    it('GET returns JSON null without an active code (never created, expired, closed)', async () => {
      const none = await currentCode(t, w.director, w.aziz.id);
      expect([none.statusCode, none.body]).toEqual([200, 'null']);
      await generateCode(t, w.director, w.aziz.id);
      await t.prisma.schoolStudentInvite.updateMany({ where: { studentId: w.aziz.id }, data: { expiresAt: new Date(Date.now() - 1000) } });
      expect((await currentCode(t, w.director, w.aziz.id)).body).toBe('null');
      await t.prisma.schoolStudentInvite.updateMany({ where: { studentId: w.aziz.id }, data: { expiresAt: new Date(Date.now() + 60_000), closedAt: new Date() } });
      expect((await currentCode(t, w.director, w.aziz.id)).body).toBe('null');
    });

    it('audits code creation without writing the code itself', async () => {
      const code = await issueCode(t, w.homeroomA, w.aziz.id);
      const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'student.inviteCode' } });
      expect(audit).toMatchObject({ module: 'GUARDIANS', entityId: w.aziz.id, params: { name: 'Karimov Aziz' } });
      expect(JSON.stringify([audit.summary, audit.params, audit.before, audit.after])).not.toContain(code);
    });
  });

  describe('child: POST /child/school/link', () => {
    it('UNDER_REVIEW: school data stays hidden, no names leak, staff gets a LINK_REVIEW notification', async () => {
      const family = await newFamily(t, 'Aziz');
      const code = await issueCode(t, w.homeroomA, w.aziz.id);
      expect((await linkStatus(t, family.child)).json()).toEqual({
        student: { status: 'NONE', schoolName: null, className: null },
        parent: { status: 'NONE' },
        expiresAt: null,
      });

      const res = await childLink(t, family.child, code);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({
        student: { status: 'UNDER_REVIEW', schoolName: null, className: null },
        parent: { status: 'PENDING' },
        expiresAt: expect.any(String),
      });
      for (const secret of [SCHOOL_NAME, 'Karimov', 'Aziz', '7-A']) expect(res.body).not.toContain(secret);
      expect((await linkStatus(t, family.child)).json().student.status).toBe('UNDER_REVIEW');

      const invite = await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } });
      expect(invite).toMatchObject({ studentChildId: family.child.childId, studentConfirmedAt: null, parentUserId: null, closedAt: null });
      expect(invite.studentUsedAt).not.toBeNull();
      expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBeNull();
      expect((await timetable(t, family.child)).json().code).toBe('NOT_ENROLLED');

      const notes = await t.prisma.schoolStaffNotification.findMany({ where: { kind: 'LINK_REVIEW' } });
      expect(notes).toHaveLength(1);
      // Oluvchilar: guardians.link ruxsati bor, faol, shu maktab va o'quvchi sinfi doirasidagi xodimlar.
      expect(notes[0]).toMatchObject({
        schoolId: w.schoolId,
        roles: ['ADMIN', 'DIRECTOR', 'HOMEROOM'],
        classIds: [w.classA],
        params: { studentName: 'Karimov Aziz', className: '7-A' },
      });
      expect([...notes[0]!.staffIds].sort()).toEqual([w.director.staffId, w.admin.staffId, w.homeroomA.staffId].sort());
      expect(Object.keys(notes[0]!.params as object).sort()).toEqual(['className', 'studentName']);
      expect(JSON.stringify([notes[0]!.params, notes[0]!.subject, notes[0]!.href])).not.toContain(code);

      // GET /school/students/:id/invite-code: o'quvchi o'rni UNDER_REVIEW, ota-ona o'rni bo'sh
      expect((await currentCode(t, w.homeroomA, w.aziz.id)).json()).toMatchObject({
        student: { status: 'UNDER_REVIEW' },
        parent: { status: 'FREE' },
      });
    });

    it('is idempotent: the same child entering the same code again changes nothing (also after the code closed)', async () => {
      const family = await newFamily(t, 'Aziz');
      const code = await issueCode(t, w.director, w.aziz.id);
      const first = (await childLink(t, family.child, code)).json();

      const again = await childLink(t, family.child, code);

      expect(again.statusCode).toBe(200);
      expect(again.json()).toEqual(first);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(1);

      // Ikkala o'rin ham band bo'lib kod yopilgach ham takroriy so'rov xato bermaydi.
      const other = await newFamily(t, 'Boshqa');
      expect((await parentLink(t, other.parent, code)).statusCode).toBe(200);
      expect((await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } })).closedAt).not.toBeNull();
      const closed = await childLink(t, family.child, code);
      expect(closed.statusCode).toBe(200);
      expect(closed.json().student).toEqual(first.student);
    });

    it.each([
      ['wrong code', async () => undefined],
      ['expired code', async (id: string) => void (await t.prisma.schoolStudentInvite.updateMany({ where: { studentId: id }, data: { expiresAt: new Date(Date.now() - 1000) } }))],
      ['closed code', async (id: string) => void (await t.prisma.schoolStudentInvite.updateMany({ where: { studentId: id }, data: { closedAt: new Date() } }))],
    ])('%s -> 404 CODE_INVALID without any school or student name', async (name, mutate) => {
      const family = await newFamily(t);
      const code = await issueCode(t, w.director, w.aziz.id);
      await mutate(w.aziz.id);

      const res = await childLink(t, family.child, name === 'wrong code' ? wrongOf(code) : code);

      expect(res.statusCode).toBe(404);
      expect(res.json()).toEqual({ statusCode: 404, code: 'CODE_INVALID', message: expect.any(String) });
      for (const secret of [SCHOOL_NAME, 'Karimov', '7-A']) expect(res.body).not.toContain(secret);
    });

    it('rejects a code whose student slot is used by another child, or whose student is already confirmed for another child (same answer)', async () => {
      const first = await newFamily(t, 'Birinchi');
      const second = await newFamily(t, 'Ikkinchi');
      const code = await issueCode(t, w.director, w.aziz.id);
      expect((await childLink(t, first.child, code)).statusCode).toBe(200);
      const slotUsed = await childLink(t, second.child, code);
      expect([slotUsed.statusCode, slotUsed.json().code]).toEqual([404, 'CODE_INVALID']);

      const third = await newFamily(t, 'Uchinchi');
      const bobur = await issueCode(t, w.director, w.bobur.id);
      await t.prisma.schoolStudent.update({ where: { id: w.bobur.id }, data: { childId: third.child.childId } });
      const confirmedElsewhere = await childLink(t, second.child, bobur);
      expect([confirmedElsewhere.statusCode, confirmedElsewhere.json().code]).toEqual([404, 'CODE_INVALID']);
    });

    it('validates the body (400) and the roles (parent token 403, anonymous 401)', async () => {
      const family = await newFamily(t);
      for (const body of [{}, { code: '12345' }, { code: '1234567' }, { code: 'ABCDEFGH' }, { code: 123456 }]) {
        const res = await appReq(t, family.child.token, 'POST', '/child/school/link', body);
        expect([res.statusCode, res.json().code]).toEqual([400, 'VALIDATION']);
      }
      // Bo'shliq va chiziqcha farqsiz
      const code = await issueCode(t, w.director, w.aziz.id);
      const spaced = await appReq(t, family.child.token, 'POST', '/child/school/link', { code: `${code.slice(0, 3)} ${code.slice(3)}` });
      expect(spaced.statusCode).toBe(200);
      expect((await appReq(t, family.parent.token, 'POST', '/child/school/link', { code })).statusCode).toBe(403);
      expect((await t.app.inject({ method: 'POST', url: '/api/child/school/link', payload: { code } })).statusCode).toBe(401);
      expect((await appReq(t, family.parent.token, 'GET', '/child/school/link-status')).statusCode).toBe(403);
    });

    it('locks the child after 5 wrong codes (even the right one) with retryAfterSeconds; a success does not use up attempts', async () => {
      const family = await newFamily(t);
      const code = await issueCode(t, w.director, w.aziz.id);
      for (let i = 0; i < 5; i += 1) {
        const res = await childLink(t, family.child, wrongOf(code));
        expect([res.statusCode, res.json().code]).toEqual([404, 'CODE_INVALID']);
      }

      const locked = await childLink(t, family.child, code);

      expect(locked.statusCode).toBe(429);
      expect(locked.json()).toMatchObject({ statusCode: 429, code: 'LOCKED', retryAfterSeconds: expect.any(Number) });
      expect(locked.json().retryAfterSeconds).toBeGreaterThan(890);
      expect(locked.json().retryAfterSeconds).toBeLessThanOrEqual(900);
      expect((await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } })).studentChildId).toBeNull();
      // Boshqa bola (boshqa profil) bloklanmagan
      const other = await newFamily(t);
      expect((await childLink(t, other.child, code)).statusCode).toBe(200);

      // Muvaffaqiyatli kiritish limitni yemaydi (faqat xatolar sanaladi): 4 xato + muvaffaqiyat + 1 xato = 5 xato,
      // keyingisi bloklanadi — muvaffaqiyat hisobga qo'shilmagan.
      const careful = await newFamily(t);
      const bobur = await issueCode(t, w.director, w.bobur.id);
      for (let i = 0; i < 4; i += 1) await childLink(t, careful.child, wrongOf(bobur));
      expect((await childLink(t, careful.child, bobur)).statusCode).toBe(200);
      expect((await childLink(t, careful.child, wrongOf(bobur))).statusCode).toBe(404);
      expect((await childLink(t, careful.child, wrongOf(bobur))).statusCode).toBe(429);
    });

    it('locks one IP after 60 wrong codes across different children (school NAT), not before', async () => {
      const code = await issueCode(t, w.director, w.aziz.id);
      for (let c = 0; c < 15; c += 1) {
        const kid = await newFamily(t);
        for (let i = 0; i < 4; i += 1) expect((await childLink(t, kid.child, wrongOf(code))).statusCode).toBe(404);
      }
      const innocent = await newFamily(t);

      const res = await childLink(t, innocent.child, code);

      expect(res.statusCode).toBe(429);
      expect(res.json()).toMatchObject({ code: 'LOCKED', retryAfterSeconds: expect.any(Number) });
      expect(res.json().retryAfterSeconds).toBeGreaterThan(0);
    });

    it('replaces an earlier pending request when the child enters another student code', async () => {
      const family = await newFamily(t);
      const a = await issueCode(t, w.director, w.aziz.id);
      const b = await issueCode(t, w.director, w.bobur.id);
      await childLink(t, family.child, a);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(1);

      const res = await childLink(t, family.child, b);

      expect(res.statusCode).toBe(200);
      const [first, second] = await Promise.all([
        t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } }),
        t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.bobur.id } }),
      ]);
      expect(first.studentChildId).toBeNull();
      expect(second.studentChildId).toBe(family.child.childId);
      const notes = await t.prisma.schoolStaffNotification.findMany({ where: { kind: 'LINK_REVIEW' } });
      expect(notes.map((n) => n.id)).toEqual([`link-review:${second.id}`]);
      // Eski kod endi band emas — boshqa bola uni kirita oladi.
      expect((await childLink(t, (await newFamily(t)).child, a)).statusCode).toBe(200);
    });

    it('answers 409 ALREADY_ENROLLED to a confirmed child for any code except its own student code', async () => {
      const family = await newFamily(t);
      await trustParent(t, w.aziz, family);
      const own = await issueCode(t, w.director, w.aziz.id);
      const parent = await parentLink(t, family.parent, own);
      expect(parent.statusCode).toBe(200);
      expect((await childLink(t, family.child, own)).json().student.status).toBe('CONFIRMED');

      const other = await issueCode(t, w.director, w.bobur.id);
      for (const code of [other, wrongOf(other)]) {
        const res = await childLink(t, family.child, code);
        expect([res.statusCode, res.json().code]).toEqual([409, 'ALREADY_ENROLLED']);
      }
      // O'z kodini qayta kiritish — o'zgarishsiz 200; xato urinishlar sanalmaydi.
      expect((await childLink(t, family.child, own)).json().student.status).toBe('CONFIRMED');
      expect((await childLink(t, family.child, own)).statusCode).toBe(200);
    });
  });

  describe('confirmation by the child\'s own parent', () => {
    it('trusted parent first (school-entered guardian with the same phone), then the child: CONFIRMED at once, code closed, no review notification', async () => {
      const family = await newFamily(t, 'Aziz', 'Karimova');
      const known = await trustParent(t, w.aziz, family);
      const code = await issueCode(t, w.homeroomA, w.aziz.id);

      const parent = await parentLink(t, family.parent, code);

      expect(parent.statusCode).toBe(200);
      expect(parent.json().links[0]).toMatchObject({
        status: 'LINKED',
        guardianId: known.id,
        school: { name: SCHOOL_NAME },
        students: [{ id: w.aziz.id, fullName: 'Karimov Aziz', className: '7-A', childId: null, linkedBy: 'NONE' }],
      });
      // Maktabning o'z yozuvi ulandi (yangi yozuv yaratilmadi), kod ishonch bermagan: telefon mos edi.
      const guardian = await t.prisma.schoolGuardian.findFirstOrThrow({ where: { userId: family.parent.userId }, include: { students: true } });
      expect(guardian).toMatchObject({ id: known.id, linkStatus: 'LINKED', relation: 'MOTHER', schoolId: w.schoolId, inviteCode: null });
      expect(guardian.linkedAt).not.toBeNull();
      expect(guardian.students.map((s) => s.studentId)).toEqual([w.aziz.id]);
      expect(await t.prisma.schoolGuardian.count({ where: { schoolId: w.schoolId } })).toBe(1);
      expect(await t.prisma.schoolGuardianReview.count()).toBe(0);
      expect((await currentCode(t, w.homeroomA, w.aziz.id)).json()).toMatchObject({ parent: { status: 'USED' }, student: { status: 'FREE' } });

      const child = await childLink(t, family.child, code);

      expect(child.json()).toEqual({
        student: { status: 'CONFIRMED', schoolName: SCHOOL_NAME, className: '7-A' },
        parent: { status: 'CONFIRMED' },
        expiresAt: null,
      });
      expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBe(family.child.childId);
      expect(await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } })).toMatchObject({
        studentChildId: family.child.childId,
        parentUserId: family.parent.userId,
      });
      const invite = await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } });
      expect(invite.closedAt).not.toBeNull();
      expect(invite.studentConfirmedAt).not.toBeNull();
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
      expect((await timetable(t, family.child)).statusCode).toBe(200);
      expect((await appReq(t, family.parent.token, 'GET', '/parent/school/links')).json().links[0].students[0]).toMatchObject({
        childId: family.child.childId,
        linkedBy: 'ME',
      });
      const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'student.childLinked' } });
      expect(audit).toMatchObject({ actorId: null, actorName: 'Bola ilovasi', params: { name: 'Karimov Aziz' } });
    });

    it('child first (UNDER_REVIEW), then the child\'s trusted parent enters the code: the link becomes CONFIRMED and the notification clears', async () => {
      const family = await newFamily(t, 'Aziz');
      await trustParent(t, w.aziz, family);
      const code = await issueCode(t, w.director, w.aziz.id);
      expect((await childLink(t, family.child, code)).json().student.status).toBe('UNDER_REVIEW');
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(1);

      const parent = await parentLink(t, family.parent, code);

      expect(parent.statusCode).toBe(200);
      expect(parent.json().links[0].students[0]).toMatchObject({ id: w.aziz.id, childId: family.child.childId, linkedBy: 'ME' });
      expect((await linkStatus(t, family.child)).json()).toEqual({
        student: { status: 'CONFIRMED', schoolName: SCHOOL_NAME, className: '7-A' },
        parent: { status: 'CONFIRMED' },
        expiresAt: null,
      });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
      expect((await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } })).closedAt).not.toBeNull();
    });

    it('a different (untrusted) parent entering the parent slot does NOT confirm a stranger\'s child (stays UNDER_REVIEW, code closed)', async () => {
      const kid = await newFamily(t, 'Begona bola');
      const other = await newFamily(t, 'Boshqa');
      const code = await issueCode(t, w.director, w.aziz.id);
      await childLink(t, kid.child, code);

      expect((await parentLink(t, other.parent, code)).statusCode).toBe(200);

      const status = (await linkStatus(t, kid.child)).json();
      expect(status.student.status).toBe('UNDER_REVIEW');
      expect(status.parent.status).toBe('EXPIRED');
      expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBeNull();
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(1);
    });

    it('auto-confirms when the child\'s parent is already a linked guardian of the student', async () => {
      const family = await newFamily(t, 'Aziz');
      await linkGuardian(t, w.schoolId, w.aziz.id, family.parent);
      const code = await issueCode(t, w.director, w.aziz.id);

      const res = await childLink(t, family.child, code);

      expect(res.json()).toMatchObject({ student: { status: 'CONFIRMED', schoolName: SCHOOL_NAME, className: '7-A' }, parent: { status: 'CONFIRMED' } });
      expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBe(family.child.childId);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
    });

    it('never fails the parent when the student already belongs to another family: the child stays UNDER_REVIEW', async () => {
      const family = await newFamily(t, 'Aziz');
      const rival = await newFamily(t, 'Raqib');
      await trustParent(t, w.aziz, family);
      const code = await issueCode(t, w.director, w.aziz.id);
      expect((await childLink(t, family.child, code)).json().student.status).toBe('UNDER_REVIEW');
      // Poyga: o'quvchi kutish paytida boshqa oila farzandiga ulangan (qo'lda; ilova yo'llari buni tozalaydi)
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { childId: rival.child.childId } });

      const res = await parentLink(t, family.parent, code);

      expect(res.statusCode).toBe(200);
      expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBe(rival.child.childId);
      expect((await linkStatus(t, family.child)).json().student).toEqual({ status: 'UNDER_REVIEW', schoolName: null, className: null });
    });
  });

  describe('parent: POST /parent/school/link with a 6-digit code', () => {
    it('matches an existing school guardian by phone (no duplicate guardian), then returns the standard links shape', async () => {
      const family = await newFamily(t);
      await t.prisma.user.update({ where: { id: family.parent.userId }, data: { phone: '+998901234567' } });
      const known = await createGuardian(t.prisma, w.schoolId, [w.aziz.id], { fullName: 'Karimova Malika' });
      const code = await issueCode(t, w.director, w.aziz.id);

      const res = await parentLink(t, family.parent, code);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toMatchObject({
        links: [{ guardianId: known.id, fullName: 'Karimova Malika', students: [{ id: w.aziz.id }] }],
        children: [{ id: family.child.childId }],
      });
      expect(await t.prisma.schoolGuardian.count({ where: { schoolId: w.schoolId } })).toBe(1);
      expect(await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: known.id } })).toMatchObject({
        userId: family.parent.userId,
        linkStatus: 'LINKED',
      });
    });

    it('does not take over a guardian row that is already linked to someone else: the code alone grants nothing (pending review)', async () => {
      const owner = await newFamily(t);
      const family = await newFamily(t);
      await t.prisma.user.update({ where: { id: family.parent.userId }, data: { phone: '+998901234567' } });
      await linkGuardian(t, w.schoolId, w.aziz.id, owner.parent); // phone '+998 90 123 45 67', userId = owner
      const code = await issueCode(t, w.director, w.aziz.id);

      const res = await parentLink(t, family.parent, code);

      expect(res.statusCode).toBe(200);
      const guardians = await t.prisma.schoolGuardian.findMany({ where: { schoolId: w.schoolId } });
      expect(guardians.map((g) => g.userId)).toEqual([owner.parent.userId]);
      expect(res.json().links).toEqual([expect.objectContaining({ status: 'PENDING_REVIEW', guardianId: null, students: [] })]);
      expect(await t.prisma.schoolGuardianReview.count({ where: { userId: family.parent.userId, status: 'OPEN' } })).toBe(1);
    });

    it('is idempotent for a trusted parent and refuses a second parent', async () => {
      const family = await newFamily(t);
      const second = await newFamily(t);
      await trustParent(t, w.aziz, family);
      const code = await issueCode(t, w.director, w.aziz.id);
      expect((await parentLink(t, family.parent, code)).statusCode).toBe(200);

      expect((await parentLink(t, family.parent, code)).statusCode).toBe(200);
      expect(await t.prisma.schoolGuardian.count({ where: { userId: family.parent.userId } })).toBe(1);
      const refused = await parentLink(t, second.parent, code);
      expect([refused.statusCode, refused.json().code]).toEqual([404, 'INVITE_INVALID']);
    });

    it('rejects invalid / expired / closed codes with INVITE_INVALID and shares the failure limit with 8-character codes', async () => {
      const family = await newFamily(t);
      const code = await issueCode(t, w.director, w.aziz.id);
      await t.prisma.schoolStudentInvite.updateMany({ where: { studentId: w.aziz.id }, data: { expiresAt: new Date(Date.now() - 1000) } });
      const expired = await parentLink(t, family.parent, code);
      expect([expired.statusCode, expired.json().code]).toEqual([404, 'INVITE_INVALID']);
      const unknown = await parentLink(t, family.parent, wrongOf(code));
      expect([unknown.statusCode, unknown.json().code]).toEqual([404, 'INVITE_INVALID']);
      // 8 belgili noto'g'ri kodlar ham shu hisobga qo'shiladi (jami 5 -> bloklanadi)
      for (const wrong of ['ZZZZZZ22', 'ZZZZZZ23', 'ZZZZZZ24']) expect((await parentLink(t, family.parent, wrong)).json().code).toBe('INVITE_INVALID');

      const fresh = await issueCode(t, w.director, w.aziz.id);
      const blocked = await parentLink(t, family.parent, fresh);

      expect(blocked.statusCode).toBe(429);
      expect(blocked.json().code).toBe('TOO_MANY_ATTEMPTS');
      expect(await t.prisma.schoolGuardian.count({ where: { userId: family.parent.userId } })).toBe(0);
    });

    it('still validates the format: 5 digits / garbage -> 400', async () => {
      const mom = await createParent(t.prisma);
      for (const code of ['12345', '1234567', 'AB', '']) {
        const res = await parentLink(t, mom, code);
        expect([res.statusCode, res.json().code]).toEqual([400, 'VALIDATION']);
      }
      expect((await appReq(t, (await newFamily(t)).child.token, 'POST', '/parent/school/link', { code: '123456' })).statusCode).toBe(403);
    });
  });

  describe('legacy 8-character guardian codes', () => {
    it('keep working exactly as before next to student codes', async () => {
      const family = await newFamily(t);
      const guardian = await createGuardian(t.prisma, w.schoolId, [w.aziz.id]);
      const invited = await schoolReq(t, w.director, 'POST', `/guardians/${guardian.id}/invite`);
      const legacy = invited.json().inviteCode as string;
      expect(legacy).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);

      const linked = await parentLink(t, family.parent, legacy.toLowerCase());

      expect(linked.statusCode).toBe(200);
      expect(linked.json().links[0]).toMatchObject({ guardianId: guardian.id, students: [{ id: w.aziz.id, linkedBy: 'NONE' }] });
      expect(await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: guardian.id } })).toMatchObject({ linkStatus: 'LINKED', inviteCode: null });
      expect((await parentLink(t, family.parent, legacy)).json().code).toBe('INVITE_INVALID');
      // Eski oqim bilan ulangan ota-onaning bolasi 6 raqamli kodni kiritganda darhol CONFIRMED
      const code = await issueCode(t, w.director, w.aziz.id);
      expect((await childLink(t, family.child, code)).json().student.status).toBe('CONFIRMED');
    });
  });

  // ── Yordamchilar ───────────────────────────────────────────────────

  async function buildOtherSchool() {
    const { school } = await createSchool(t.prisma, 'other-school');
    return { admin: await staffSession(t, school.id, 'ADMIN', 'admin-other') };
  }
});

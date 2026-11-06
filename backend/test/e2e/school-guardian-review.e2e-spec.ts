// Ishonchsiz ota-onaning vasiylik so'rovi (K2): 6 raqamli kod O'ZI vasiylik bermaydi. Maktab bilmaydigan ota-ona kodni kiritsa
// vasiy ULANMAYDI — xodim ko'rigidagi so'rov (`GUARDIAN`) yaratiladi, ota-ona o'rni band, xodimga GUARDIAN_REVIEW; tasdiqlanmaguncha
// hech qanday o'quvchi ma'lumotiga kirish yo'q. Tasdiq -> vasiy (+ kutayotgan farzand CONFIRMED); rad -> o'rin bo'shaydi.

import { randomUUID } from 'node:crypto';
import { resetDb } from './db';
import { createModerator } from './factories';
import { staffSession } from './school-attendance-fixtures';
import { appReq, schoolReq } from './school-child-fixtures';
import { createSchool } from './school-fixtures';
import {
  buildCodeWorld,
  childLink,
  CodeWorld,
  confirm,
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
  SCHOOL_NAME,
  trustParent,
  withoutPermission,
} from './school-student-code-fixtures';
import { createTestApp, TestApp } from './test-app';

const PHONE = '+998901234567';

describe('School guardian review — a 6-digit code alone never grants guardianship (K2)', () => {
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

  /** Maktab bilmaydigan ota-ona 6 raqamli kodni kiritadi -> vasiylik so'rovi. */
  async function pendingGuardian(over: { phone?: string; childName?: string; student?: CodeWorld['aziz'] } = {}) {
    const student = over.student ?? w.aziz;
    const family = await newFamily(t, over.childName ?? 'Aziz', 'Karimova');
    if (over.phone) await t.prisma.user.update({ where: { id: family.parent.userId }, data: { phone: over.phone } });
    const code = await issueCode(t, w.director, student.id);
    const res = await parentLink(t, family.parent, code);
    expect(res.statusCode).toBe(200);
    const review = await t.prisma.schoolGuardianReview.findFirstOrThrow({ where: { userId: family.parent.userId } });
    return { family, code, review, response: res.json() };
  }

  const reviewOf = (id: string) => t.prisma.schoolGuardianReview.findUniqueOrThrow({ where: { id } });
  const inviteOf = (studentId: string) => t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId }, orderBy: { createdAt: 'desc' } });
  const guardiansOf = (userId: string) => t.prisma.schoolGuardian.findMany({ where: { userId } });
  const kinds = async (who: Parameters<typeof feed>[1]) => (await feed(t, who)).json().map((n: { kind: string }) => n.kind);

  describe('redemption without a school-known phone', () => {
    it('does not link the guardian: a pending review, parent slot used, staff notified, the parent sees a pending entry with NO student data', async () => {
      const { family, code, review, response } = await pendingGuardian({ phone: PHONE });

      const user = await t.prisma.user.findUniqueOrThrow({ where: { id: family.parent.userId } });
      expect(response).toEqual({
        links: [
          {
            status: 'PENDING_REVIEW',
            guardianId: null,
            reviewId: review.id,
            fullName: user.name,
            relation: 'OTHER',
            linkedAt: null,
            requestedAt: expect.any(String),
            school: { id: w.schoolId, name: SCHOOL_NAME, shortName: expect.any(String), city: expect.any(String), logo: null },
            students: [],
          },
        ],
        children: [{ id: family.child.childId, name: 'Aziz' }],
      });
      expect(JSON.stringify(response)).not.toMatch(/Karimov Aziz|7-A|Rahimov/);
      expect(JSON.stringify(response)).not.toContain(w.aziz.id);

      expect(await guardiansOf(family.parent.userId)).toEqual([]);
      expect(await t.prisma.schoolGuardian.count({ where: { schoolId: w.schoolId } })).toBe(0);
      expect(review).toMatchObject({ status: 'OPEN', schoolId: w.schoolId, studentId: w.aziz.id, userId: family.parent.userId });
      const invite = await inviteOf(w.aziz.id);
      expect(review.inviteId).toBe(invite.id);
      expect(invite).toMatchObject({ parentUserId: family.parent.userId, closedAt: null });
      expect(invite.code).toBe(code);
      expect((await currentCode(t, w.director, w.aziz.id)).json().parent.status).toBe('USED');
      // Maktab vasiylari ro'yxatida u yo'q (vasiy yozuvi yaratilmagan)
      expect((await schoolReq(t, w.director, 'GET', '/guardians/stats')).json()).toMatchObject({ LINKED: 0, total: 0 });

      const note = await t.prisma.schoolStaffNotification.findFirstOrThrow({ where: { kind: 'GUARDIAN_REVIEW' } });
      expect(note).toMatchObject({
        id: `guardian-review:${review.id}`,
        schoolId: w.schoolId,
        roles: ['ADMIN', 'DIRECTOR', 'HOMEROOM'],
        classIds: [w.classA],
        params: { studentName: 'Karimov Aziz', className: '7-A' },
      });
      expect(Object.keys(note.params as object).sort()).toEqual(['className', 'studentName']);
      expect(note.href).toBe('/students/link-requests');
      expect([...note.staffIds].sort()).toEqual([w.director.staffId, w.admin.staffId, w.homeroomA.staffId].sort());
      expect((await feed(t, w.admin)).json()).toEqual([
        {
          id: `guardian-review:${review.id}`,
          kind: 'GUARDIAN_REVIEW',
          at: expect.any(String),
          tone: 'warning',
          params: { studentName: 'Karimov Aziz', className: '7-A' },
          subject: null,
          href: '/students/link-requests',
        },
      ]);
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'guardian.reviewRequested' } })).toBe(1);
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'guardian.linked' } })).toBe(0);
    });

    it('a pending guardian gets NO access: no student data, messages, attendance, pickup or early dismissal', async () => {
      const { family } = await pendingGuardian({ phone: PHONE });
      const known = await newFamily(t, 'Boshqa');
      await trustParent(t, w.aziz, known);
      expect((await parentLink(t, known.parent, await issueCode(t, w.director, w.aziz.id))).statusCode).toBe(200);
      const call = (token: string, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, body?: object) => appReq(t, token, method, url, body);
      const pending = family.parent.token;

      // Nazorat: ulangan vasiy shu o'quvchining davomatini ko'radi (so'rovlar to'g'ri tuzilgan)
      expect((await call(known.parent.token, 'GET', `/parent/school/attendance?studentId=${w.aziz.id}&month=2026-10`)).statusCode).toBe(200);

      // Ro'yxat yo'llari bo'sh
      const announcements = (await call(pending, 'GET', '/parent/school/announcements')).json();
      expect(announcements.items).toEqual([]);
      expect(announcements.unread).toBe(0);
      expect((await call(pending, 'GET', '/parent/school/payments')).json()).toEqual([]);
      expect((await call(pending, 'GET', '/parent/school/verifications')).json()).toEqual([]);
      expect((await call(pending, 'GET', '/parent/school/early-exits')).json()).toEqual([]);
      // O'quvchiga bog'liq yo'llar — 404 (o'quvchi ma'lumoti hatto mavjudligi ham ochilmaydi)
      expect((await call(pending, 'GET', `/parent/school/attendance?studentId=${w.aziz.id}&month=2026-10`)).statusCode).toBe(404);
      const exit = await call(pending, 'POST', '/parent/school/early-exits', { studentId: w.aziz.id, time: '11:00', reason: 'Shifokor', pickupBy: 'Onasi' });
      expect(exit.statusCode).toBe(404);
      expect((await call(pending, 'PUT', `/parent/school/students/${w.aziz.id}/child`, { childId: family.child.childId })).statusCode).toBe(404);
      expect(await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).toMatchObject({ childId: null });
      // Aloqani uzish yo'li ham vasiy yozuvi talab qiladi
      const review = await t.prisma.schoolGuardianReview.findFirstOrThrow({ where: { userId: family.parent.userId } });
      expect((await call(pending, 'DELETE', `/parent/school/links/${review.id}`)).statusCode).toBe(404);
    });

    it('defense in depth: even a guardian row that carries a userId but is not LINKED opens nothing', async () => {
      const family = await newFamily(t);
      await t.prisma.schoolGuardian.create({
        data: {
          schoolId: w.schoolId,
          fullName: 'Noto\'g\'ri holat',
          phone: '+998 90 111 22 33',
          relation: 'MOTHER',
          linkStatus: 'NOT_INVITED',
          userId: family.parent.userId,
          students: { create: { studentId: w.aziz.id } },
        },
      });
      const token = family.parent.token;

      expect((await appReq(t, token, 'GET', `/parent/school/attendance?studentId=${w.aziz.id}&month=2026-10`)).statusCode).toBe(404);
      expect((await appReq(t, token, 'GET', '/parent/school/early-exits')).json()).toEqual([]);
      const exit = await appReq(t, token, 'POST', '/parent/school/early-exits', { studentId: w.aziz.id, time: '11:00', reason: 'Shifokor', pickupBy: 'Onasi' });
      expect(exit.statusCode).toBe(404);
      expect((await appReq(t, token, 'GET', '/parent/school/links')).json().links).toEqual([]);
    });

    it('trusted cases link at once and create no review: already this student\'s guardian (a), school record with the same real phone (b)', async () => {
      // (a) allaqachon shu o'quvchining vasiysi
      const mine = await newFamily(t);
      const record = await trustParent(t, w.aziz, mine);
      await t.prisma.schoolGuardian.update({ where: { id: record.id }, data: { userId: mine.parent.userId, linkStatus: 'LINKED', linkedAt: new Date() } });
      const first = await parentLink(t, mine.parent, await issueCode(t, w.director, w.aziz.id));
      expect(first.json().links).toEqual([expect.objectContaining({ status: 'LINKED', guardianId: record.id })]);

      // (b) hech kimga ulanmagan maktab yozuvi, telefon boshqa formatda ham mos (oxirgi 9 raqam)
      const other = await newFamily(t);
      await t.prisma.user.update({ where: { id: other.parent.userId }, data: { phone: '901234567' } });
      const school = await t.prisma.schoolGuardian.create({
        data: { schoolId: w.schoolId, fullName: 'Rahimova Dilfuza', phone: '+998 90 123 45 67', relation: 'MOTHER', students: { create: { studentId: w.bobur.id } } },
      });
      const second = await parentLink(t, other.parent, await issueCode(t, w.director, w.bobur.id));
      expect(second.json().links).toEqual([expect.objectContaining({ status: 'LINKED', guardianId: school.id, fullName: 'Rahimova Dilfuza' })]);
      expect(await t.prisma.schoolGuardianReview.count()).toBe(0);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(0);
    });

    it('re-entering the same code is idempotent (one review, one notification); a regenerated code moves the review to the new parent slot', async () => {
      const { family, code, review } = await pendingGuardian({ phone: PHONE });

      expect((await parentLink(t, family.parent, code)).statusCode).toBe(200);
      expect(await t.prisma.schoolGuardianReview.count()).toBe(1);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(1);

      const fresh = await issueCode(t, w.director, w.aziz.id);
      expect((await parentLink(t, family.parent, fresh)).statusCode).toBe(200);

      expect(await t.prisma.schoolGuardianReview.count()).toBe(1);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(1);
      const moved = await reviewOf(review.id);
      expect(moved.inviteId).toBe((await inviteOf(w.aziz.id)).id);
      expect((await currentCode(t, w.director, w.aziz.id)).json().parent.status).toBe('USED');
    });
  });

  describe('GET /school/link-requests — kind GUARDIAN', () => {
    it('lists the parent display name, a masked phone and the student; the parent\'s waiting child is shown; scoped by class', async () => {
      const { family, code, review } = await pendingGuardian({ phone: PHONE });
      expect((await childLink(t, family.child, code)).json().student.status).toBe('UNDER_REVIEW');
      const other = await pendingGuardian({ student: w.sardor, childName: 'Sardor' });
      const user = await t.prisma.user.findUniqueOrThrow({ where: { id: family.parent.userId } });

      const list = (await requests(t, w.director)).json();

      const item = list.find((r: { id: string }) => r.id === review.id);
      expect(item).toEqual({
        id: review.id,
        kind: 'GUARDIAN',
        createdAt: expect.any(String),
        student: { id: w.aziz.id, fullName: 'Karimov Aziz', classId: w.classA, className: '7-A' },
        child: { name: 'Aziz' },
        parent: { name: user.name, maskedPhone: '+998 ** *** 45 67' },
        parentLinked: false,
        reason: null,
        note: null,
      });
      // Ikkinchisida telefon va farzand ko'rigi yo'q
      expect(list.find((r: { id: string }) => r.id === other.review.id)).toMatchObject({ kind: 'GUARDIAN', parent: { maskedPhone: null }, child: null });
      // Telefonning to'liq qiymati hech qayerda yo'q
      expect(JSON.stringify(list)).not.toContain('901234567');
      // Doira
      const guardianIds = async (who: Parameters<typeof requests>[1]) =>
        (await requests(t, who)).json().filter((r: { kind: string }) => r.kind === 'GUARDIAN').map((r: { id: string }) => r.id);
      expect(await guardianIds(w.homeroomA)).toEqual([review.id]);
      expect(await guardianIds(w.homeroomB)).toEqual([other.review.id]);
      // Bolaning o'z so'rovi (REVIEW) ham shu navbatda, alohida element sifatida
      expect(list.filter((r: { kind: string }) => r.kind === 'REVIEW')).toHaveLength(1);
      for (const who of [w.teacher, w.duty, w.psych]) expect((await requests(t, who)).statusCode).toBe(403);
    });

    it('never offers a Telegram placeholder phone', async () => {
      const { review } = await pendingGuardian({ phone: 'tg:987654321' });

      const item = (await requests(t, w.director)).json().find((r: { id: string }) => r.id === review.id);

      expect(item.parent.maskedPhone).toBeNull();
      expect(JSON.stringify(item)).not.toContain('987654321');
    });
  });

  describe('confirm / reject', () => {
    it('confirm: the guardian is LINKED from the parent profile, the parent\'s waiting child is CONFIRMED, notification cleared, audited, idempotent', async () => {
      const { family, code, review } = await pendingGuardian({ phone: PHONE });
      await childLink(t, family.child, code);
      expect((await linkStatus(t, family.child)).json()).toEqual({
        student: { status: 'UNDER_REVIEW', schoolName: null, className: null },
        parent: { status: 'UNDER_REVIEW' },
        expiresAt: null,
      });

      const res = await confirm(t, w.homeroomA, review.id);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ id: review.id, kind: 'GUARDIAN', status: 'CONFIRMED' });
      const user = await t.prisma.user.findUniqueOrThrow({ where: { id: family.parent.userId } });
      const guardians = await guardiansOf(family.parent.userId);
      expect(guardians).toHaveLength(1);
      expect(guardians[0]).toMatchObject({ linkStatus: 'LINKED', relation: 'OTHER', schoolId: w.schoolId, fullName: user.name, phone: PHONE });
      expect(await reviewOf(review.id)).toMatchObject({ status: 'CONFIRMED', resolvedByStaffId: w.homeroomA.staffId });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(0);
      expect((await requests(t, w.director)).json()).toEqual([]);
      // Ota-ona endi haqiqiy vasiy; farzandi avtomatik tasdiqlandi
      const links = (await appReq(t, family.parent.token, 'GET', '/parent/school/links')).json().links;
      expect(links).toEqual([
        expect.objectContaining({
          status: 'LINKED',
          guardianId: guardians[0]!.id,
          students: [{ id: w.aziz.id, fullName: 'Karimov Aziz', className: '7-A', childId: family.child.childId, linkedBy: 'ME' }],
        }),
      ]);
      expect((await linkStatus(t, family.child)).json()).toEqual({
        student: { status: 'CONFIRMED', schoolName: SCHOOL_NAME, className: '7-A' },
        parent: { status: 'CONFIRMED' },
        expiresAt: null,
      });
      expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBe(family.child.childId);
      expect((await appReq(t, family.parent.token, 'GET', `/parent/school/attendance?studentId=${w.aziz.id}&month=2026-10`)).statusCode).toBe(200);
      const linked = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'guardian.linked' } });
      expect(linked).toMatchObject({ actorId: w.homeroomA.staffId, module: 'GUARDIANS', entityId: guardians[0]!.id });
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'student.childLinked', actorId: w.homeroomA.staffId } })).toBe(1);

      expect((await confirm(t, w.director, review.id)).json()).toEqual({ id: review.id, kind: 'GUARDIAN', status: 'CONFIRMED' });
      const late = await reject(t, w.director, review.id);
      expect([late.statusCode, late.json().code]).toEqual([409, 'REQUEST_STALE']);
      expect(await guardiansOf(family.parent.userId)).toHaveLength(1);
    });

    it('confirm links the school record that matches the phone by now instead of creating a duplicate', async () => {
      const { family, review } = await pendingGuardian({ phone: PHONE });
      const record = await t.prisma.schoolGuardian.create({
        data: { schoolId: w.schoolId, fullName: 'Karimova Malika', phone: '+998 90 123 45 67', relation: 'MOTHER', students: { create: { studentId: w.aziz.id } } },
      });

      expect((await confirm(t, w.admin, review.id)).statusCode).toBe(200);

      expect(await t.prisma.schoolGuardian.count({ where: { schoolId: w.schoolId } })).toBe(1);
      expect(await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: record.id } })).toMatchObject({
        userId: family.parent.userId,
        linkStatus: 'LINKED',
        fullName: 'Karimova Malika',
      });
    });

    it('reject: nothing is linked, the parent slot is freed, the parent cannot re-enter that code, another parent can; idempotent; audited', async () => {
      const { family, code, review } = await pendingGuardian({ phone: PHONE });

      const res = await reject(t, w.homeroomA, review.id);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ id: review.id, kind: 'GUARDIAN', status: 'REJECTED' });
      expect(await reviewOf(review.id)).toMatchObject({ status: 'REJECTED', resolvedByStaffId: w.homeroomA.staffId });
      expect(await guardiansOf(family.parent.userId)).toEqual([]);
      expect(await inviteOf(w.aziz.id)).toMatchObject({ parentUserId: null, parentUsedAt: null });
      expect((await currentCode(t, w.director, w.aziz.id)).json().parent).toEqual({ status: 'FREE', usedAt: null });
      expect((await appReq(t, family.parent.token, 'GET', '/parent/school/links')).json().links).toEqual([]);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(0);
      expect((await requests(t, w.director)).json()).toEqual([]);
      const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'guardian.linkRejected' } });
      expect(audit).toMatchObject({ actorId: w.homeroomA.staffId, module: 'GUARDIANS', entityId: w.aziz.id, params: { name: 'Karimov Aziz' } });

      // Rad etilgan ota-ona shu kodni qayta kirita olmaydi (xodim bezovta qilinmaydi) ...
      const again = await parentLink(t, family.parent, code);
      expect([again.statusCode, again.json().code]).toEqual([404, 'INVITE_INVALID']);
      expect(await t.prisma.schoolGuardianReview.count({ where: { userId: family.parent.userId } })).toBe(1);
      // ... boshqa ota-ona esa bo'shagan o'rinni egallay oladi (kod hali faol)
      const second = await newFamily(t);
      const reused = await parentLink(t, second.parent, code);
      expect(reused.statusCode).toBe(200);
      expect(reused.json().links).toEqual([expect.objectContaining({ status: 'PENDING_REVIEW' })]);

      // Takroriy rad etish — o'sha javob; tasdiqlash — eskirgan
      expect((await reject(t, w.director, review.id)).json()).toEqual({ id: review.id, kind: 'GUARDIAN', status: 'REJECTED' });
      const stale = await confirm(t, w.director, review.id);
      expect([stale.statusCode, stale.json().code]).toEqual([409, 'REQUEST_STALE']);
      expect(await guardiansOf(family.parent.userId)).toEqual([]);
    });

    it('is class-scoped and permission-gated like the other requests; unknown / other-school ids are 404; an archived student is stale', async () => {
      const { review } = await pendingGuardian({ phone: PHONE });
      const other = await createSchool(t.prisma, 'other-school');
      const stranger = await staffSession(t, other.school.id, 'ADMIN', 'admin-other');

      for (const action of [confirm, reject]) {
        expect((await action(t, w.homeroomB, review.id)).statusCode).toBe(403);
        expect((await action(t, stranger, review.id)).statusCode).toBe(404);
        expect((await action(t, w.director, randomUUID())).statusCode).toBe(404);
        for (const who of [w.teacher, w.duty, w.psych]) expect((await action(t, who, review.id)).statusCode).toBe(403);
      }
      expect(await reviewOf(review.id)).toMatchObject({ status: 'OPEN' });

      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { archived: true } });
      const stale = await confirm(t, w.director, review.id);
      expect([stale.statusCode, stale.json().code]).toEqual([409, 'REQUEST_STALE']);
    });

    it('a decision race ends consistently: confirm vs reject -> exactly one wins; confirm vs confirm -> one guardian', async () => {
      const first = await pendingGuardian({ phone: PHONE });

      const [a, b] = await Promise.all([confirm(t, w.director, first.review.id), reject(t, w.admin, first.review.id)]);

      expect([a.statusCode, b.statusCode].sort()).toEqual([200, 409]);
      const settled = await reviewOf(first.review.id);
      const guardians = await guardiansOf(first.family.parent.userId);
      if (settled.status === 'CONFIRMED') {
        expect(guardians).toHaveLength(1);
      } else {
        expect(guardians).toHaveLength(0);
        expect(await inviteOf(w.aziz.id)).toMatchObject({ parentUserId: null });
      }

      const second = await pendingGuardian({ student: w.bobur, phone: '+998912223344', childName: 'Bobur' });
      const both = await Promise.all([confirm(t, w.director, second.review.id), confirm(t, w.admin, second.review.id)]);
      expect(both.map((r) => r.statusCode)).toEqual([200, 200]);
      expect(await guardiansOf(second.family.parent.userId)).toHaveLength(1);
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'guardian.linked', entityId: (await guardiansOf(second.family.parent.userId))[0]!.id } })).toBe(1);
    });
  });

  describe('the child sees the parent state', () => {
    it('own parent redeemed but awaits staff: parent.status UNDER_REVIEW (no expiry); after rejection the closed code reads EXPIRED', async () => {
      const { family, code, review } = await pendingGuardian({ phone: PHONE });

      const status = (await childLink(t, family.child, code)).json();
      expect(status).toEqual({
        student: { status: 'UNDER_REVIEW', schoolName: null, className: null },
        parent: { status: 'UNDER_REVIEW' },
        expiresAt: null,
      });
      expect((await linkStatus(t, family.child)).json()).toEqual(status);

      expect((await reject(t, w.director, review.id)).statusCode).toBe(200);
      // Ikkala o'rin band bo'lib kod yopilgan edi: ota-ona o'rni bo'shagach ham yopiq — yangi kod kerak
      expect((await linkStatus(t, family.child)).json()).toMatchObject({ student: { status: 'UNDER_REVIEW' }, parent: { status: 'EXPIRED' } });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(1);
    });

    it('a child-only waiting state is unchanged for a parent without a request: PENDING with the code expiry', async () => {
      const family = await newFamily(t);
      const code = await issueCode(t, w.director, w.aziz.id);

      expect((await childLink(t, family.child, code)).json()).toEqual({
        student: { status: 'UNDER_REVIEW', schoolName: null, className: null },
        parent: { status: 'PENDING' },
        expiresAt: expect.any(String),
      });
    });
  });

  describe('recipients and clean-up', () => {
    it('GUARDIAN_REVIEW follows the permission rule: a homeroom without guardians.link is not notified', async () => {
      const restore = withoutPermission(['HOMEROOM']);
      try {
        const { review } = await pendingGuardian({ phone: PHONE });

        const note = await t.prisma.schoolStaffNotification.findFirstOrThrow({ where: { kind: 'GUARDIAN_REVIEW' } });
        expect(note.id).toBe(`guardian-review:${review.id}`);
        expect(note.roles).toEqual(['ADMIN', 'DIRECTOR']);
        expect(note.staffIds).not.toContain(w.homeroomA.staffId);
        expect(await kinds(w.homeroomA)).toEqual([]);
        expect(await kinds(w.director)).toEqual(['GUARDIAN_REVIEW']);
      } finally {
        restore();
      }
    });

    it('an admin deleting the parent removes the review and its notification and frees the parent slot', async () => {
      const { family, code } = await pendingGuardian({ phone: PHONE });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(1);
      const moderator = await createModerator(t.prisma, ['manage_users']);

      const res = await t.app.inject({
        method: 'DELETE',
        url: `/api/admin/users/${family.parent.userId}`,
        headers: { authorization: `Bearer ${moderator.token}` },
      });

      expect(res.statusCode).toBe(200);
      expect(await t.prisma.schoolGuardianReview.count()).toBe(0);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(0);
      expect((await currentCode(t, w.director, w.aziz.id)).json().parent.status).toBe('FREE');
      // O'rin bo'shadi: boshqa ota-ona shu kodni kirita oladi
      const next = await newFamily(t);
      expect((await parentLink(t, next.parent, code)).statusCode).toBe(200);
    });
  });
});

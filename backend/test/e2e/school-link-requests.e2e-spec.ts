// Ulanish so'rovlari (K2): xodim navbati (UNDER_REVIEW bog'lanishlar + bolaning tuzatish so'rovlari), tasdiqlash /
// rad etish (doira, invariantlar, idempotentlik), bildirishnomalar (LINK_REVIEW / LINK_CORRECTION) va tuzatish
// so'rovi (A08): ochiq bo'lganda bolaning maktab ma'lumoti yopiq.

import { randomUUID } from 'node:crypto';
import { resetDb } from './db';
import { createChild } from './factories';
import { linkGuardian, staffSession } from './school-attendance-fixtures';
import { appReq } from './school-child-fixtures';
import { createSchool } from './school-fixtures';
import {
  buildCodeWorld,
  childLink,
  CodeWorld,
  confirm,
  confirmedLink,
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
  timetable,
  withoutPermission,
} from './school-student-code-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School link requests and corrections (K2)', () => {
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

  /** Bola kodni kiritadi (ota-onasiz) -> UNDER_REVIEW; kod yozuvini qaytaradi. */
  async function pendingLink(family: Family, studentId: string) {
    const code = await issueCode(t, w.director, studentId);
    const res = await childLink(t, family.child, code);
    expect(res.json().student.status).toBe('UNDER_REVIEW');
    const invite = await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId, studentChildId: family.child.childId } });
    // Xodim ro'yxatidagi REVIEW so'rovining id'si: kod yozuvi + bola.
    return { code, invite, requestId: `${invite.id}:${family.child.childId}` };
  }

  const correction = (family: Family, over: Record<string, unknown> = {}) =>
    appReq(t, family.child.token, 'POST', '/child/school/correction', {
      reason: 'WRONG_SCHOOL_OR_CLASS',
      note: 'Men 7-B sinfdaman',
      clientRequestId: randomUUID(),
      ...over,
    });

  const studentRow = (id: string) => t.prisma.schoolStudent.findUniqueOrThrow({ where: { id } });

  describe('GET /school/link-requests', () => {
    it('lists pending links with the exact shape, scoped by class; roles without guardians.link are rejected', async () => {
      const a = await newFamily(t, 'Aziz');
      const b = await newFamily(t, 'Sardor');
      const { invite, requestId } = await pendingLink(a, w.aziz.id);
      await pendingLink(b, w.sardor.id);
      await linkGuardian(t, w.schoolId, w.sardor.id, b.parent); // ota-ona ulangan -> belgisi

      const director = (await requests(t, w.director)).json();
      expect(director).toHaveLength(2);
      const first = director.find((r: { id: string }) => r.id === requestId);
      expect(first).toEqual({
        id: requestId,
        kind: 'REVIEW',
        createdAt: expect.any(String),
        student: { id: w.aziz.id, fullName: 'Karimov Aziz', classId: w.classA, className: '7-A' },
        child: { name: 'Aziz' },
        parent: null,
        parentLinked: false,
        reason: null,
        note: null,
      });
      expect(director.find((r: { student: { id: string } }) => r.student.id === w.sardor.id)).toMatchObject({ parentLinked: true, child: { name: 'Sardor' } });

      expect((await requests(t, w.homeroomA)).json().map((r: { student: { id: string } }) => r.student.id)).toEqual([w.aziz.id]);
      expect((await requests(t, w.homeroomB)).json().map((r: { student: { id: string } }) => r.student.id)).toEqual([w.sardor.id]);
      expect((await requests(t, w.admin)).json()).toHaveLength(2);
      for (const who of [w.teacher, w.duty, w.psych]) expect((await requests(t, who)).statusCode).toBe(403);
    });

    it('lists a student without a class with classId and className null', async () => {
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { classId: null } });
      const family = await newFamily(t, 'Aziz');
      await pendingLink(family, w.aziz.id);

      const [item] = (await requests(t, w.director)).json();

      expect(item.student).toEqual({ id: w.aziz.id, fullName: 'Karimov Aziz', classId: null, className: null });
      // Sinf rahbari ko'rmaydi (sinfsiz o'quvchi — faqat butun maktab doirasidagilar)
      expect((await requests(t, w.homeroomA)).json()).toEqual([]);
    });

    it('includes open corrections with the child\'s note, oldest first, and skips archived students', async () => {
      const family = await newFamily(t, 'Aziz');
      const other = await newFamily(t, 'Bobur');
      await confirmedLink(t, w.director, w.aziz, family);
      const created = (await correction(family, { note: 'Sinfim 7-B' })).json();
      await pendingLink(other, w.bobur.id);

      const list = (await requests(t, w.director)).json();

      expect(list.map((r: { kind: string }) => r.kind)).toEqual(['CORRECTION', 'REVIEW']);
      expect(list[0]).toEqual({
        id: created.id,
        kind: 'CORRECTION',
        createdAt: expect.any(String),
        student: { id: w.aziz.id, fullName: 'Karimov Aziz', classId: w.classA, className: '7-A' },
        child: { name: 'Aziz' },
        parent: null,
        parentLinked: true,
        reason: 'WRONG_SCHOOL_OR_CLASS',
        note: 'Sinfim 7-B',
      });
      await t.prisma.schoolStudent.update({ where: { id: w.bobur.id }, data: { archived: true } });
      expect((await requests(t, w.director)).json()).toHaveLength(1);
    });
  });

  describe('confirm / reject a pending link', () => {
    it('confirm: sets SchoolStudent.childId, opens school data, clears the notification, audits, is idempotent', async () => {
      const family = await newFamily(t, 'Aziz');
      const { invite, requestId } = await pendingLink(family, w.aziz.id);
      expect((await timetable(t, family.child)).json().code).toBe('NOT_ENROLLED');

      const res = await confirm(t, w.homeroomA, requestId);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ id: requestId, kind: 'REVIEW', status: 'CONFIRMED' });
      expect((await studentRow(w.aziz.id)).childId).toBe(family.child.childId);
      expect((await linkStatus(t, family.child)).json()).toMatchObject({ student: { status: 'CONFIRMED', schoolName: SCHOOL_NAME, className: '7-A' } });
      expect((await timetable(t, family.child)).statusCode).toBe(200);
      expect((await t.prisma.schoolStudentInvite.findUniqueOrThrow({ where: { id: invite.id } })).studentConfirmedAt).not.toBeNull();
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
      expect((await requests(t, w.director)).json()).toEqual([]);
      const audit = await t.prisma.schoolAuditLog.findFirstOrThrow({ where: { action: 'student.childLinked' } });
      expect(audit).toMatchObject({ actorId: w.homeroomA.staffId, module: 'STUDENTS', entityId: w.aziz.id, params: { name: 'Karimov Aziz' } });

      expect((await confirm(t, w.homeroomA, requestId)).json()).toEqual({ id: requestId, kind: 'REVIEW', status: 'CONFIRMED' });
      const late = await reject(t, w.homeroomA, requestId);
      expect([late.statusCode, late.json().code]).toEqual([409, 'REQUEST_STALE']);
      expect((await studentRow(w.aziz.id)).childId).toBe(family.child.childId);
    });

    it('confirm keeps the parent PUT invariants: STUDENT_LINKED_ELSEWHERE, ALREADY_ENROLLED, sibling replacement', async () => {
      const family = await newFamily(t, 'Aziz');
      const rival = await newFamily(t, 'Raqib');
      const { invite, requestId } = await pendingLink(family, w.aziz.id);

      // o'quvchi boshqa OILA farzandiga ulangan (ilova yo'llari buni tozalaydi — qo'lda yaratilgan holat)
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { childId: rival.child.childId } });
      const elsewhere = await confirm(t, w.director, requestId);
      expect([elsewhere.statusCode, elsewhere.json().code]).toEqual([409, 'STUDENT_LINKED_ELSEWHERE']);
      expect((await studentRow(w.aziz.id)).childId).toBe(rival.child.childId);

      // bola boshqa FAOL o'quvchiga ulangan
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { childId: null } });
      await t.prisma.schoolStudent.update({ where: { id: w.bobur.id }, data: { childId: family.child.childId } });
      const enrolled = await confirm(t, w.director, requestId);
      expect([enrolled.statusCode, enrolled.json().code]).toEqual([409, 'ALREADY_ENROLLED']);
      expect((await studentRow(w.aziz.id)).childId).toBeNull();

      // shu oilaning aka-ukasi almashtiriladi
      await t.prisma.schoolStudent.update({ where: { id: w.bobur.id }, data: { childId: null } });
      const sibling = await createChild(t.prisma, family.parent, { name: 'Aka' });
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { childId: sibling.childId } });
      expect((await confirm(t, w.director, requestId)).statusCode).toBe(200);
      expect((await studentRow(w.aziz.id)).childId).toBe(family.child.childId);
    });

    it('reject: frees the student slot (the child is NONE again), clears the notification, audits; the code works for another child', async () => {
      const family = await newFamily(t, 'Aziz');
      const real = await newFamily(t, 'Haqiqiy');
      const { code, invite, requestId } = await pendingLink(family, w.aziz.id);

      const res = await reject(t, w.homeroomA, requestId);

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ id: requestId, kind: 'REVIEW', status: 'REJECTED' });
      expect(await t.prisma.schoolStudentInvite.findUniqueOrThrow({ where: { id: invite.id } })).toMatchObject({ studentChildId: null, studentUsedAt: null, studentConfirmedAt: null });
      expect((await linkStatus(t, family.child)).json()).toEqual({
        student: { status: 'NONE', schoolName: null, className: null },
        parent: { status: 'NONE' },
        expiresAt: null,
      });
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'student.linkRejected' } })).toBe(1);
      expect((await studentRow(w.aziz.id)).childId).toBeNull();
      expect((await requests(t, w.director)).json()).toEqual([]);
      // Ikkinchi rad etish — endi ro'yxatda yo'q
      expect((await reject(t, w.homeroomA, requestId)).statusCode).toBe(404);
      // Kod hali faol bo'lsa haqiqiy bola kirita oladi
      expect((await childLink(t, real.child, code)).json().student.status).toBe('UNDER_REVIEW');
    });

    it('is class-scoped: another homeroom 403, other school 404, unknown id 404, roles without guardians.link 403', async () => {
      const family = await newFamily(t, 'Aziz');
      const { invite, requestId } = await pendingLink(family, w.aziz.id);
      const other = await createSchool(t.prisma, 'other-school');
      const stranger = await staffSession(t, other.school.id, 'ADMIN', 'admin-other');

      for (const action of [confirm, reject]) {
        expect((await action(t, w.homeroomB, requestId)).statusCode).toBe(403);
        expect((await action(t, stranger, requestId)).statusCode).toBe(404);
        expect((await action(t, w.director, randomUUID())).statusCode).toBe(404);
        expect((await action(t, w.director, `${randomUUID()}:${family.child.childId}`)).statusCode).toBe(404);
        expect((await action(t, w.director, 'garbage:')).statusCode).toBe(404);
        for (const who of [w.teacher, w.duty, w.psych]) expect((await action(t, who, requestId)).statusCode).toBe(403);
      }
      expect((await t.prisma.schoolStudentInvite.findUniqueOrThrow({ where: { id: invite.id } })).studentChildId).toBe(family.child.childId);
      expect((await studentRow(w.aziz.id)).childId).toBeNull();
    });

    it('parent PUT confirming the same link settles the request: no stale review, no resurrection after unlink', async () => {
      const family = await newFamily(t, 'Aziz');
      const { invite, requestId } = await pendingLink(family, w.aziz.id);
      const guardian = await linkGuardian(t, w.schoolId, w.aziz.id, family.parent);

      const put = await appReq(t, family.parent.token, 'PUT', `/parent/school/students/${w.aziz.id}/child`, { childId: family.child.childId });

      expect(put.statusCode).toBe(200);
      expect((await t.prisma.schoolStudentInvite.findUniqueOrThrow({ where: { id: invite.id } })).studentConfirmedAt).not.toBeNull();
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
      expect((await requests(t, w.director)).json()).toEqual([]);
      expect((await linkStatus(t, family.child)).json().student.status).toBe('CONFIRMED');

      expect((await appReq(t, family.parent.token, 'DELETE', `/parent/school/links/${guardian.id}`)).statusCode).toBe(204);
      expect((await linkStatus(t, family.child)).json().student.status).toBe('NONE');
      expect((await requests(t, w.director)).json()).toEqual([]);
    });

    it('a pending request of another child at the same student is dropped when the parent confirms their own child', async () => {
      const guesser = await newFamily(t, 'Taxminchi');
      const real = await newFamily(t, 'Haqiqiy');
      const { invite, requestId } = await pendingLink(guesser, w.aziz.id);
      await linkGuardian(t, w.schoolId, w.aziz.id, real.parent);

      await appReq(t, real.parent.token, 'PUT', `/parent/school/students/${w.aziz.id}/child`, { childId: real.child.childId });

      expect(await t.prisma.schoolStudentInvite.findUniqueOrThrow({ where: { id: invite.id } })).toMatchObject({ studentChildId: null });
      expect((await linkStatus(t, guesser.child)).json().student.status).toBe('NONE');
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
    });
  });

  describe('staff notifications', () => {
    const stored = (kind: string) => t.prisma.schoolStaffNotification.findFirstOrThrow({ where: { kind } });
    const ids = (...sessions: Array<{ staffId: string }>) => sessions.map((x) => x.staffId).sort();
    const kinds = async (who: Parameters<typeof feed>[1]) => (await feed(t, who)).json().map((n: { kind: string }) => n.kind);

    it('LINK_REVIEW goes only to staff who can act on it (guardians.link, in scope), with exactly { studentName, className }', async () => {
      const family = await newFamily(t, 'Aziz');
      const { invite, requestId } = await pendingLink(family, w.aziz.id);

      const note = await stored('LINK_REVIEW');
      expect(note.roles).toEqual(['ADMIN', 'DIRECTOR', 'HOMEROOM']);
      expect([...note.staffIds].sort()).toEqual(ids(w.director, w.admin, w.homeroomA));

      const admin = (await feed(t, w.admin)).json();
      expect(admin).toEqual([
        {
          id: `link-review:${invite.id}`,
          kind: 'LINK_REVIEW',
          at: expect.any(String),
          tone: 'warning',
          params: { studentName: 'Karimov Aziz', className: '7-A' },
          subject: null,
          href: '/students/link-requests',
        },
      ]);
      expect(await kinds(w.director)).toEqual(['LINK_REVIEW']);
      expect(await kinds(w.homeroomA)).toEqual(['LINK_REVIEW']);
      // Boshqa sinf rahbari va ruxsatsiz rollar (o'qituvchi, navbatchi, psixolog) ko'rmaydi
      for (const who of [w.homeroomB, w.teacher, w.duty, w.psych]) expect(await kinds(who)).toEqual([]);
      expect(JSON.stringify(admin)).not.toContain('"Aziz"'); // bola ismi yo'q (faqat o'quvchi: "Karimov Aziz")

      await confirm(t, w.admin, requestId);
      expect((await feed(t, w.admin)).json()).toEqual([]);
    });

    it('a homeroom WITH the permission is notified for its class; WITHOUT the permission it is not, even though the class is in scope', async () => {
      const first = await newFamily(t, 'Aziz');
      await pendingLink(first, w.aziz.id);
      const withPermission = await stored('LINK_REVIEW');
      expect(withPermission.staffIds).toContain(w.homeroomA.staffId);
      expect(await kinds(w.homeroomA)).toEqual(['LINK_REVIEW']);

      const restore = withoutPermission(['HOMEROOM']);
      try {
        const second = await newFamily(t, 'Bobur');
        await pendingLink(second, w.bobur.id);

        const bobur = await t.prisma.schoolStaffNotification.findFirstOrThrow({
          where: { kind: 'LINK_REVIEW', params: { path: ['studentName'], equals: 'Rahimov Bobur' } },
        });
        expect(bobur.roles).toEqual(['ADMIN', 'DIRECTOR']);
        expect([...bobur.staffIds].sort()).toEqual(ids(w.director, w.admin));
        expect(bobur.staffIds).not.toContain(w.homeroomA.staffId);
        // Endpointlar ham unga yopiq: bildirishnoma faqat hal qila oladiganlarga boradi
        expect((await requests(t, w.homeroomA)).statusCode).toBe(403);
        expect(await kinds(w.admin)).toEqual(['LINK_REVIEW', 'LINK_REVIEW']);
      } finally {
        restore();
      }
    });

    it('nobody holds the permission in scope: the directors are notified', async () => {
      const family = await newFamily(t, 'Aziz');
      const code = await issueCode(t, w.director, w.aziz.id); // kod xodim ruxsati bilan yaratiladi, keyin jadvaldan olib tashlanadi
      const restore = withoutPermission(['DIRECTOR', 'ADMIN', 'HOMEROOM']);
      try {
        expect((await childLink(t, family.child, code)).json().student.status).toBe('UNDER_REVIEW');

        const note = await stored('LINK_REVIEW');
        expect(note.roles).toEqual(['DIRECTOR']);
        expect(note.staffIds).toEqual([w.director.staffId]);
        expect(await kinds(w.director)).toEqual(['LINK_REVIEW']);
        for (const who of [w.admin, w.homeroomA, w.homeroomB, w.teacher, w.duty, w.psych]) expect(await kinds(who)).toEqual([]);
      } finally {
        restore();
      }
    });

    it('inactive staff and staff of other schools are never notified', async () => {
      await t.prisma.schoolStaff.update({ where: { id: w.admin.staffId }, data: { active: false } });
      const other = await createSchool(t.prisma, 'other-school');
      const strangerAdmin = await staffSession(t, other.school.id, 'ADMIN', 'admin-other');
      const family = await newFamily(t, 'Aziz');
      await pendingLink(family, w.aziz.id);

      const note = await stored('LINK_REVIEW');

      expect([...note.staffIds].sort()).toEqual(ids(w.director, w.homeroomA));
      expect(note.staffIds).not.toContain(w.admin.staffId);
      expect(note.staffIds).not.toContain(strangerAdmin.staffId);
      expect(await kinds(strangerAdmin)).toEqual([]);
    });

    it('a student without a class: only school-wide handlers (director, admin), never a homeroom', async () => {
      await t.prisma.schoolStudent.update({ where: { id: w.aziz.id }, data: { classId: null } });
      const family = await newFamily(t, 'Aziz');
      await pendingLink(family, w.aziz.id);

      const note = await stored('LINK_REVIEW');
      expect(note.roles).toEqual(['ADMIN', 'DIRECTOR']);
      expect(note.classIds).toEqual([]);
      expect((await feed(t, w.admin)).json()[0]).toMatchObject({ kind: 'LINK_REVIEW', params: { studentName: 'Karimov Aziz', className: '' } });
      expect(await kinds(w.director)).toEqual(['LINK_REVIEW']);
      expect(await kinds(w.homeroomA)).toEqual([]);
      expect(await kinds(w.homeroomB)).toEqual([]);
    });

    it('no notification is stored when there is no active staff to receive it (the request itself is kept)', async () => {
      const family = await newFamily(t, 'Aziz');
      const code = await issueCode(t, w.director, w.aziz.id);
      await t.prisma.schoolStaff.updateMany({ where: { schoolId: w.schoolId }, data: { active: false } });

      const res = await childLink(t, family.child, code);

      expect(res.statusCode).toBe(200);
      expect(res.json().student.status).toBe('UNDER_REVIEW');
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_REVIEW' } })).toBe(0);
      expect((await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId: w.aziz.id } })).studentChildId).toBe(family.child.childId);
    });

    it('LINK_CORRECTION follows the same rule: a homeroom without the permission is not notified', async () => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      const restore = withoutPermission(['HOMEROOM']);
      try {
        await correction(family);

        const note = await stored('LINK_CORRECTION');
        expect(note.roles).toEqual(['ADMIN', 'DIRECTOR']);
        expect([...note.staffIds].sort()).toEqual(ids(w.director, w.admin));
        expect(await kinds(w.homeroomA)).toEqual([]);
        expect(await kinds(w.director)).toEqual(['LINK_CORRECTION']);
      } finally {
        restore();
      }
    });
  });

  describe('child correction (A08)', () => {
    it('needs a confirmed link: NONE and UNDER_REVIEW children get 404 NOT_ENROLLED', async () => {
      const none = await newFamily(t, 'Yolg\'iz');
      const waiting = await newFamily(t, 'Kutayotgan');
      await pendingLink(waiting, w.aziz.id);

      for (const kid of [none, waiting]) {
        const res = await correction(kid);
        expect([res.statusCode, res.json().code]).toEqual([404, 'NOT_ENROLLED']);
      }
      expect(await t.prisma.schoolLinkCorrection.count()).toBe(0);
    });

    it('opens the request (idempotent), closes school data everywhere, notifies staff', async () => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      expect((await timetable(t, family.child)).statusCode).toBe(200);
      const requestId = randomUUID();

      const res = await correction(family, { clientRequestId: requestId, note: '  Boshqa maktabdanman  ' });

      expect(res.statusCode).toBe(201);
      const { id } = res.json();
      expect(res.json()).toEqual({ id, status: 'OPEN' });
      expect(await t.prisma.schoolLinkCorrection.findUniqueOrThrow({ where: { id } })).toMatchObject({
        childId: family.child.childId,
        studentId: w.aziz.id,
        schoolId: w.schoolId,
        reason: 'WRONG_SCHOOL_OR_CLASS',
        note: 'Boshqa maktabdanman',
        status: 'OPEN',
      });

      // Takroriy yuborish va yangi `clientRequestId` bilan ikkinchi so'rov — o'sha ochiq so'rov
      expect((await correction(family, { clientRequestId: requestId })).json()).toEqual({ id, status: 'OPEN' });
      expect((await correction(family)).json()).toEqual({ id, status: 'OPEN' });
      expect(await t.prisma.schoolLinkCorrection.count()).toBe(1);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_CORRECTION' } })).toBe(1);

      // Bola: CORRECTION, nomlarsiz; maktab ma'lumoti yopiq
      expect((await linkStatus(t, family.child)).json()).toEqual({
        student: { status: 'CORRECTION', schoolName: null, className: null },
        parent: { status: 'CONFIRMED' },
        expiresAt: null,
      });
      const closed = await timetable(t, family.child);
      expect([closed.statusCode, closed.json().code]).toEqual([404, 'UNDER_REVIEW']);
      expect((await appReq(t, family.child.token, 'GET', '/child/school/announcements')).json().code).toBe('UNDER_REVIEW');
      expect((await appReq(t, family.child.token, 'GET', '/child/school/today')).json()).toEqual({ today: null });
      expect((await appReq(t, family.child.token, 'GET', '/child/school/assignments')).json()).toEqual([]);
      expect((await appReq(t, family.child.token, 'GET', '/child/school/assessments')).json()).toMatchObject({ enrolled: false });
      expect((await appReq(t, family.child.token, 'GET', '/child/school/care/contact')).json().code).toBe('UNDER_REVIEW');
      // Xodim bildirishnomasi: faqat { studentName, className }
      const note = await t.prisma.schoolStaffNotification.findFirstOrThrow({ where: { kind: 'LINK_CORRECTION' } });
      expect(note).toMatchObject({ id: `link-correction:${id}`, roles: ['ADMIN', 'DIRECTOR', 'HOMEROOM'], classIds: [w.classA], params: { studentName: 'Karimov Aziz', className: '7-A' } });
      expect([...note.staffIds].sort()).toEqual([w.director.staffId, w.admin.staffId, w.homeroomA.staffId].sort());
      expect(JSON.stringify(note.params)).not.toContain('Boshqa maktabdanman');
      expect((await feed(t, w.homeroomA)).json()[0]).toMatchObject({ kind: 'LINK_CORRECTION', tone: 'warning', href: '/students/link-requests', params: { studentName: 'Karimov Aziz', className: '7-A' } });
      expect(note.href).toBe('/students/link-requests');
      expect((await feed(t, w.homeroomB)).json()).toEqual([]);
    });

    it('confirm = keep the link (school data reopens); reject = unlink (the child can link again)', async () => {
      const kept = await newFamily(t, 'Aziz');
      const dropped = await newFamily(t, 'Bobur');
      await confirmedLink(t, w.director, w.aziz, kept);
      await confirmedLink(t, w.director, w.bobur, dropped);
      const keptId = (await correction(kept)).json().id as string;
      const droppedId = (await correction(dropped)).json().id as string;

      const keep = await confirm(t, w.homeroomA, keptId);
      expect(keep.json()).toEqual({ id: keptId, kind: 'CORRECTION', status: 'CONFIRMED' });
      expect((await studentRow(w.aziz.id)).childId).toBe(kept.child.childId);
      expect((await timetable(t, kept.child)).statusCode).toBe(200);
      expect((await linkStatus(t, kept.child)).json().student.status).toBe('CONFIRMED');
      expect(await t.prisma.schoolLinkCorrection.findUniqueOrThrow({ where: { id: keptId } })).toMatchObject({ status: 'CONFIRMED', resolvedByStaffId: w.homeroomA.staffId });
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'student.linkCorrectionKept' } })).toBe(1);

      const drop = await reject(t, w.homeroomA, droppedId);
      expect(drop.json()).toEqual({ id: droppedId, kind: 'CORRECTION', status: 'REJECTED' });
      expect((await studentRow(w.bobur.id)).childId).toBeNull();
      expect((await linkStatus(t, dropped.child)).json()).toEqual({
        student: { status: 'NONE', schoolName: null, className: null },
        parent: { status: 'NONE' },
        expiresAt: null,
      });
      expect((await timetable(t, dropped.child)).json().code).toBe('NOT_ENROLLED');
      expect(await t.prisma.schoolStudentInvite.count({ where: { studentChildId: dropped.child.childId } })).toBe(0);
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'student.childUnlinked' } })).toBe(1);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_CORRECTION' } })).toBe(0);
      expect((await requests(t, w.director)).json()).toEqual([]);

      // Idempotent takror / qarama-qarshi qaror
      expect((await confirm(t, w.homeroomA, keptId)).json().status).toBe('CONFIRMED');
      expect((await reject(t, w.homeroomA, keptId)).json().code).toBe('REQUEST_STALE');
      // Uzilgan bola boshqa (to'g'ri) o'quvchi kodini kirita oladi
      const right = await issueCode(t, w.director, w.sardor.id);
      expect((await childLink(t, dropped.child, right)).json().student.status).toBe('UNDER_REVIEW');
    });

    it('is class-scoped for staff (another homeroom 403) and cancelled when the child is re-linked elsewhere by the parent', async () => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      const id = (await correction(family)).json().id as string;
      expect((await confirm(t, w.homeroomB, id)).statusCode).toBe(403);
      expect((await reject(t, w.homeroomB, id)).statusCode).toBe(403);
      expect((await studentRow(w.aziz.id)).childId).toBe(family.child.childId);

      // Ota-ona bolani boshqa o'quvchiga (to'g'ri sinf) ko'chiradi — eski so'rov ma'nosiz (CANCELLED), ma'lumot ochiladi
      await linkGuardian(t, w.schoolId, w.bobur.id, family.parent);
      const moved = await appReq(t, family.parent.token, 'PUT', `/parent/school/students/${w.bobur.id}/child`, { childId: family.child.childId });
      expect(moved.statusCode).toBe(200);
      expect(await t.prisma.schoolLinkCorrection.findUniqueOrThrow({ where: { id } })).toMatchObject({ status: 'CANCELLED' });
      expect((await studentRow(w.aziz.id)).childId).toBeNull();
      expect((await linkStatus(t, family.child)).json().student.status).toBe('CONFIRMED');
      expect((await timetable(t, family.child)).statusCode).toBe(200);
      expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_CORRECTION' } })).toBe(0);
    });

    it('validates the body: reason, note (<= 300), clientRequestId (uuid); child token only', async () => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      const cases: Array<[Record<string, unknown>, string]> = [
        [{ reason: 'OTHER' }, 'reason'],
        [{ reason: undefined }, 'reason'],
        [{ note: 'x'.repeat(301) }, 'note'],
        [{ clientRequestId: undefined }, 'clientRequestId'],
        [{ clientRequestId: 'not-a-uuid' }, 'clientRequestId'],
      ];
      for (const [over, field] of cases) {
        const res = await correction(family, over);
        expect([res.statusCode, res.json().code]).toEqual([400, 'VALIDATION']);
        expect(res.json().message).toContain(`${field}:`);
      }
      expect((await correction(family, { note: 'x'.repeat(300) })).statusCode).toBe(201);
      expect((await appReq(t, family.parent.token, 'POST', '/child/school/correction', { reason: 'WRONG_SCHOOL_OR_CLASS', clientRequestId: randomUUID() })).statusCode).toBe(403);
      expect(await t.prisma.schoolLinkCorrection.count()).toBe(1);
    });

    it('caps new correction requests at 5 per child per day', async () => {
      const family = await newFamily(t, 'Aziz');
      await confirmedLink(t, w.director, w.aziz, family);
      for (let i = 0; i < 5; i += 1) {
        const created = await correction(family);
        expect(created.statusCode).toBe(201);
        expect((await confirm(t, w.director, created.json().id)).statusCode).toBe(200);
      }

      const sixth = await correction(family);

      expect(sixth.statusCode).toBe(429);
      expect(sixth.json().code).toBe('TOO_MANY_REQUESTS');
      expect(await t.prisma.schoolLinkCorrection.count()).toBe(5);
      // Takroriy (eski) `clientRequestId` limitga tegmaydi
      const old = await t.prisma.schoolLinkCorrection.findFirstOrThrow({ orderBy: { createdAt: 'asc' } });
      expect((await correction(family, { clientRequestId: old.clientRequestId })).statusCode).toBe(201);
    });
  });

  describe('invite lifecycle with a confirmed link', () => {
    it('the parent redeeming after staff confirmation marks the parent slot without changing the link', async () => {
      const family = await newFamily(t, 'Aziz');
      const { code, invite, requestId } = await pendingLink(family, w.aziz.id);
      await confirm(t, w.director, requestId);

      expect((await parentLink(t, family.parent, code)).statusCode).toBe(200);

      expect((await studentRow(w.aziz.id)).childId).toBe(family.child.childId);
      expect(await t.prisma.schoolStudentInvite.findUniqueOrThrow({ where: { id: invite.id } })).toMatchObject({
        parentUserId: family.parent.userId,
        studentConfirmedAt: expect.any(Date),
        closedAt: expect.any(Date),
      });
    });
  });
});

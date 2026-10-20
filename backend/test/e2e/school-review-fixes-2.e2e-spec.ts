// Ikkinchi xavfsizlik ko'rigi tuzatishlari — regressiya testlari: himoyalangan
// rollar, so'rov hajmi, Growth K=5, ota-ona uzish doirasi, test natijalari
// doirasi, faol tayinlash himoyasi, erta ketish lentasi, natija unikalligi.

import { LearningSubject } from '@prisma/client';
import type { LightMyRequestResponse } from 'fastify';
import { addDays, isoWeekday, tashkentDay } from '../../src/common/time/tashkent';
import { AssessmentsChildService } from '../../src/school/assessments/assessments-child.service';
import { resetDb } from './db';
import { createChild, createParent } from './factories';
import { buildWorld, childApi, L, publishedAssignment, sampleInput, Staff, staffApi } from './school-assessments-fixtures';
import { seedWorld, Session } from './school-attendance-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createClass, createStudent } from './school-students-fixtures';
import { seedQuestionBank } from './learning-fixtures';
import { createTestApp, TestApp } from './test-app';

const MB = 1024 * 1024;
const ALL_A = { q1: 'a', q2: 'b', q3: 'a', q4: 'b' };

describe('School security review fixes (2)', () => {
  let t: TestApp;

  const as = (who: { token: string }, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) =>
    t.app.inject({ method, url: `/api${url}`, headers: { authorization: `Bearer ${who.token}` }, ...(payload && { payload }) });

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
  });

  afterAll(() => t.close());

  it('HIGH 1: direktor psixolog hisobini yarata, unga ko\'tara yoki egallay olmaydi; pasaytirish va hisobni o\'chirish mumkin', async () => {
    const w = await seedWorld(t);
    const form = (role: string) => ({ fullName: 'Yangi Xodim', position: 'Mutaxassis', role, phone: '+998 90 111 22 33' });

    const created = await as(w.director, 'POST', '/school/staff', form('PSYCHOLOGIST'));
    expect(created.statusCode).toBe(403);
    expect(created.json().message).toBe('role: protected');
    const teacher = await as(w.director, 'POST', '/school/staff', form('TEACHER'));
    expect(teacher.statusCode).toBeLessThan(300);
    expect((await as(w.director, 'PUT', `/school/staff/${teacher.json().id}`, form('PSYCHOLOGIST'))).statusCode).toBe(403);
    const takeover = await as(w.director, 'PUT', `/school/staff/${w.psych.staffId}/account`, { username: 'psixolog2', password: 'Yangi-parol-2026' });
    expect(takeover.statusCode).toBe(403);
    expect(await t.prisma.schoolStaff.count({ where: { schoolId: w.schoolId, role: 'PSYCHOLOGIST' } })).toBe(1);
    expect((await t.prisma.schoolStaff.findUniqueOrThrow({ where: { id: w.psych.staffId } })).username).toBe('psych');

    // O'z parolini joriy parolsiz almashtirib bo'lmaydi (profil orqali).
    const self = await as(w.director, 'PUT', `/school/staff/${w.director.staffId}/account`, { username: 'direktor', password: 'Boshqa-parol-2026' });
    expect(self.json()).toMatchObject({ statusCode: 409, message: 'self' });

    // Kirishni olib tashlash maxfiylikni buzmaydi — ruxsat etiladi.
    expect((await as(w.director, 'DELETE', `/school/staff/${w.psych.staffId}/account`)).statusCode).toBe(200);
    expect((await as(w.director, 'PUT', `/school/staff/${w.psych.staffId}`, form('DUTY'))).statusCode).toBe(200);
  });

  it('HIGH 1 (poyga): rol tekshiruvi qulflangan qatorda — eskirgan o\'qish psixolog rolini qaytarmaydi', async () => {
    const w = await seedWorld(t);
    const keep = { fullName: 'Psixolog', position: 'Psixolog', role: 'PSYCHOLOGIST', phone: '+998 90 000 00 01' };
    let pending: Promise<LightMyRequestResponse> | undefined;
    await t.prisma.$transaction(
      async (tx) => {
        await tx.$queryRaw`SELECT id FROM school_staff WHERE id = ${w.psych.staffId} FOR UPDATE`;
        pending = as(w.director, 'PUT', `/school/staff/${w.psych.staffId}`, keep);
        await new Promise((resolve) => setTimeout(resolve, 300));
        // Shu orada boshqa so'rovlar: pasaytirish va direktor qo'ygan login.
        await tx.schoolStaff.update({ where: { id: w.psych.staffId }, data: { role: 'DUTY', username: 'egallash' } });
      },
      { timeout: 10_000 },
    );
    expect((await pending!).statusCode).toBe(403);
    expect(await t.prisma.schoolStaff.findUniqueOrThrow({ where: { id: w.psych.staffId } })).toMatchObject({ role: 'DUTY', username: 'egallash' });
  });

  it('MEDIUM 3: 5 MB dan katta JSON — 413 (auth\'dan oldin); ilovalar sync va fayllar o\'z chegarasida', async () => {
    const big = JSON.stringify({ pad: 'x'.repeat(6 * MB) });
    const json = { 'content-type': 'application/json' };
    const login = await t.app.inject({ method: 'POST', url: '/api/school/auth/login', headers: json, payload: big });
    expect(login.statusCode).toBe(413);
    // Bola qurilmasi ikonali ro'yxatni bitta so'rovda yuboradi — endpoint chegarasi kattaroq.
    const apps = await t.app.inject({ method: 'POST', url: '/api/children/x/installed-apps', headers: json, payload: big });
    expect(apps.statusCode).toBe(401);
    const boundary = 'parvoz-e2e';
    const multipart = Buffer.concat([
      Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="video"; filename="v.mp4"\r\nContent-Type: video/mp4\r\n\r\n`),
      Buffer.alloc(6 * MB, 1),
      Buffer.from(`\r\n--${boundary}--\r\n`),
    ]);
    const upload = await t.app.inject({
      method: 'POST',
      url: '/api/video-messages',
      headers: { 'content-type': `multipart/form-data; boundary=${boundary}` },
      payload: multipart,
    });
    expect(upload.statusCode).toBe(401);
  });

  describe('MEDIUM 2: Growth natijalari — faqat ≥5 faol bolali (sinf, hafta) kataklaridan', () => {
    let schoolId: string;
    let classA: string;
    let classB: string;
    let director: LoggedIn;
    const monday = () => addDays(tashkentDay(), 1 - isoWeekday(tashkentDay()));
    /** Natijalar faqat yakunlangan haftalardan — fixture'lar o'tgan haftada. */
    const lastWeek = () => addDays(monday(), -7);

    async function kids(classId: string, n: number, subjects: LearningSubject[], correct: number): Promise<string[]> {
      const ids: string[] = [];
      for (let i = 0; i < n; i++) {
        const parent = await createParent(t.prisma);
        const kid = await createChild(t.prisma, parent);
        const student = await createStudent(t.prisma, schoolId, classId, { childId: kid.childId, firstName: `Bola${i}` });
        await t.prisma.learningProfile.create({ data: { childId: kid.childId, grade: 7, subjects } });
        await t.prisma.learningAttempt.create({
          data: {
            childId: kid.childId, subject: subjects[0]!, day: lastWeek(), isDaily: true, status: 'COMPLETED', questionIds: [], correct, total: 5, donEarned: correct * 2,
            completedAt: new Date(), schoolClassId: classId,
          },
        });
        ids.push(student.id);
      }
      return ids;
    }

    beforeEach(async () => {
      schoolId = (await createSchool(t.prisma)).school.id;
      classA = (await createClass(t.prisma, schoolId, 7, 'A')).id;
      classB = (await createClass(t.prisma, schoolId, 8, 'B')).id;
      director = await login(t.app, 'direktor');
    });

    it('kichik sinf yashiriladi; jami va filtrdan ayirib tiklab bo\'lmaydi; hisobot, bosh sahifa, profil va qiziqishlar ham', async () => {
      const inA = await kids(classA, 5, ['MATH'], 4);
      const inB = await kids(classB, 3, ['ENGLISH'], 1);

      const act = (await as(director, 'GET', '/school/learning/activity')).json();
      const row = (id: string) => act.classes.find((c: { classId: string }) => c.classId === id);
      expect(row(classA)).toMatchObject({ activeStudents: 5, completedTasks: 5, avgScore: 80, donPoints: 40, suppressed: false });
      expect(row(classB)).toMatchObject({ activeStudents: 3, activeRate: 100, completedTasks: null, avgScore: null, donPoints: null, suppressed: true });
      // Jami — faqat ochiq kataklar: jami − 7-A = 0, ya'ni 8-B natijasi tiklanmaydi.
      expect(act.weeks.at(-1)).toMatchObject({ activeStudents: 8, completedTasks: 5, avgScore: 80, donPoints: 40, suppressed: false });
      expect(act.weeks.at(-2)).toMatchObject({ activeStudents: 0, completedTasks: 0, avgScore: null, donPoints: 0, suppressed: false });
      const onlyB = (await as(director, 'GET', `/school/learning/activity?classId=${classB}`)).json();
      expect(onlyB.weeks.at(-1)).toMatchObject({ activeStudents: 3, completedTasks: null, avgScore: null, donPoints: null, suppressed: true });

      expect((await as(director, 'GET', '/school/learning/interests')).json()).toEqual([{ grade: 7, shares: [{ subject: 'MATH', percent: 100 }] }]);

      const report = (await as(director, 'GET', `/school/reports/monthly?month=${lastWeek().slice(0, 7)}`)).json();
      expect(report.learning).toMatchObject({ completedTasks: 5, avgScore: 80, suppressed: false });
      expect(report.learning.weeks).toBeGreaterThanOrEqual(1);

      await createStaff(t.prisma, schoolId, 'HOMEROOM', 'rahbar-b', [classB]);
      const homeroomB = await login(t.app, 'rahbar-b');
      const dash = (await as(homeroomB, 'GET', '/school/dashboard/overview')).json();
      expect(dash.learning).toMatchObject({ activeStudents: 3, totalStudents: 3, completedTasks: null, avgScore: null, suppressed: true });

      await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psixolog');
      const psych = await login(t.app, 'psixolog');
      const context = async (studentId: string) => (await as(psych, 'GET', `/school/development/students/${studentId}/profile`)).json().context.classLearning;
      expect(await context(inB[0]!)).toEqual({ activeRate: 100, avgScore: null, suppressed: true });
      expect(await context(inA[0]!)).toEqual({ activeRate: 100, avgScore: 80, suppressed: false });
    });
    it('snapshot: ko\'chirish o\'tgan kataklarni o\'zgartirmaydi; bog\'lashdan oldingi urinish ko\'rinmaydi', async () => {
      await kids(classA, 5, ['MATH'], 4);
      const inB = await kids(classB, 3, ['ENGLISH'], 1);
      const moved = (await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: inB[0]! } })).childId!;
      await t.prisma.learningAttempt.create({
        data: { childId: moved, subject: 'MATH', day: lastWeek(), isDaily: false, status: 'COMPLETED', questionIds: [], correct: 5, total: 5, completedAt: new Date() },
      });
      // 8-B dagi bolani 7-A ga ko'chirib, 7-A farqidan uning natijasini bilib bo'lmaydi.
      await t.prisma.schoolStudent.update({ where: { id: inB[0]! }, data: { classId: classA } });
      const act = (await as(director, 'GET', '/school/learning/activity')).json();
      const row = (id: string) => act.classes.find((c: { classId: string }) => c.classId === id);
      expect(row(classA)).toMatchObject({ size: 6, activeStudents: 5, activeRate: 83, completedTasks: 5, avgScore: 80, suppressed: false });
      expect(row(classB)).toMatchObject({ size: 2, activeStudents: 3, activeRate: 100, completedTasks: null, suppressed: true });
    });

    it('davom etayotgan hafta: natijalar chiqmaydi — yangi urinish e\'lon qilingan raqamlarni o\'zgartirmaydi', async () => {
      await kids(classA, 5, ['MATH'], 4);
      const parent = await createParent(t.prisma);
      const late = await createChild(t.prisma, parent);
      await createStudent(t.prisma, schoolId, classA, { childId: late.childId });
      const read = async () => (await as(director, 'GET', '/school/learning/activity')).json();
      const before = await read();
      expect(before.current).toEqual({ weekStart: monday(), activeStudents: 0 });

      await t.prisma.learningAttempt.create({
        data: { childId: late.childId, subject: 'MATH', day: monday(), isDaily: true, status: 'COMPLETED', questionIds: [], correct: 5, total: 5, donEarned: 20, completedAt: new Date(), schoolClassId: classA },
      });
      const after = await read();
      expect(after.current.activeStudents).toBe(1);
      expect([after.latestWeek, after.weeks, after.classes]).toEqual([before.latestWeek, before.weeks, before.classes]);
      const dash = (await as(director, 'GET', '/school/dashboard/overview')).json().learning;
      expect(dash).toMatchObject({ weekStart: lastWeek(), activeStudents: 5, completedTasks: 5, avgScore: 80 });
    });

    it('o\'tgan haftada boshlanib, shu hafta yakunlangan urinish yopilgan haftani o\'zgartirmaydi (snapshot\'siz)', async () => {
      const parent = await createParent(t.prisma);
      const kid = await createChild(t.prisma, parent);
      await createStudent(t.prisma, schoolId, classA, { childId: kid.childId });
      const finish = async (day: string) => {
        const a = await t.prisma.learningAttempt.create({ data: { childId: kid.childId, subject: 'MATH', day, isDaily: false, questionIds: [], total: 0 } });
        expect((await as(kid, 'POST', `/learning/attempts/${a.id}/complete`)).statusCode).toBeLessThan(300);
        return (await t.prisma.learningAttempt.findUniqueOrThrow({ where: { id: a.id } })).schoolClassId;
      };
      expect(await finish(addDays(monday(), -1))).toBeNull();
      expect(await finish(tashkentDay())).toBe(classA);
    });

    it('yakunlash: urinish o\'sha paytdagi faol sinfni saqlaydi (bog\'lanmagan / arxivlangan — yo\'q)', async () => {
      await seedQuestionBank(t.prisma);
      const parent = await createParent(t.prisma);
      const [linked, loner, archived] = [await createChild(t.prisma, parent), await createChild(t.prisma, parent), await createChild(t.prisma, parent)];
      await createStudent(t.prisma, schoolId, classA, { childId: linked.childId });
      const gone = await createStudent(t.prisma, schoolId, classA, { childId: archived.childId });
      await t.prisma.schoolStudent.update({ where: { id: gone.id }, data: { archived: true } });
      const complete = async (kid: { token: string }) => {
        await as(kid, 'PUT', '/learning/profile', { grade: 7, subjects: ['math'] });
        const started = (await as(kid, 'POST', '/learning/attempts', { subject: 'math' })).json();
        for (const q of started.questions as Array<{ id: string }>) await as(kid, 'POST', `/learning/attempts/${started.id}/answers`, { questionId: q.id, selectedIndex: 0 });
        expect((await as(kid, 'POST', `/learning/attempts/${started.id}/complete`)).statusCode).toBeLessThan(300);
        return (await t.prisma.learningAttempt.findUniqueOrThrow({ where: { id: started.id } })).schoolClassId;
      };
      expect(await complete(linked)).toBe(classA);
      expect(await complete(loner)).toBeNull();
      expect(await complete(archived)).toBeNull();
    });
  });

  it('LOW 4: sinf rahbari boshqa sinfda ham farzandi bor ota-onani uza olmaydi', async () => {
    const w = await seedWorld(t);
    await t.prisma.schoolStudentGuardian.create({ data: { guardianId: w.guardianId, studentId: w.bek } });
    const unlink = (s: Session) => as(s, 'POST', `/school/guardians/${w.guardianId}/unlink`);

    expect((await unlink(w.homeroom)).statusCode).toBe(403);
    expect((await t.prisma.schoolGuardian.findUniqueOrThrow({ where: { id: w.guardianId } })).linkStatus).toBe('LINKED');
    const res = await unlink(w.admin);
    expect(res.statusCode).toBeLessThan(300);
    expect(res.json().linkStatus).toBe('NOT_INVITED');
  });

  it('LOW 5: test natijalari — o\'quvchining bugungi sinfi; boshqa sinfga o\'tgan yoki arxivlangan eski rahbarga ko\'rinmaydi', async () => {
    const w = await buildWorld(t);
    const api = staffApi(t);
    const test = (await api(w.psych, 'POST', '/tests', sampleInput())).json();
    await api(w.psych, 'POST', `/tests/${test.id}/publish`);
    for (const kid of w.kids7a) {
      await t.prisma.schoolPsychResult.create({
        data: { schoolId: w.schoolId, studentId: kid.studentId, classId: w.classes.c7a, grade: 7, ageBand: 'A13_14', testId: test.id, version: 1, takenAt: new Date(), origin: 'APP', raw: { total: 3 } },
      });
    }
    const [moved, archived, stays] = w.kids7a;
    await t.prisma.schoolStudent.update({ where: { id: moved!.studentId }, data: { classId: w.classes.c7b } });
    await t.prisma.schoolStudent.update({ where: { id: archived!.studentId }, data: { archived: true } });
    const ids = async (who: Staff, query = '') =>
      ((await api(who, 'GET', `/tests/${test.id}/results${query}`)).json().rows as Array<{ studentId: string }>).map((r) => r.studentId).sort();

    expect(await ids(w.homeroom)).toEqual([stays!.studentId]);
    expect(await ids(w.psych, `?classId=${w.classes.c7b}`)).toEqual([moved!.studentId]);
    expect(await ids(w.psych)).toEqual([moved!.studentId, stays!.studentId].sort());
    const res = (await api(w.psych, 'GET', `/tests/${test.id}/results?classId=${w.classes.c7a}`)).json();
    expect(res.participation).toEqual({ invited: 1, completed: 1 });
  });

  it('LOW 6: faol tayinlashda savol / shkala o\'zgarmaydi va test arxivlanmaydi (409); muddat o\'tgach yoki yopilgach — mumkin', async () => {
    const w = await buildWorld(t);
    const api = staffApi(t);
    const { testId, assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    const fewer = sampleInput({ items: sampleInput().items.slice(0, 3) });

    const blocked = await api(w.psych, 'PUT', `/tests/${testId}`, fewer);
    expect(blocked.statusCode).toBe(409);
    expect(blocked.json()).toMatchObject({ code: 'CONFLICT', message: 'assessments.validation.openAssignments' });
    expect((await api(w.psych, 'POST', `/tests/${testId}/archive`)).json()).toMatchObject({ code: 'CONFLICT', message: 'assessments.validation.openAssignments' });
    expect((await api(w.psych, 'PUT', `/tests/${testId}`, sampleInput({ title: L('Yangi nom') }))).json()).toMatchObject({ version: 1 });

    // Muddat (+ qo'shimcha vaqt) o'tgan, lekin hali OPEN — endi bola yubora olmaydi.
    await t.prisma.schoolPsychAssignment.update({ where: { id: assignment.id }, data: { closesAt: new Date(Date.now() - 2 * 3_600_000) } });
    expect((await api(w.psych, 'PUT', `/tests/${testId}`, fewer)).json()).toMatchObject({ version: 2 });

    // Vaqt chegarasini ham o'zgartirib bo'lmaydi: qisqartirib keyingi tahrirda tekshiruvni chetlab o'tmasin.
    const live = await publishedAssignment(t, w, [w.classes.c7a]);
    expect((await api(w.psych, 'PUT', `/tests/${live.testId}`, sampleInput({ timeLimitMin: 1 }))).json()).toMatchObject({ code: 'CONFLICT', message: 'assessments.validation.openAssignments' });
    expect((await api(w.psych, 'PUT', `/tests/${live.testId}`, sampleInput({ title: L('Faqat nom') }))).statusCode).toBe(200);

    const second = await publishedAssignment(t, w, [w.classes.c7b]);
    expect((await api(w.psych, 'POST', `/tests/${second.testId}/archive`)).statusCode).toBe(409);
    expect((await api(w.psych, 'POST', `/assignments/${second.assignment.id}/close`)).statusCode).toBeLessThan(300);
    expect((await api(w.psych, 'POST', `/tests/${second.testId}/archive`)).json()).toMatchObject({ status: 'ARCHIVED' });
  });

  it('LOW 7: erta ketish lentasi — tarix ruxsatisiz faqat bugungi; sabab faqat `attendance.earlyExit` egasiga', async () => {
    const w = await seedWorld(t);
    const today = tashkentDay();
    const base = { schoolId: w.schoolId, studentId: w.vali, classId: w.classA, time: '11:00', pickupBy: 'Onasi', status: 'PENDING' as const };
    const fresh = await t.prisma.schoolEarlyExit.create({ data: { ...base, date: today, reason: 'Tish shifokori', requestedAt: new Date(Date.now() - 60_000) } });
    const old = await t.prisma.schoolEarlyExit.create({ data: { ...base, date: addDays(today, -3), reason: 'Oilaviy sabab', requestedAt: new Date(Date.now() - 3 * 86_400_000) } });
    const exits = async (who: Session) =>
      ((await as(who, 'GET', '/school/notifications/feed')).json() as Array<{ id: string; kind: string; subject: { uz: string } | null }>).filter(
        (n) => n.kind === 'EARLY_EXIT_PENDING',
      );

    const duty = await exits(w.duty);
    expect(duty.map((n) => n.id)).toEqual([`exit:${fresh.id}`]);
    expect(duty[0]!.subject).toBeNull();
    const director = await exits(w.director);
    expect(director.map((n) => n.id).sort()).toEqual([`exit:${fresh.id}`, `exit:${old.id}`].sort());
    expect(director.every((n) => n.subject === null)).toBe(true);
    const homeroom = await exits(w.homeroom);
    expect(homeroom.find((n) => n.id === `exit:${old.id}`)?.subject?.uz).toBe('Oilaviy sabab');
  });

  it('LOW 8: bitta tayinlash — o\'quvchiga bitta natija (DB unikal indeksi); tayinlashsiz (CSV) natijalar cheklanmaydi', async () => {
    const w = await buildWorld(t);
    const kid = w.kids7a[0]!;
    const row = (assignmentId: string | null) => ({
      schoolId: w.schoolId, studentId: kid.studentId, classId: w.classes.c7a, grade: 7, ageBand: 'A13_14', testId: 'tpl-logic', version: 1, assignmentId, takenAt: new Date(), origin: 'IMPORT', raw: {},
    });
    await t.prisma.schoolPsychResult.create({ data: row('pa-e2e') });
    await expect(t.prisma.schoolPsychResult.create({ data: row('pa-e2e') })).rejects.toMatchObject({ code: 'P2002' });
    await t.prisma.schoolPsychResult.createMany({ data: [row(null), row(null)] });
    expect(await t.prisma.schoolPsychResult.count({ where: { studentId: kid.studentId } })).toBe(3);

    // Qulfdan tashqari takror (masalan, "yuborilganmi" tekshiruvi chetlansa) — 409, 500 emas.
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    const child = childApi(t);
    expect((await child(kid, 'POST', `/${assignment.id}/submit`, { answers: ALL_A })).statusCode).toBeLessThan(300);
    const spy = jest.spyOn(AssessmentsChildService.prototype as unknown as { submitted: () => Promise<boolean> }, 'submitted').mockResolvedValue(false);
    try {
      const again = await child(kid, 'POST', `/${assignment.id}/submit`, { answers: ALL_A });
      expect(again.statusCode).toBe(409);
      expect(again.json().code).toBe('ALREADY_SUBMITTED');
    } finally {
      spy.mockRestore();
    }
  });
});

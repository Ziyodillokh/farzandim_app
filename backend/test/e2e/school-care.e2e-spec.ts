// Bola ovozi: savollar banki, so'rovnoma (psixolog) → bola ilovasida javob
// (shifrlangan, bir marta) → anonim natija (direktor, K=5); murojaatlar
// (faqat psixolog), himoya protokoli — auditda shaxsiy ma'lumot yo'q.

import { createChild, createParent, TestChild } from './factories';
import { resetDb } from './db';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createClass, createStudent } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School care (Bola ovozi)', () => {
  let t: TestApp;
  let schoolId: string;
  let classA: string;
  let director: LoggedIn;
  let psych: LoggedIn;

  const staff = (who: LoggedIn, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: unknown) =>
    t.app.inject({ method, url: `/api/school/care${url}`, payload: payload as object, headers: { authorization: `Bearer ${who.token}` } });
  const child = (kid: TestChild, method: 'GET' | 'POST', url: string, payload?: unknown) =>
    t.app.inject({ method, url: `/api/child/school/care${url}`, payload: payload as object, headers: { authorization: `Bearer ${kid.token}` } });

  async function enrolledKids(classId: string, n: number): Promise<TestChild[]> {
    const parent = await createParent(t.prisma);
    const kids: TestChild[] = [];
    for (let i = 0; i < n; i++) {
      const kid = await createChild(t.prisma, parent, { name: `Bola ${i}` });
      await createStudent(t.prisma, schoolId, classId, { firstName: `Bola${i}`, childId: kid.childId });
      kids.push(kid);
    }
    return kids;
  }

  async function activeSurvey(): Promise<{ id: string; questionIds: string[] }> {
    const questions = (await staff(psych, 'GET', '/questions')).json();
    const ids = questions.filter((q: { ageGroups: string[] }) => q.ageGroups.includes('G5_8')).slice(0, 4).map((q: { id: string }) => q.id);
    const survey = (await staff(psych, 'POST', '/surveys', { title: 'Haftalik so\'rovnoma', weekStart: '2026-10-19', ageGroups: ['G5_8'], questionIds: ids })).json();
    await staff(psych, 'POST', `/surveys/${survey.id}/activate`);
    return { id: survey.id, questionIds: ids };
  }

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    schoolId = (await createSchool(t.prisma)).school.id;
    classA = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    await createStaff(t.prisma, schoolId, 'PSYCHOLOGIST', 'psixolog');
    director = await login(t.app, 'direktor');
    psych = await login(t.app, 'psixolog');
  });

  afterAll(() => t.close());

  it('savollar banki va so\'rovnoma hayot sikli; faqat psixolog boshqaradi', async () => {
    const questions = (await staff(psych, 'GET', '/questions')).json();
    expect(questions).toHaveLength(15);
    expect((await staff(director, 'GET', '/questions')).statusCode).toBe(403);

    const bad = await staff(psych, 'POST', '/surveys', { title: '', weekStart: '2026-10-19', ageGroups: [], questionIds: [] });
    expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: 'title: errors.form.required' });
    const g14Only = questions.find((q: { ageGroups: string[] }) => q.ageGroups.length === 1 && q.ageGroups[0] === 'G1_4');
    expect((await staff(psych, 'POST', '/surveys', { title: 'X', weekStart: '2026-10-19', ageGroups: ['G9_11'], questionIds: [g14Only.id] })).statusCode).toBe(400);

    await enrolledKids(classA, 3);
    const { id } = await activeSurvey();
    const list = (await staff(psych, 'GET', '/surveys')).json();
    expect(list[0]).toMatchObject({ id, status: 'ACTIVE', invited: 3, respondents: 0 });
    expect((await staff(psych, 'PUT', `/surveys/${id}`, { title: 'Y', weekStart: '2026-10-19', ageGroups: ['G5_8'], questionIds: [list[0].questionIds[0]] })).statusCode).toBe(409);
    expect((await staff(psych, 'DELETE', `/questions/${list[0].questionIds[0]}`)).statusCode).toBe(409);
    expect((await staff(psych, 'POST', `/surveys/${id}/close`)).json().status).toBe('CLOSED');
    expect((await staff(psych, 'POST', `/surveys/${id}/close`)).statusCode).toBe(409);
    const audit = await t.prisma.schoolAuditLog.findMany({ where: { module: 'CARE' } });
    expect(audit.map((a) => a.action).sort()).toEqual(['care.survey.activate', 'care.survey.close', 'care.survey.create']);
  });

  it('bola javobi shifrlanadi, bir marta; direktor faqat K ≥ 5 bo\'lsa natijani ko\'radi', async () => {
    const kids = await enrolledKids(classA, 6);
    const survey = await activeSurvey();

    const view = (await child(kids[0]!, 'GET', '/survey')).json();
    expect(view).toMatchObject({ enrolled: true, answered: false, survey: { id: survey.id } });
    expect(view.survey.questions).toHaveLength(4);
    expect(view.survey.questions[0].text).toEqual(expect.any(String));

    const answers = Object.fromEntries(survey.questionIds.map((q) => [q, 4]));
    for (const kid of kids.slice(0, 4)) {
      expect((await child(kid, 'POST', `/survey/${survey.id}/responses`, { answers })).statusCode).toBe(201);
    }
    expect((await child(kids[0]!, 'POST', `/survey/${survey.id}/responses`, { answers })).json().code).toBe('ALREADY_ANSWERED');
    expect((await child(kids[0]!, 'GET', '/survey')).json()).toMatchObject({ survey: null, answered: true });
    expect((await child(kids[5]!, 'POST', `/survey/${survey.id}/responses`, { answers: { [survey.questionIds[0]!]: 9 } })).statusCode).toBe(400);
    const stored = await t.prisma.schoolCareResponse.findFirstOrThrow();
    expect(stored.answersEnc).toMatch(/^v1\./);
    expect(stored.answersEnc).not.toContain(survey.questionIds[0]);

    // 4 respondent — psixologda ham kichik guruh yashirin; direktor faol so'rovnomada faqat ishtirokni ko'radi.
    const hidden = (await staff(psych, 'GET', `/aggregate?surveyId=${survey.id}&breakdown=CLASS`)).json();
    expect(hidden).toMatchObject({ respondents: 4, overall: {}, groups: [{ hidden: true, respondents: 0, topicScores: null }] });
    expect((await staff(director, 'GET', `/aggregate?surveyId=${survey.id}&breakdown=CLASS`)).json()).toMatchObject({ respondents: 4, groups: [] });
    expect((await staff(director, 'GET', '/surveys/options')).json()[0]).toMatchObject({ id: survey.id, ready: false });

    await child(kids[4]!, 'POST', `/survey/${survey.id}/responses`, { answers });
    // Faol so'rovnoma: direktor faqat ishtirokni ko'radi (har yangi javobdagi o'zgarish
    // shu bolani ochib qo'ymasin); psixolog — jonli natijani.
    const live = (await staff(director, 'GET', `/aggregate?surveyId=${survey.id}&breakdown=SCHOOL`)).json();
    expect(live).toMatchObject({ respondents: 5, overall: {}, groups: [] });
    expect((await staff(director, 'GET', '/surveys/options')).json()[0].ready).toBe(false);
    expect(Object.keys((await staff(psych, 'GET', `/aggregate?surveyId=${survey.id}&breakdown=SCHOOL`)).json().overall).length).toBeGreaterThan(0);
    await staff(psych, 'POST', `/surveys/${survey.id}/close`);
    const shown = (await staff(director, 'GET', `/aggregate?breakdown=SCHOOL`)).json();
    expect(shown).toMatchObject({ surveyId: survey.id, respondents: 5, invited: 6, participationRate: 83 });
    expect(shown.groups[0].hidden).toBe(false);
    expect(Object.values(shown.overall).length).toBeGreaterThan(0);
    const ids = (await t.prisma.schoolStudent.findMany()).map((s) => s.id);
    for (const id of ids) expect(JSON.stringify(shown)).not.toContain(id);
    const summaries = (await staff(director, 'GET', '/surveys/summaries')).json();
    expect(summaries[0]).toMatchObject({ questionCount: 4, participation: { respondents: 5, invited: 6, rate: 83 } });
  });

  it('murojaat: matn shifrlangan, faqat psixolog ko\'radi; eslatma, suhbat, himoya protokoli', async () => {
    const [kid] = await enrolledKids(classA, 1);
    await createStaff(t.prisma, schoolId, 'DUTY', 'navbatchi');
    const created = await child(kid!, 'POST', '/requests', { topic: 'BULLYING', message: 'Tanaffusda meni urishdi', urgency: 'URGENT' });
    expect(created.statusCode).toBe(201);
    const stored = await t.prisma.schoolCareRequest.findFirstOrThrow();
    expect(stored.messageEnc).not.toContain('urishdi');

    expect((await staff(director, 'GET', '/requests')).statusCode).toBe(403);
    const list = (await staff(psych, 'GET', '/requests?search=urishdi')).json();
    expect(list.items[0]).toMatchObject({ message: 'Tanaffusda meni urishdi', className: '7-A', urgency: 'URGENT', status: 'NEW' });
    expect(list.counts).toMatchObject({ NEW: 1 });

    const id = list.items[0].id;
    expect((await staff(psych, 'PUT', `/requests/${id}/status`, { status: 'SCHEDULED' })).json().message).toBe('meetingAt: errors.form.required');
    const met = (await staff(psych, 'PUT', `/requests/${id}/meeting`, { meetingAt: '2026-10-21T14:30' })).json();
    expect(met).toMatchObject({ status: 'SCHEDULED', meetingAt: '2026-10-21T09:30:00.000Z' });
    await staff(psych, 'POST', `/requests/${id}/notes`, { text: 'Sinf rahbari bilan gaplashildi' });
    const protocol = (await staff(psych, 'POST', `/requests/${id}/protocol`)).json();
    expect(protocol.protocolActivated).toBe(true);
    expect((await staff(psych, 'POST', `/requests/${id}/protocol`)).statusCode).toBe(409);

    const detail = (await staff(psych, 'GET', `/requests/${id}`)).json();
    expect(detail.notes.map((n: { byName: string }) => n.byName)).toEqual(['PSYCHOLOGIST xodim', 'PSYCHOLOGIST xodim']);
    expect(detail.notified).toEqual([
      { role: 'DIRECTOR', name: 'Karimov Akmal' },
      { role: 'DUTY', name: 'DUTY xodim' },
    ]);
    const signal = await t.prisma.schoolStaffNotification.findFirstOrThrow();
    expect(signal).toMatchObject({ kind: 'SAFETY_SIGNAL', roles: ['DIRECTOR', 'DUTY'], params: {} });
    const audit = await t.prisma.schoolAuditLog.findMany({ where: { module: 'CARE' } });
    expect(audit.every((a) => a.entityId === null)).toBe(true);
    expect(JSON.stringify(audit)).not.toMatch(/urishdi|Bola0|gaplashildi/);

    expect((await child(kid!, 'GET', '/requests')).json()[0]).toMatchObject({ topic: 'BULLYING', status: 'SCHEDULED' });
  });

  it('bola cheklovi va maktabga ulanmagan bola', async () => {
    const [kid] = await enrolledKids(classA, 1);
    for (let i = 0; i < 5; i++) {
      expect((await child(kid!, 'POST', '/requests', { topic: 'OTHER', message: `Xabar ${i}` })).statusCode).toBe(201);
    }
    expect((await child(kid!, 'POST', '/requests', { topic: 'OTHER', message: 'Oltinchi' })).statusCode).toBe(429);

    const parent = await createParent(t.prisma);
    const loner = await createChild(t.prisma, parent);
    expect((await child(loner, 'GET', '/survey')).json()).toEqual({ enrolled: false, survey: null, answered: false });
    expect((await child(loner, 'POST', '/requests', { topic: 'OTHER', message: 'Salom' })).json().code).toBe('NOT_ENROLLED');
  });
});

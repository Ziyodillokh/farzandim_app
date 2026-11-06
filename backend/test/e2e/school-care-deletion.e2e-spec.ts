// Bola ovozi — ma'lumotlarni o'chirish: bola / ota-ona / admin yo'llarida bolaning murojaatlari
// (xabarlar cascade) va so'rovnoma ishtirok belgilari o'chadi; ANONIM javoblar qoladi (o'quvchiga
// bog'lanmagan); o'quvchi qatori va boshqa bolalar ma'lumoti tegilmaydi.

import { consumerToken, createModerator } from './factories';
import { resetDb } from './db';
import { createTestApp, TestApp } from './test-app';
import { activateSurvey, answersOf, AssessWorld, buildWorld, careChild, careStaff, createRequest, Kid } from './school-care-fixtures';

describe('Bola ovozi — ma\'lumotlarni o\'chirish', () => {
  let t: TestApp;
  let w: AssessWorld;
  let child: ReturnType<typeof careChild>;
  let staff: ReturnType<typeof careStaff>;
  let survey: { id: string; questionIds: string[] };

  beforeAll(async () => {
    t = await createTestApp();
    child = careChild(t);
    staff = careStaff(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildWorld(t);
    survey = await activateSurvey(t, w.psych);
  });

  afterAll(() => t.close());

  /** Bola so'rovnomaga javob beradi, shoshilinch murojaat yozadi, psixolog javob beradi. */
  async function fill(kid: Kid) {
    await child(kid, 'POST', `/survey/${survey.id}/responses`, { answers: answersOf(survey.questionIds, 4) });
    const request = await createRequest(t, kid, { urgency: 'URGENT', message: 'Maxfiy murojaat' });
    await staff(w.psych, 'POST', `/requests/${request.id}/messages`, { text: 'Maxfiy javob' });
    await child(kid, 'POST', `/requests/${request.id}/messages`, { text: 'Rahmat' });
    // Murojaatga bog'liq saqlangan xodim bildirishnomasi (javob yozilgach odatda tozalanadi — qo'lda qo'yamiz).
    await t.prisma.schoolStaffNotification.create({
      data: { id: `care:${request.id}`, schoolId: w.schoolId, kind: 'CARE_URGENT', roles: ['PSYCHOLOGIST'], classIds: [], params: { className: '7-A' } },
    });
    return request;
  }

  const counts = async (studentIds: string[]) => ({
    requests: await t.prisma.schoolCareRequest.count({ where: { studentId: { in: studentIds } } }),
    messages: await t.prisma.schoolCareMessage.count({ where: { request: { studentId: { in: studentIds } } } }),
    participation: await t.prisma.schoolCareParticipation.count({ where: { studentId: { in: studentIds } } }),
  });

  async function expectErased(gone: Kid, kept: Kid) {
    expect(await counts([gone.studentId])).toEqual({ requests: 0, messages: 0, participation: 0 });
    expect(await counts([kept.studentId])).toEqual({ requests: 1, messages: 3, participation: 1 });
    // Anonim javoblar qoladi (ikkala bolaniki, kimniki ekani noma'lum); o'quvchi qatori saqlanadi.
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(2);
    expect(await t.prisma.schoolStudent.count({ where: { id: gone.studentId } })).toBe(1);
    // Faqat saqlanib qolgan bolaning murojaati bildirishnomasi qoladi.
    expect(await t.prisma.schoolStaffNotification.count({ where: { id: { startsWith: 'care:' } } })).toBe(1);
  }

  it('bola o\'z akkauntini o\'chiradi (DELETE /users/me)', async () => {
    const [gone, kept] = [w.kids7a[0]!, w.kids7b[0]!];
    await fill(gone);
    await fill(kept);
    expect(await counts([gone.studentId])).toEqual({ requests: 1, messages: 3, participation: 1 });

    const res = await t.app.inject({ method: 'DELETE', url: '/api/users/me', headers: { authorization: `Bearer ${gone.token}` } });

    expect(res.statusCode).toBe(200);
    await expectErased(gone, kept);
  });

  it('ota-ona bola profilini o\'chiradi (DELETE /children/:id)', async () => {
    const [gone, kept] = [w.kids7a[0]!, w.kids7b[0]!];
    await fill(gone);
    await fill(kept);

    const res = await t.app.inject({ method: 'DELETE', url: `/api/children/${gone.childId}`, headers: { authorization: `Bearer ${consumerToken(gone.parentId, 'PARENT')}` } });

    expect(res.statusCode).toBe(200);
    await expectErased(gone, kept);
  });

  it('ota-ona o\'z akkauntini o\'chiradi (barcha bolalari)', async () => {
    const [gone1, gone2, kept] = [w.kids7a[0]!, w.kids7a[1]!, w.kids7b[0]!];
    await fill(gone1);
    await fill(gone2);
    await fill(kept);

    const res = await t.app.inject({ method: 'DELETE', url: '/api/users/me', headers: { authorization: `Bearer ${consumerToken(gone1.parentId, 'PARENT')}` } });

    expect(res.statusCode).toBe(200);
    expect(await counts([gone1.studentId, gone2.studentId])).toEqual({ requests: 0, messages: 0, participation: 0 });
    expect(await counts([kept.studentId])).toEqual({ requests: 1, messages: 3, participation: 1 });
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(3);
  });

  it.each(['PARENT', 'CHILD'] as const)('admin foydalanuvchini butunlay o\'chiradi (%s)', async (kind) => {
    const [gone, kept] = [w.kids7a[0]!, w.kids7b[0]!];
    await fill(gone);
    await fill(kept);
    const moderator = await createModerator(t.prisma, ['manage_users']);
    const id = kind === 'PARENT' ? gone.parentId : gone.userId;

    const res = await t.app.inject({ method: 'DELETE', url: `/api/admin/users/${id}`, headers: { authorization: `Bearer ${moderator.token}` } });

    expect(res.statusCode).toBe(200);
    expect(await counts([gone.studentId])).toEqual({ requests: 0, messages: 0, participation: 0 });
    expect(await counts([kept.studentId])).toEqual({ requests: 1, messages: 3, participation: 1 });
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(2);
  });

  it('shaxsiy tayinlashdagi murojaat havolasi tozalanadi (tayinlash qoladi)', async () => {
    const gone = w.kids7a[0]!;
    const request = await fill(gone);
    const assignment = await t.prisma.schoolPsychAssignment.create({
      data: {
        schoolId: w.schoolId, testId: 'tpl-logic', testVersion: 1, target: { kind: 'STUDENTS', studentIds: [gone.studentId] }, classIds: [], studentIds: [gone.studentId],
        careRequestId: request.id, opensAt: new Date(), closesAt: new Date(Date.now() + 86_400_000), createdBy: w.psych.staffId,
      },
    });

    await t.app.inject({ method: 'DELETE', url: '/api/users/me', headers: { authorization: `Bearer ${gone.token}` } });

    expect(await t.prisma.schoolPsychAssignment.findUniqueOrThrow({ where: { id: assignment.id } })).toMatchObject({ careRequestId: null });
  });

  it('o\'chirilgandan keyin psixolog ro\'yxatida ham murojaat qolmaydi', async () => {
    const gone = w.kids7a[0]!;
    await fill(gone);
    await t.app.inject({ method: 'DELETE', url: '/api/users/me', headers: { authorization: `Bearer ${gone.token}` } });

    const list = (await staff(w.psych, 'GET', '/requests')).json();
    expect(list.items).toEqual([]);
  });
});

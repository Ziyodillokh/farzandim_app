// Psixolog amallari bolaga yetadi: test tayinlash (sinf / shaxsiy, rejalashtirilgan — ochilganda),
// so'rovnoma faollashishi va suhbat vaqti. Push neytral, har bolaga bir marta; boshqa sinfga — yo'q.

import { PsychAssignmentPushService } from '../../src/school/assessments/psych-assignment-push.service';
import { resetDb } from './db';
import { AssessWorld, buildWorld, localInput, openWindow, publishedAssignment, sampleInput, staffApi } from './school-assessments-fixtures';
import { activateSurvey, careStaff, createRequest } from './school-care-fixtures';
import { createTestApp, TestApp } from './test-app';

const HOUR = 3_600_000;

/** Ertaga Toshkent vaqti bilan soat 10:00 (tungi tanaffusdan tashqarida). */
function tomorrowAt10(): Date {
  const tashkentNow = new Date(Date.now() + 5 * HOUR);
  const day = Date.UTC(tashkentNow.getUTCFullYear(), tashkentNow.getUTCMonth(), tashkentNow.getUTCDate() + 1);
  return new Date(day + 10 * HOUR - 5 * HOUR);
}

describe('School psixolog push — bolaga yetkaziladi', () => {
  let t: TestApp;
  let w: AssessWorld;
  let api: ReturnType<typeof staffApi>;

  beforeAll(async () => {
    t = await createTestApp();
    api = staffApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await buildWorld(t);
  });

  afterAll(() => t.close());

  const pushTypes = (userId: string) => t.fcm.pushesTo(userId).map((p) => p.data?.type);

  it('sinfga test — shu sinf bolalariga bir martadan neytral push, boshqa sinfga yo\'q', async () => {
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);

    for (const kid of w.kids7a) {
      expect(t.fcm.pushesTo(kid.userId)).toEqual([
        { title: 'Parvoz', body: 'Sizga yangi test yuborildi', data: { type: 'PSYCH_ASSIGNMENT', assignmentId: assignment.id, kind: 'TEST' } },
      ]);
    }
    for (const kid of w.kids7b) expect(t.fcm.pushesTo(kid.userId)).toEqual([]);

    await t.app.get(PsychAssignmentPushService).notify(assignment.id);
    expect(pushTypes(w.kids7a[0]!.userId)).toEqual(['PSYCH_ASSIGNMENT']);
  });

  it('shaxsiy tayinlash — faqat tanlangan o\'quvchiga, uning tilida', async () => {
    const test = (await api(w.psych, 'POST', '/tests', sampleInput())).json();
    await api(w.psych, 'POST', `/tests/${test.id}/publish`);
    const kid = w.kids7b[0]!;

    const res = await api(w.psych, 'POST', '/assignments', {
      testId: test.id,
      target: { kind: 'STUDENTS', studentIds: [kid.studentId] },
      ...openWindow(),
      consent: true,
    });

    expect(res.statusCode).toBe(201);
    expect(t.fcm.pushesTo(kid.userId).map((p) => p.body)).toEqual(['Вам отправлен новый тест']);
    expect(pushTypes(w.kids7b[1]!.userId)).toEqual([]);
    for (const other of w.kids7a) expect(pushTypes(other.userId)).toEqual([]);
  });

  it('keyinroq ochiladigan test — tayinlashda push yo\'q, ochilgach cron bir marta yuboradi', async () => {
    const test = (await api(w.psych, 'POST', '/tests', sampleInput())).json();
    await api(w.psych, 'POST', `/tests/${test.id}/publish`);
    const opensAt = tomorrowAt10();
    const res = await api(w.psych, 'POST', '/assignments', {
      testId: test.id,
      target: { kind: 'CLASSES', classIds: [w.classes.c7a] },
      opensAt: localInput(opensAt),
      closesAt: localInput(new Date(opensAt.getTime() + 3 * 24 * HOUR)),
      consent: true,
    });
    expect(res.statusCode).toBe(201);
    const kid = w.kids7a[0]!;
    expect(pushTypes(kid.userId)).toEqual([]);

    const cron = t.app.get(PsychAssignmentPushService);
    expect(await cron.sweep(new Date(opensAt.getTime() - 60_000))).toBe(0);
    expect(await cron.sweep(new Date(opensAt.getTime() + 60_000))).toBe(w.kids7a.length);
    expect(await cron.sweep(new Date(opensAt.getTime() + 6 * 60_000))).toBe(0);

    expect(pushTypes(kid.userId)).toEqual(['PSYCH_ASSIGNMENT']);
  });

  it('so\'rovnoma faollashdi — yosh guruhidagi bolalarga bir martadan push', async () => {
    const survey = await activateSurvey(t, w.psych);

    for (const kid of [...w.kids7a, ...w.kids7b]) {
      expect(t.fcm.pushesTo(kid.userId).map((p) => p.data)).toEqual([{ type: 'CARE_SURVEY', surveyId: survey.id }]);
    }
    expect(t.fcm.pushesTo(w.kids7a[0]!.userId)[0]).toMatchObject({ title: 'Parvoz', body: 'Maktabdan yangi soʻrovnoma' });
  });

  it('suhbat vaqti belgilandi — murojaat egasiga neytral xabar; o\'sha vaqt qayta saqlansa push yo\'q', async () => {
    const kid = w.kids7a[0]!;
    await t.prisma.fcmToken.create({ data: { userId: kid.userId, token: 'fcm-kid-phone', deviceType: 'android' } });
    const request = await createRequest(t, kid);
    const staff = careStaff(t);
    const meetingAt = localInput(tomorrowAt10());

    const first = await staff(w.psych, 'PUT', `/requests/${request.id}/meeting`, { meetingAt });
    expect(first.statusCode).toBe(200);
    expect(t.fcm.pushesTo(kid.userId)).toEqual([
      { title: 'Parvoz', body: 'Sizga yangi xabar keldi', data: { type: 'CARE_MESSAGE', requestId: request.id } },
    ]);

    await staff(w.psych, 'PUT', `/requests/${request.id}/meeting`, { meetingAt });
    expect(pushTypes(kid.userId)).toEqual(['CARE_MESSAGE']);

    await staff(w.psych, 'PUT', `/requests/${request.id}/meeting`, { meetingAt: localInput(new Date(tomorrowAt10().getTime() + HOUR)) });
    expect(pushTypes(kid.userId)).toEqual(['CARE_MESSAGE', 'CARE_MESSAGE']);
    for (const other of w.kids7a.slice(1)) expect(pushTypes(other.userId)).toEqual([]);
  });
});

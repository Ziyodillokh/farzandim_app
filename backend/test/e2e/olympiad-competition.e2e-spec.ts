// U17–U19 · Olimpiada musobaqa rejimi: `hideResults` yoqilgan olimpiadada
// natija (to'g'ri javob, ball, sertifikat) olimpiada tugaguncha ko'rinmaydi;
// «Yakunlash» savol-savol oqimini muddatidan oldin yopadi.

import { resetDb } from './db';
import { api, familyOf } from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

const DAY_MS = 24 * 60 * 60 * 1000;

describe('Olimpiada: musobaqa rejimi va yakunlash', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
  });

  afterAll(() => t.close());

  async function olympiad(hideResults: boolean) {
    return t.prisma.olympiad.create({
      data: {
        title: 'Matematika olimpiadasi',
        subject: 'Matematika',
        ageFrom: 1,
        ageTo: 18,
        status: 'published',
        hideResults,
        startTime: new Date(Date.now() - DAY_MS),
        endTime: new Date(Date.now() + DAY_MS),
        questions: {
          create: [0, 1, 2].map((i) => ({
            text: `${i} + 1 = ?`,
            options: ['1', '2', '3', '4'],
            correctIndex: (i + 1) % 4,
            orderIdx: i,
          })),
        },
      },
      include: { questions: true },
    });
  }

  it('hideResults: javobda to\'g\'ri javob va ball yo\'q; yakunlash — kvitansiya', async () => {
    const { child } = await familyOf(t);
    const o = await olympiad(true);
    const start = await api(t, 'POST', `/content/olympiads/${o.id}/start`, { token: child.token });
    expect(start.statusCode).toBe(201);
    const attemptId = start.json().attemptId as string;

    const answer = await api(t, 'POST', `/content/olympiads/attempts/${attemptId}/answer`, {
      token: child.token,
      payload: { questionId: o.questions[0].id, selectedIndex: 1 },
    });
    expect(answer.statusCode).toBeLessThan(300);
    const body = answer.json();
    expect(body.saved).toBe(true);
    expect(body).not.toHaveProperty('isCorrect');
    expect(body).not.toHaveProperty('correctIndex');
    expect(body).not.toHaveProperty('scoreSoFar');

    const finish = await api(t, 'POST', `/content/olympiads/attempts/${attemptId}/finish`, { token: child.token });
    expect(finish.statusCode).toBe(200);
    expect(finish.json()).toMatchObject({ answersSaved: 1, questionsTotal: 3 });
    expect(finish.json()).not.toHaveProperty('score');
    expect(new Date(finish.json().resultsAt).getTime()).toBe(o.endTime.getTime());

    const stored = await t.prisma.olympiadAttempt.findUniqueOrThrow({ where: { id: attemptId } });
    expect(stored.status).toBe('finished');

    // Takroriy yakunlash — o'sha kvitansiya, XP ikki marta berilmaydi.
    const again = await api(t, 'POST', `/content/olympiads/attempts/${attemptId}/finish`, { token: child.token });
    expect(again.statusCode).toBe(200);

    const cert = await api(t, 'GET', `/content/olympiads/attempts/${attemptId}/certificate`, { token: child.token });
    expect(cert.statusCode).toBe(403);
  });

  it('oddiy olimpiadada javob izohi avvalgidek', async () => {
    const { child } = await familyOf(t);
    const o = await olympiad(false);
    const attemptId = (await api(t, 'POST', `/content/olympiads/${o.id}/start`, { token: child.token })).json()
      .attemptId as string;
    const answer = await api(t, 'POST', `/content/olympiads/attempts/${attemptId}/answer`, {
      token: child.token,
      payload: { questionId: o.questions[0].id, selectedIndex: 1 },
    });
    expect(answer.json()).toMatchObject({ isCorrect: true, correctIndex: 1 });
  });

  it('yakunlash: boshqa bolaning urinishi — 404', async () => {
    const { child } = await familyOf(t);
    const other = await familyOf(t, 'Jasur Karimov');
    const o = await olympiad(true);
    const attemptId = (await api(t, 'POST', `/content/olympiads/${o.id}/start`, { token: child.token })).json()
      .attemptId as string;
    const res = await api(t, 'POST', `/content/olympiads/attempts/${attemptId}/finish`, { token: other.child.token });
    expect(res.statusCode).toBe(404);
  });
});

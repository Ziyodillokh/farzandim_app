// I02: GET /learning/weekly — joriy va oldingi ISO hafta (Toshkent), faqat bolaning o'zi.

import { LearningAttemptStatus } from '@prisma/client';
import { addDays, daysBetween, isoWeekStart, tashkentDay } from '../../src/common/time/tashkent';
import { resetDb } from './db';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { Call, caller } from './kelajak-fixtures';
import { seedQuestionBank } from './learning-fixtures';
import { createTestApp, TestApp } from './test-app';

interface WeeklyBody {
  weeks: Array<{ weekStart: string; sessions: number; minutes: number; activeDays: number; streak: number }>;
  firstWeek: boolean;
}

describe('Haftalik faollik (GET /learning/weekly)', () => {
  let t: TestApp;
  let call: Call;
  let parent: TestParent;
  let child: TestChild;

  const today = () => tashkentDay();
  const currentStart = () => isoWeekStart(today());
  const weekly = async (token = child.token) => {
    const res = await call(token, 'GET', '/learning/weekly');
    return { res, body: res.json() as WeeklyBody };
  };

  /** Toshkent [day] kuni 10:00 (UTC 05:00) da boshlangan, [minutes] daqiqa davom etgan urinish. */
  const attempt = (
    day: string,
    minutes: number,
    options: { childId?: string; status?: LearningAttemptStatus } = {},
  ) => {
    const startedAt = new Date(`${day}T05:00:00.000Z`);
    const status = options.status ?? LearningAttemptStatus.COMPLETED;
    return t.prisma.learningAttempt.create({
      data: {
        childId: options.childId ?? child.childId,
        subject: 'MATH',
        day,
        isDaily: false,
        status,
        questionIds: [],
        total: 10,
        startedAt,
        completedAt: status === LearningAttemptStatus.COMPLETED ? new Date(startedAt.getTime() + minutes * 60_000) : null,
      },
    });
  };

  beforeAll(async () => {
    t = await createTestApp();
    call = caller(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    parent = await createParent(t.prisma);
    child = await createChild(t.prisma, parent);
  });

  afterAll(() => t.close());

  it('tokensiz — 401; ota-ona tokeni — 403', async () => {
    expect((await t.app.inject({ method: 'GET', url: '/api/learning/weekly' })).statusCode).toBe(401);
    expect((await weekly(parent.token)).res.statusCode).toBe(403);
  });

  it('faollik yo\'q: ikki hafta (eskisi birinchi), hammasi 0, firstWeek=true', async () => {
    const { res, body } = await weekly();
    expect(res.statusCode).toBe(200);
    expect(body).toEqual({
      weeks: [
        { weekStart: addDays(currentStart(), -7), sessions: 0, minutes: 0, activeDays: 0, streak: 0 },
        { weekStart: currentStart(), sessions: 0, minutes: 0, activeDays: 0, streak: 0 },
      ],
      firstWeek: true,
    });
    // Hafta boshi — dushanba
    expect(daysBetween('2026-11-02', currentStart()) % 7).toBe(0);
  });

  it('sessiya / daqiqa (60 chek) / faol kun / hafta oxiridagi streak; yakunlanmaganlar va begona bola hisoblanmaydi', async () => {
    const cur = currentStart();
    const prev = addDays(cur, -7);
    const other = await createChild(t.prisma, parent, { name: 'Zilola' });

    // Oldingi hafta: seshanba(2), payshanba(1, 10 soat → 60 chek), yakshanba(1)  → 4 sessiya, 3 faol kun
    await attempt(addDays(prev, 1), 10);
    await attempt(addDays(prev, 1), 12);
    await attempt(addDays(prev, 3), 600);
    await attempt(addDays(cur, -1), 5); // oldingi haftaning yakshanbasi
    // Hisoblanmaydi: tugallanmagan / tashlab ketilgan / begona bola / ikki hafta oldingi
    await attempt(addDays(prev, 2), 0, { status: LearningAttemptStatus.IN_PROGRESS });
    await attempt(addDays(prev, 2), 0, { status: LearningAttemptStatus.ABANDONED });
    await attempt(addDays(prev, 4), 30, { childId: other.childId });
    await attempt(addDays(prev, -10), 30);
    // Joriy hafta: dushanba (bugundan oldin yoki bugun)
    await attempt(cur, 20);
    await attempt(cur, 25);

    const { body } = await weekly();
    expect(body.firstWeek).toBe(false);
    expect(body.weeks[0]).toEqual({
      weekStart: prev,
      sessions: 4,
      minutes: 10 + 12 + 60 + 5,
      activeDays: 3,
      // hafta oxiri = yakshanba (cur-1) yechilgan; shanba(cur-2) yo'q → 1
      streak: 1,
    });
    // Joriy hafta: dushanba 2 sessiya (45 daq). Streak: dushanba + oldingi yakshanba (zanjir) = 2,
    // lekin bugun dushanbadan keyin bo'lsa va bugun/kecha yechilmagan bo'lsa — 0.
    const sinceMonday = daysBetween(cur, today());
    expect(body.weeks[1]).toEqual({
      weekStart: cur,
      sessions: 2,
      minutes: 45,
      activeDays: 1,
      streak: sinceMonday <= 1 ? 2 : 0,
    });
  });

  it('firstWeek: faqat joriy haftadagi urinish — true; oldingi hafta urinishi bo\'lsa — false', async () => {
    await attempt(currentStart(), 5);
    expect((await weekly()).body.firstWeek).toBe(true);
    await attempt(addDays(currentStart(), -1), 5);
    expect((await weekly()).body.firstWeek).toBe(false);
  });

  it('streak joriy haftadan oldingi haftaga o\'tadi (bugun/kecha yechilgan bo\'lsa)', async () => {
    // Bugundan orqaga ketma-ket 3 kun
    for (const back of [0, 1, 2]) await attempt(addDays(today(), -back), 5);
    const { body } = await weekly();
    expect(body.weeks[1].streak).toBe(3);
  });

  it('firstWeek streak oynasidan (366 kun) chekli emas: bir yil oldingi urinish ham hisoblanadi', async () => {
    await attempt(addDays(today(), -500), 5);
    await attempt(currentStart(), 5);
    const { body } = await weekly();
    expect(body.firstWeek).toBe(false);
  });

  it('streak oynasi chegaralangan: 400 kunlik zanjir 367 da to\'xtaydi (366 kun orqaga + bugun)', async () => {
    const days = Array.from({ length: 400 }, (_, i) => addDays(today(), -i));
    await t.prisma.learningAttempt.createMany({
      data: days.map((day) => ({
        childId: child.childId,
        subject: 'MATH' as const,
        day,
        isDaily: false,
        status: LearningAttemptStatus.COMPLETED,
        questionIds: [],
        total: 10,
        startedAt: new Date(`${day}T05:00:00.000Z`),
        completedAt: new Date(`${day}T05:05:00.000Z`),
      })),
    });
    const { body } = await weekly();
    expect(body.weeks[1].streak).toBe(367);
    expect(body.firstWeek).toBe(false);
  });

  it('haqiqiy oqim: kunlik test yakuni → joriy haftada 1 sessiya, firstWeek=true', async () => {
    await seedQuestionBank(t.prisma);
    expect((await call(child.token, 'PUT', '/learning/profile', { grade: 7, subjects: ['math'] })).statusCode).toBe(200);
    const started = (await call(child.token, 'POST', '/learning/attempts', { subject: 'math' })).json() as {
      id: string;
      questions: Array<{ id: string }>;
    };
    for (const q of started.questions) {
      await call(child.token, 'POST', `/learning/attempts/${started.id}/answers`, { questionId: q.id, selectedIndex: 0 });
    }
    expect((await call(child.token, 'POST', `/learning/attempts/${started.id}/complete`)).statusCode).toBe(200);

    const { body } = await weekly();
    expect(body.firstWeek).toBe(true);
    expect(body.weeks[1]).toMatchObject({ weekStart: currentStart(), sessions: 1, minutes: 0, activeDays: 1, streak: 1 });
    expect(body.weeks[0]).toMatchObject({ sessions: 0, activeDays: 0, streak: 0 });
  });

  it('javob kalitlari aynan kontraktdagidek', async () => {
    const { body } = await weekly();
    expect(Object.keys(body).sort()).toEqual(['firstWeek', 'weeks']);
    expect(Object.keys(body.weeks[0]).sort()).toEqual(['activeDays', 'minutes', 'sessions', 'streak', 'weekStart']);
  });
});

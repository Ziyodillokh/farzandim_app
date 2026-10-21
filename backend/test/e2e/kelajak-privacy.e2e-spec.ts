// Parvoz Kelajak — maxfiylik haqiqiy Postgres'da: yopiq sessiyada ochiq matn
// va wellbeing / safety qiymatlari qaytmaydi (qayta ulangan qurilma ham
// o'qiy olmaydi), bola o'z ma'lumotini o'chirsa Kelajak ham o'chadi, shifrlash
// kaliti yo'q bo'lsa ochiq savollar berilmaydi (docs/KELAJAK-REJA.md §4–§5).

import { SchoolCryptoService } from '../../src/school/common/school-crypto.service';
import { resetDb } from './db';
import { consumerToken, createChild, createParent, TestChild, TestParent } from './factories';
import { answerScale, Call, caller, lowest, seedKelajakBank, setChildAge } from './kelajak-fixtures';
import { createTestApp, TestApp } from './test-app';

interface Q {
  id: string;
  category: string;
  answerType: string;
  options: Array<{ value: number }>;
}

const SECRET = 'Maktabda meni bezovta qiladigan narsa bor';

describe('Kelajak API — maxfiylik', () => {
  let t: TestApp;
  let call: Call;
  let parent: TestParent;
  let child: TestChild;

  const startOk = async (type: string, token = child.token) => {
    const res = await call(token, 'POST', '/kelajak/sessions', { type });
    expect(res.statusCode).toBe(200);
    return res.json();
  };
  const completeOk = async (sessionId: string) => {
    const res = await call(child.token, 'POST', `/kelajak/sessions/${sessionId}/complete`);
    expect(res.statusCode).toBe(200);
    return res.json();
  };
  const view = async (sessionId: string, token = child.token) =>
    (await call(token, 'GET', `/kelajak/sessions/${sessionId}`)).json();

  /** Ota-ona bolani qayta ulaydi (repair QR / oila kodi): shu Child'ga yangi CHILD user. */
  const repair = async (): Promise<string> => {
    const user = await t.prisma.user.create({ data: { role: 'CHILD' } });
    await t.prisma.child.update({ where: { id: child.childId }, data: { childUserId: user.id } });
    return consumerToken(user.id, 'CHILD');
  };

  beforeAll(async () => {
    t = await createTestApp();
    call = caller(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedKelajakBank(t.prisma);
    parent = await createParent(t.prisma);
    child = await createChild(t.prisma, parent, { name: 'Aziz' });
    await setChildAge(t.prisma, child.childId, { via: 'age', years: 11 });
  });

  afterEach(() => jest.restoreAllMocks());

  afterAll(() => t.close());

  it('ochiq sessiyada matn bolaga qaytadi; yakunlangach — hech kimga (qayta ulangan qurilmaga ham)', async () => {
    const voice = await startOk('voice');
    const q: Q = voice.questions[0];
    await call(child.token, 'PUT', `/kelajak/sessions/${voice.id}/answers/${q.id}`, { text: SECRET });
    expect((await view(voice.id)).answers).toEqual([{ questionId: q.id, value: null, text: SECRET }]);

    const done = await completeOk(voice.id);
    expect(done.answers).toEqual([{ questionId: q.id, value: null, text: null }]);
    expect(JSON.stringify(done)).not.toContain(SECRET);

    const token = await repair();
    const res = await call(token, 'GET', `/kelajak/sessions/${voice.id}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).not.toContain(SECRET);
    expect(res.json().answers).toEqual([{ questionId: q.id, value: null, text: null }]);
    // Eski qurilma tokeni endi bola profiliga bog'lanmagan.
    expect((await call(child.token, 'GET', '/kelajak/overview')).statusCode).toBe(403);
  });

  it('yopiq sessiyada wellbeing / safety qiymatlari null, boshqa kategoriyalar saqlanadi', async () => {
    const wellbeing = await startOk('wellbeing');
    await answerScale(call, child.token, wellbeing, lowest);
    const open = await view(wellbeing.id);
    expect(open.answers.every((a: { value: number | null }) => a.value !== null)).toBe(true);
    await completeOk(wellbeing.id);

    const token = await repair();
    const closed = await view(wellbeing.id, token);
    expect(closed.answeredCount).toBe(wellbeing.total);
    expect(closed.answers.every((a: { value: number | null; text: string | null }) => a.value === null && a.text === null)).toBe(true);
    expect(closed.result.insights.support).toMatchObject({ level: 'support' });

    const learning = await startOk('learning', token);
    await answerScale(call, token, learning);
    expect((await call(token, 'POST', `/kelajak/sessions/${learning.id}/complete`)).statusCode).toBe(200);
    const kept = await view(learning.id, token);
    expect(kept.answers.every((a: { value: number | null }) => a.value !== null)).toBe(true);
  });

  it('bola "ma\'lumotlarimni o\'chirish" — Kelajak sessiyalari, javoblar va natijalar ham o\'chadi', async () => {
    const voice = await startOk('voice');
    await call(child.token, 'PUT', `/kelajak/sessions/${voice.id}/answers/${voice.questions[0].id}`, { text: SECRET });
    await completeOk(voice.id);
    const wellbeing = await startOk('wellbeing');
    await answerScale(call, child.token, wellbeing, lowest);
    await completeOk(wellbeing.id);
    expect(await t.prisma.kelajakAnswer.count()).toBeGreaterThan(0);

    const res = await call(child.token, 'DELETE', '/users/me');
    expect(res.statusCode).toBe(200);
    expect(await t.prisma.kelajakSession.count({ where: { childId: child.childId } })).toBe(0);
    expect(await t.prisma.kelajakAnswer.count()).toBe(0);
    // Profil (ota-onaniki) qoladi, lekin Kelajak xulosasi bo'sh.
    const summary = (await call(parent.token, 'GET', `/children/${child.childId}/kelajak/summary`)).json();
    expect(summary).toMatchObject({ sessionsCompleted: 0, support: null, categories: [] });
  });

  it('SCHOOL_DATA_KEY yo\'q — ochiq fikr testi ko\'rsatilmaydi va boshlanmaydi', async () => {
    const before = await startOk('voice');
    jest.spyOn(SchoolCryptoService.prototype, 'isConfigured').mockReturnValue(false);

    const overview = (await call(child.token, 'GET', '/kelajak/overview')).json();
    const types = overview.tests.map((x: { type: string }) => x.type);
    // Bugungi boshlangan sessiya bo'lsa — u ko'rinadi; yangi kunda voice umuman chiqmaydi.
    expect(types).toContain('daily');
    await t.prisma.kelajakSession.deleteMany({ where: { id: before.id } });
    const fresh = (await call(child.token, 'GET', '/kelajak/overview')).json();
    expect(fresh.tests.map((x: { type: string }) => x.type)).not.toContain('voice');

    const res = await call(child.token, 'POST', '/kelajak/sessions', { type: 'voice' });
    expect(res.statusCode).toBe(404);
    expect(res.json().code).toBe('NO_QUESTIONS');
    const daily = await startOk('daily');
    expect(daily.questions.every((q: Q) => q.answerType !== 'text')).toBe(true);
  });
});

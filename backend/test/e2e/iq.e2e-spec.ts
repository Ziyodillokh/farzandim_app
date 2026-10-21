// Parvoz IQ test — haqiqiy Postgres'da: yosh/daraja, javob kaliti sirligi,
// yakunlash (idempotent), norma, qayta topshirish, muddati o'tgan sessiya va
// ota-ona xulosasi (docs/IQ-REJA.md).

import { PrismaClient } from '@prisma/client';
import { buildIqBankRows } from '../../scripts/iq/build-bank-migration';
import { resetDb } from './db';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { Call, caller, setChildAge } from './kelajak-fixtures';
import { createTestApp, TestApp } from './test-app';

const DAY_MS = 86_400_000;

async function seedIqBank(prisma: PrismaClient): Promise<void> {
  await prisma.iqItem.createMany({
    data: buildIqBankRows().map(({ options, ...row }) => ({ ...row, options })),
  });
}

describe('IQ API', () => {
  let t: TestApp;
  let call: Call;
  let parent: TestParent;
  let child: TestChild;

  const start = (token = child.token) => call(token, 'POST', '/iq/sessions');
  const put = (sessionId: string, itemId: string, body: object) =>
    call(child.token, 'PUT', `/iq/sessions/${sessionId}/answers/${itemId}`, body);
  const complete = (sessionId: string) => call(child.token, 'POST', `/iq/sessions/${sessionId}/complete`);

  /** Hamma savolga javob: `correct` ta to'g'ri (kalit DB'dan), qolgani noto'g'ri. */
  async function answerAll(session: { id: string; items: Array<{ id: string }> }, correct: number): Promise<void> {
    const keys = await t.prisma.iqItem.findMany({
      where: { id: { in: session.items.map((i) => i.id) } },
    });
    const answerOf = new Map(keys.map((k) => [k.id, k.answer]));
    for (const [i, item] of session.items.entries()) {
      const right = answerOf.get(item.id) as string;
      const choice = i < correct ? right : right === 'A' ? 'B' : 'A';
      expect((await put(session.id, item.id, { choice, durationMs: 12_000 })).statusCode).toBe(200);
    }
  }

  beforeAll(async () => {
    t = await createTestApp();
    call = caller(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedIqBank(t.prisma);
    parent = await createParent(t.prisma);
    child = await createChild(t.prisma, parent, { name: 'Aziz' });
    await setChildAge(t.prisma, child.childId, { via: 'age', years: 9 });
  });

  afterAll(() => t.close());

  it("yosh yo'q / 9 dan kichik — 409, fallback yo'q", async () => {
    await setChildAge(t.prisma, child.childId, { via: 'none' });
    expect((await start()).json()).toMatchObject({ code: 'AGE_REQUIRED' });
    await setChildAge(t.prisma, child.childId, { via: 'age', years: 8 });
    expect((await start()).json()).toMatchObject({ code: 'AGE_OUT_OF_RANGE' });
  });

  it("sessiya: yoshga mos forma, 20 savol osondan qiyinga, javob kaliti YO'Q, qayta chaqiruv — o'sha sessiya", async () => {
    await setChildAge(t.prisma, child.childId, { via: 'birthDate', years: 13 });
    const res = await start();
    expect(res.statusCode).toBe(200);
    const session = res.json();
    expect(session).toMatchObject({
      status: 'STARTED',
      level: 3,
      form: 'L3A',
      total: 20,
      result: null,
    });
    expect(session.items).toHaveLength(20);
    expect(res.body).not.toMatch(/"answer"|"correct"|"b"/);
    expect(session.items[0].options.map((o: { key: string }) => o.key)).toEqual(['A', 'B', 'C', 'D', 'E', 'F']);
    const rows = await t.prisma.iqItem.findMany({
      where: { id: { in: session.items.map((i: { id: string }) => i.id) } },
    });
    const bById = new Map(rows.map((r) => [r.id, r.b]));
    const bs = session.items.map((i: { id: string }) => bById.get(i.id) as number);
    expect([...bs].sort((a, b) => a - b)).toEqual(bs);
    expect((await start()).json().id).toBe(session.id);
  });

  it("javob: noma'lum variant va begona savol — 400; to'g'riligi qaytarilmaydi", async () => {
    const session = (await start()).json();
    const item = session.items[0];
    expect((await put(session.id, item.id, { choice: 'G' })).statusCode).toBe(400);
    const other = await t.prisma.iqItem.findFirst({ where: { level: 5 } });
    expect((await put(session.id, other!.id, { choice: 'A' })).json()).toMatchObject({ code: 'ITEM_NOT_IN_SESSION' });
    const ok = await put(session.id, item.id, { choice: 'A' });
    expect(ok.json()).toEqual({
      answeredCount: 1,
      total: 20,
      status: 'IN_PROGRESS',
    });
  });

  it("yakunlash: javobsiz savol bo'lsa 400 UNANSWERED", async () => {
    const session = (await start()).json();
    await put(session.id, session.items[0].id, { choice: 'A' });
    const res = await complete(session.id);
    expect(res.statusCode).toBe(400);
    expect(res.json()).toMatchObject({ code: 'UNANSWERED' });
    expect(res.json().remaining).toHaveLength(19);
  });

  it("yakunlash: PROVISIONAL natija, normaga bir marta qo'shiladi, idempotent", async () => {
    const session = (await start()).json();
    await answerAll(session, 18);
    const done = (await complete(session.id)).json();
    expect(done.status).toBe('COMPLETED');
    expect(done.result).toMatchObject({
      correct: 18,
      total: 20,
      status: 'PROVISIONAL',
      standardScore: null,
      ci95: null,
      normGroup: '9',
    });
    expect(done.result.percentile).toBeGreaterThan(50);
    expect(done.items.find((i: { choice: string | null }) => i.choice === null)).toBeUndefined();
    expect((await complete(session.id)).json().result).toEqual(done.result);
    expect(await t.prisma.iqNorm.findUnique({ where: { group: '9' } })).toMatchObject({ n: 1 });
  });

  it('norma yetarli (n ≥ 300) — NORMED: IQ raqami va 95% oraliq', async () => {
    await t.prisma.iqNorm.create({
      data: { group: '9', n: 400, mean: -1.0, m2: 0.64 * 399 },
    });
    const session = (await start()).json();
    await answerAll(session, 10);
    const { result } = (await complete(session.id)).json();
    expect(result.status).toBe('NORMED');
    expect(result.standardScore).toEqual(expect.any(Number));
    expect(result.ci95[0]).toBeLessThan(result.standardScore);
    expect(result.ci95[1]).toBeGreaterThan(result.standardScore);
  });

  it('qayta topshirish: 180 kun ichida 409, keyin B forma (normaga kirmaydi)', async () => {
    const first = (await start()).json();
    await answerAll(first, 12);
    await complete(first.id);
    const early = await start();
    expect(early.statusCode).toBe(409);
    expect(early.json()).toMatchObject({
      code: 'RETAKE_TOO_SOON',
      nextAvailableAt: expect.any(String),
    });
    expect((await call(child.token, 'GET', '/iq/overview')).json()).toMatchObject({ canStart: false, active: null });

    await t.prisma.iqSession.update({
      where: { id: first.id },
      data: { completedAt: new Date(Date.now() - 181 * DAY_MS) },
    });
    const second = (await start()).json();
    expect(second).toMatchObject({ form: 'L1B', status: 'STARTED' });
    await answerAll(second, 20);
    await complete(second.id);
    expect(await t.prisma.iqNorm.findUnique({ where: { group: '9' } })).toMatchObject({ n: 1 });
  });

  it('24 soatdan eski ochiq sessiya yopiladi — javob 409 SESSION_CLOSED, yangisi ochiladi', async () => {
    const session = (await start()).json();
    await t.prisma.iqSession.update({
      where: { id: session.id },
      data: { startedAt: new Date(Date.now() - 25 * 3_600_000) },
    });
    expect((await put(session.id, session.items[0].id, { choice: 'A' })).json()).toMatchObject({
      code: 'SESSION_CLOSED',
    });
    expect((await start()).json().id).not.toBe(session.id);
  });

  it("ota-ona: faqat o'z bolasi — to'liq natija, savollarsiz", async () => {
    const session = (await start()).json();
    await answerAll(session, 15);
    await complete(session.id);
    const res = await call(parent.token, 'GET', `/children/${child.childId}/iq/summary`);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({
      age: { status: 'OK', level: 1 },
      last: { correct: 15, total: 20 },
    });
    expect(res.json().history).toHaveLength(1);
    expect(res.body).not.toMatch(/gridSvg|"choice"|"answer"/);

    const stranger = await createParent(t.prisma);
    expect((await call(stranger.token, 'GET', `/children/${child.childId}/iq/summary`)).statusCode).toBe(403);
    expect((await call(child.token, 'GET', `/children/${child.childId}/iq/summary`)).statusCode).toBe(403);
  });
});

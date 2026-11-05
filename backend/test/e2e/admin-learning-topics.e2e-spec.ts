// Admin — Daily Learning mavzular katalogi: ruxsat, CRUD, tartiblash,
// savollarni bog'lash, savol DTO'sidagi topicId, audit.

import { createChild, createModerator, createParent, TestModerator } from './factories';
import { resetDb } from './db';
import { createQuestions, createTopic } from './learning-topics-fixtures';
import { createTestApp, TestApp } from './test-app';

const UNKNOWN_ID = '00000000-0000-4000-8000-000000000000';
const AUDIT_WAIT_MS = 2_000;
const AUDIT_POLL_MS = 25;

const topicBody = (patch: object = {}) => ({
  subject: 'math',
  key: 'oddiy-kasrlar',
  title: { uz: 'Oddiy kasrlar', ru: 'Обыкновенные дроби', en: 'Fractions' },
  goal: { uz: 'Kasrlarni qo\'shish va ayirish' },
  minGrade: 5,
  maxGrade: 7,
  ...patch,
});

const questionBody = (patch: object = {}) => ({
  subject: 'math',
  externalId: 'math-900',
  difficulty: 2,
  minGrade: 5,
  maxGrade: 9,
  topic: { uz: 'Foizlar', ru: 'Проценты', en: 'Percent' },
  prompt: { uz: '200 ning 10% i?', ru: '10% от 200?', en: '10% of 200?' },
  options: ['10', '20', '30', '40'].map((v) => ({ uz: v, ru: v, en: v })),
  answerIndex: 1,
  explanation: { uz: '200 × 0,1 = 20', ru: '200 × 0,1 = 20', en: '200 × 0.1 = 20' },
  ...patch,
});

describe('Admin learning topics API', () => {
  let t: TestApp;
  let admin: TestModerator;

  const call = (method: 'GET' | 'POST' | 'PATCH' | 'DELETE', url: string, payload?: object, token: string | null = admin.token) =>
    t.app.inject({
      method,
      url: `/api/admin/learning${url}`,
      ...(token && { headers: { authorization: `Bearer ${token}` } }),
      ...(payload && { payload }),
    });

  const createViaApi = async (patch: object = {}) => {
    const res = await call('POST', '/topics', topicBody(patch));
    expect(res.statusCode).toBe(201);
    return res.json();
  };

  /** Audit yozuvi fonda yoziladi (`void log`) — paydo bo'lishini kutamiz. */
  const auditRows = async (action: string) => {
    const deadline = Date.now() + AUDIT_WAIT_MS;
    for (;;) {
      const rows = await t.prisma.moderatorAuditLog.findMany({ where: { action } });
      if (rows.length > 0 || Date.now() > deadline) return rows;
      await new Promise((resolve) => setTimeout(resolve, AUDIT_POLL_MS));
    }
  };

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    admin = await createModerator(t.prisma, ['manage_learning']);
  });

  afterAll(() => t.close());

  describe('kirish huquqi', () => {
    it('ruxsatsiz moderator — 403, tokensiz — 401, bola / ota-ona tokeni — rad etiladi', async () => {
      const topic = await createTopic(t.prisma);
      const noPermission = await createModerator(t.prisma, ['view_users']);
      const parent = await createParent(t.prisma);
      const child = await createChild(t.prisma, parent);
      const requests: [('GET' | 'POST' | 'PATCH'), string, object?][] = [
        ['GET', '/topics'],
        ['POST', '/topics', topicBody()],
        ['PATCH', `/topics/${topic.id}`, { position: 3 }],
        ['POST', '/topics/reorder', { subject: 'math', ids: [topic.id] }],
        ['POST', `/topics/${topic.id}/questions`, { questionIds: [UNKNOWN_ID] }],
      ];
      for (const [method, url, payload] of requests) {
        expect((await call(method, url, payload, noPermission.token)).statusCode).toBe(403);
        expect((await call(method, url, payload, null)).statusCode).toBe(401);
        expect([401, 403]).toContain((await call(method, url, payload, child.token)).statusCode);
        expect([401, 403]).toContain((await call(method, url, payload, parent.token)).statusCode);
      }
      // Rad etilgan so'rovlar hech narsani o'zgartirmagan.
      expect(await t.prisma.learningTopic.count()).toBe(1);
    });
  });

  describe('POST /topics', () => {
    it('yaratadi: 201, standart holat ACTIVE, pozitsiya fan oxiriga, questionCount 0', async () => {
      const first = await createViaApi();
      expect(first).toMatchObject({
        subject: 'math',
        key: 'oddiy-kasrlar',
        title: { uz: 'Oddiy kasrlar', ru: 'Обыкновенные дроби', en: 'Fractions' },
        goal: { uz: 'Kasrlarni qo\'shish va ayirish' },
        minGrade: 5,
        maxGrade: 7,
        position: 0,
        status: 'ACTIVE',
        questionCount: 0,
        createdBy: admin.id,
      });
      expect(first.id).toEqual(expect.any(String));

      const second = await createViaApi({ key: 'foizlar', title: { uz: 'Foizlar' }, goal: undefined });
      expect(second).toMatchObject({ position: 1, goal: null, title: { uz: 'Foizlar' } });
      // Boshqa fan o'z hisobini boshlaydi; aniq pozitsiya va holat berish mumkin.
      const physics = await createViaApi({ subject: 'physics', key: 'kuch', minGrade: 7, maxGrade: 9, position: 5, status: 'HIDDEN' });
      expect(physics).toMatchObject({ subject: 'physics', position: 5, status: 'HIDDEN' });
    });

    it('bir xil kalit boshqa fanda mumkin, o\'sha fanda — 409 TOPIC_KEY_TAKEN', async () => {
      await createViaApi();
      const dup = await call('POST', '/topics', topicBody());
      expect(dup.statusCode).toBe(409);
      expect(dup.json().code).toBe('TOPIC_KEY_TAKEN');
      expect((await call('POST', '/topics', topicBody({ subject: 'physics' }))).statusCode).toBe(201);
      expect(await t.prisma.learningTopic.count()).toBe(2);
    });

    it.each([
      ['yaroqsiz kalit (katta harf)', { key: 'Oddiy-Kasrlar' }],
      ['yaroqsiz kalit (bo\'shliq)', { key: 'oddiy kasrlar' }],
      ['yaroqsiz kalit (defis chetda)', { key: '-kasr' }],
      ['kalit bo\'sh', { key: '' }],
      ['kalit 80 belgidan uzun', { key: 'a'.repeat(81) }],
      ['title.uz yo\'q', { title: { ru: 'Дроби' } }],
      ['title.uz bo\'sh', { title: { uz: '   ' } }],
      ['title noma\'lum til', { title: { uz: 'Kasrlar', fr: 'Fractions' } }],
      ['title obyekt emas', { title: 'Kasrlar' }],
      ['title.uz 80 belgidan uzun', { title: { uz: 'x'.repeat(81) } }],
      ['goal.uz bo\'sh', { goal: { uz: '' } }],
      ['minGrade > maxGrade', { minGrade: 8, maxGrade: 6 }],
      ['minGrade 0', { minGrade: 0 }],
      ['maxGrade 12', { maxGrade: 12 }],
      ['sinf kasr son', { minGrade: 5.5 }],
      ['noma\'lum fan', { subject: 'astrology' }],
      ['noma\'lum holat', { status: 'DELETED' }],
      ['manfiy pozitsiya', { position: -1 }],
      ['ortiqcha maydon', { extra: true }],
    ])('400: %s', async (_name, patch) => {
      const res = await call('POST', '/topics', topicBody(patch));
      expect(res.statusCode).toBe(400);
      expect(await t.prisma.learningTopic.count()).toBe(0);
    });

    it('title: ru / en ixtiyoriy, bo\'sh qiymatlar tushiriladi, matn qirqiladi', async () => {
      const res = await createViaApi({ title: { uz: '  Kasrlar ', ru: '', en: '  ' } });
      expect(res.title).toEqual({ uz: 'Kasrlar' });
    });
  });

  describe('GET /topics', () => {
    it('fan, pozitsiya bo\'yicha tartib; filtrlar; questionCount faqat FAOL savollar', async () => {
      await createTopic(t.prisma, { key: 'm2', position: 1 });
      const m1 = await createTopic(t.prisma, { key: 'm1', position: 0 });
      await createTopic(t.prisma, { key: 'p1', subject: 'PHYSICS', position: 0, status: 'HIDDEN' });
      await createQuestions(t.prisma, 3, m1.id);
      await createQuestions(t.prisma, 2, m1.id, { status: 'ARCHIVED' });
      await createQuestions(t.prisma, 1, m1.id, { status: 'DRAFT' });
      await createQuestions(t.prisma, 4, null);

      const all = (await call('GET', '/topics')).json();
      expect(all.minQuestions).toBe(10);
      expect(all.items.map((x: { key: string }) => x.key)).toEqual(['m1', 'm2', 'p1']);
      expect(all.items.map((x: { questionCount: number }) => x.questionCount)).toEqual([3, 0, 0]);
      expect(all.items[0].subject).toBe('math');

      expect((await call('GET', '/topics?subject=math')).json().items).toHaveLength(2);
      const hidden = (await call('GET', '/topics?status=HIDDEN')).json().items;
      expect(hidden.map((x: { key: string }) => x.key)).toEqual(['p1']);
      expect((await call('GET', '/topics?subject=physics&status=ACTIVE')).json().items).toEqual([]);
      expect((await call('GET', '/topics?subject=astrology')).statusCode).toBe(400);
      expect((await call('GET', '/topics?status=DELETED')).statusCode).toBe(400);
    });
  });

  describe('PATCH /topics/:id', () => {
    it('sarlavha, maqsad, sinflar, kalit, holat va pozitsiyani o\'zgartiradi; qolganlari o\'zgarmaydi', async () => {
      const created = await createViaApi();
      const res = await call('PATCH', `/topics/${created.id}`, {
        title: { uz: 'Kasrlar', en: 'Fractions' },
        goal: { uz: 'Yangi maqsad' },
        minGrade: 6,
        maxGrade: 8,
        key: 'kasrlar',
        status: 'HIDDEN',
        position: 4,
      });
      expect(res.statusCode).toBe(200);
      expect(res.json()).toMatchObject({
        id: created.id,
        subject: 'math',
        key: 'kasrlar',
        title: { uz: 'Kasrlar', en: 'Fractions' },
        goal: { uz: 'Yangi maqsad' },
        minGrade: 6,
        maxGrade: 8,
        status: 'HIDDEN',
        position: 4,
      });

      const partial = await call('PATCH', `/topics/${created.id}`, { status: 'ACTIVE' });
      expect(partial.json()).toMatchObject({ status: 'ACTIVE', key: 'kasrlar', minGrade: 6, maxGrade: 8, title: { uz: 'Kasrlar', en: 'Fractions' } });
    });

    it('goal: null maqsadni o\'chiradi; berilmasa saqlanadi', async () => {
      const created = await createViaApi();
      expect((await call('PATCH', `/topics/${created.id}`, { position: 2 })).json().goal).toEqual({ uz: 'Kasrlarni qo\'shish va ayirish' });
      const cleared = await call('PATCH', `/topics/${created.id}`, { goal: null });
      expect(cleared.statusCode).toBe(200);
      expect(cleared.json().goal).toBeNull();
    });

    it('faqat bitta chegara o\'zgarsa ham minGrade <= maxGrade tekshiriladi', async () => {
      const created = await createViaApi({ minGrade: 5, maxGrade: 7 });
      expect((await call('PATCH', `/topics/${created.id}`, { minGrade: 9 })).statusCode).toBe(400);
      expect((await call('PATCH', `/topics/${created.id}`, { maxGrade: 4 })).statusCode).toBe(400);
      expect((await call('PATCH', `/topics/${created.id}`, { minGrade: 7 })).statusCode).toBe(200);
    });

    it('kalit takrori — 409; o\'z kaliti bilan qayta saqlash mumkin; fan o\'zgartirilmaydi', async () => {
      const a = await createViaApi({ key: 'a' });
      await createViaApi({ key: 'b' });
      const conflict = await call('PATCH', `/topics/${a.id}`, { key: 'b' });
      expect(conflict.statusCode).toBe(409);
      expect(conflict.json().code).toBe('TOPIC_KEY_TAKEN');
      expect((await call('PATCH', `/topics/${a.id}`, { key: 'a', position: 3 })).statusCode).toBe(200);
      expect((await call('PATCH', `/topics/${a.id}`, { subject: 'physics' })).statusCode).toBe(400);
    });

    it.each([
      ['bo\'sh tana', {}],
      ['yaroqsiz kalit', { key: 'Bad Key' }],
      ['title.uz bo\'sh', { title: { uz: '' } }],
      ['noma\'lum holat', { status: 'DELETED' }],
      ['sinf oralig\'idan tashqari', { maxGrade: 12 }],
      ['manfiy pozitsiya', { position: -2 }],
    ])('400: %s', async (_name, body) => {
      const created = await createViaApi();
      expect((await call('PATCH', `/topics/${created.id}`, body)).statusCode).toBe(400);
      const stored = await t.prisma.learningTopic.findUniqueOrThrow({ where: { id: created.id } });
      expect(stored).toMatchObject({ key: 'oddiy-kasrlar', status: 'ACTIVE', minGrade: 5, maxGrade: 7, position: 0 });
    });

    it('mavjud emas — 404; noto\'g\'ri id — 400', async () => {
      expect((await call('PATCH', `/topics/${UNKNOWN_ID}`, { position: 1 })).statusCode).toBe(404);
      expect((await call('PATCH', '/topics/not-a-uuid', { position: 1 })).statusCode).toBe(400);
    });

    it('HIDDEN mavzu bola ilovasidan yo\'qoladi, qayta ACTIVE — qaytadi (o\'chirish yo\'q)', async () => {
      const parent = await createParent(t.prisma);
      const child = await createChild(t.prisma, parent);
      await t.prisma.learningProfile.create({ data: { childId: child.childId, grade: 7, subjects: ['MATH'] } });
      const created = await createViaApi();
      const list = () =>
        t.app.inject({ method: 'GET', url: '/api/learning/subjects/math/topics', headers: { authorization: `Bearer ${child.token}` } });

      expect((await list()).json().topics).toHaveLength(1);
      await call('PATCH', `/topics/${created.id}`, { status: 'HIDDEN' });
      expect((await list()).json().topics).toHaveLength(0);
      await call('PATCH', `/topics/${created.id}`, { status: 'ACTIVE' });
      expect((await list()).json().topics).toHaveLength(1);
      expect((await call('DELETE', `/topics/${created.id}`)).statusCode).toBe(404);
    });
  });

  describe('POST /topics/reorder', () => {
    async function threeMath() {
      const a = await createTopic(t.prisma, { key: 'a', position: 0 });
      const b = await createTopic(t.prisma, { key: 'b', position: 1 });
      const c = await createTopic(t.prisma, { key: 'c', position: 2, status: 'HIDDEN' });
      const other = await createTopic(t.prisma, { key: 'x', subject: 'PHYSICS', position: 7 });
      return { a, b, c, other };
    }
    const positions = async () =>
      Object.fromEntries((await t.prisma.learningTopic.findMany()).map((x) => [x.key, x.position]));

    it('position = indeks (yashirin mavzular ham); boshqa fanga tegilmaydi; yangi tartibli ro\'yxat', async () => {
      const { a, b, c } = await threeMath();
      const res = await call('POST', '/topics/reorder', { subject: 'math', ids: [c.id, a.id, b.id] });
      expect(res.statusCode).toBe(200);
      expect(res.json().items.map((x: { key: string; position: number }) => [x.key, x.position])).toEqual([
        ['c', 0],
        ['a', 1],
        ['b', 2],
      ]);
      expect(await positions()).toEqual({ c: 0, a: 1, b: 2, x: 7 });
    });

    it('400 TOPIC_ORDER_MISMATCH: yetishmayotgan, ortiqcha, boshqa fan mavzusi, noma\'lum id — hech narsa o\'zgarmaydi', async () => {
      const { a, b, c, other } = await threeMath();
      const before = await positions();
      const bad: string[][] = [
        [a.id, b.id], // c yetishmaydi
        [a.id, b.id, c.id, other.id], // boshqa fan mavzusi ortiqcha
        [a.id, b.id, other.id], // c o'rniga boshqa fan
        [a.id, b.id, UNKNOWN_ID], // noma'lum
      ];
      for (const ids of bad) {
        const res = await call('POST', '/topics/reorder', { subject: 'math', ids });
        expect(res.statusCode).toBe(400);
        expect(res.json().code).toBe('TOPIC_ORDER_MISMATCH');
      }
      expect(await positions()).toEqual(before);
    });

    it('400: takroriy id, bo\'sh ro\'yxat, noto\'g\'ri format, noma\'lum fan', async () => {
      const { a, b, c } = await threeMath();
      for (const body of [
        { subject: 'math', ids: [a.id, a.id, b.id, c.id] },
        { subject: 'math', ids: [] },
        { subject: 'math', ids: ['x'] },
        { subject: 'astrology', ids: [a.id] },
        { subject: 'math' },
      ]) {
        expect((await call('POST', '/topics/reorder', body)).statusCode).toBe(400);
      }
    });
  });

  describe('POST /topics/:id/questions', () => {
    it('savollarni bog\'laydi (boshqa mavzudan ko\'chiradi), takror chaqiruv xavfsiz', async () => {
      const target = await createTopic(t.prisma, { key: 'target' });
      const source = await createTopic(t.prisma, { key: 'source' });
      const free = await createQuestions(t.prisma, 3, null);
      const moved = await createQuestions(t.prisma, 2, source.id);
      const ids = [...free, ...moved].map((q) => q.id);

      const res = await call('POST', `/topics/${target.id}/questions`, { questionIds: ids });
      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ topicId: target.id, linked: 5, questionCount: 5 });
      expect(await t.prisma.learningQuestion.count({ where: { topicId: target.id } })).toBe(5);
      expect(await t.prisma.learningQuestion.count({ where: { topicId: source.id } })).toBe(0);

      expect((await call('POST', `/topics/${target.id}/questions`, { questionIds: ids })).json().questionCount).toBe(5);
      const listed = (await call('GET', '/topics?subject=math')).json().items;
      expect(listed.find((x: { key: string }) => x.key === 'target').questionCount).toBe(5);
    });

    it('questionCount faqat FAOL savollarni sanaydi', async () => {
      const topic = await createTopic(t.prisma);
      const questions = [
        ...(await createQuestions(t.prisma, 2, null)),
        ...(await createQuestions(t.prisma, 1, null, { status: 'ARCHIVED' })),
      ];
      const res = await call('POST', `/topics/${topic.id}/questions`, { questionIds: questions.map((q) => q.id) });
      expect(res.json()).toMatchObject({ linked: 3, questionCount: 2 });
    });

    it('400 QUESTION_SUBJECT_MISMATCH: boshqa fan savoli — hech biri bog\'lanmaydi', async () => {
      const topic = await createTopic(t.prisma);
      const ok = await createQuestions(t.prisma, 2, null);
      const foreign = await createQuestions(t.prisma, 1, null, { subject: 'PHYSICS' });
      const res = await call('POST', `/topics/${topic.id}/questions`, { questionIds: [...ok, ...foreign].map((q) => q.id) });
      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'QUESTION_SUBJECT_MISMATCH', questionIds: [foreign[0].id] });
      expect(await t.prisma.learningQuestion.count({ where: { topicId: topic.id } })).toBe(0);
    });

    it('400 QUESTION_NOT_FOUND; mavzu yo\'q — 404; bo\'sh / noto\'g\'ri tana — 400', async () => {
      const topic = await createTopic(t.prisma);
      const [q] = await createQuestions(t.prisma, 1, null);
      const missing = await call('POST', `/topics/${topic.id}/questions`, { questionIds: [q.id, UNKNOWN_ID] });
      expect(missing.statusCode).toBe(400);
      expect(missing.json()).toMatchObject({ code: 'QUESTION_NOT_FOUND', questionIds: [UNKNOWN_ID] });
      expect((await call('POST', `/topics/${UNKNOWN_ID}/questions`, { questionIds: [q.id] })).statusCode).toBe(404);
      expect((await call('POST', `/topics/${topic.id}/questions`, { questionIds: [] })).statusCode).toBe(400);
      expect((await call('POST', `/topics/${topic.id}/questions`, { questionIds: ['x'] })).statusCode).toBe(400);
      expect((await call('POST', `/topics/${topic.id}/questions`, { questionIds: [q.id, q.id] })).statusCode).toBe(400);
    });
  });

  describe('savollar: topicId', () => {
    it('yaratishda topicId saqlanadi va qaytadi; ro\'yxat topicId bilan filtrlanadi', async () => {
      const topic = await createTopic(t.prisma);
      const created = await call('POST', '/questions', questionBody({ topicId: topic.id }));
      expect(created.statusCode).toBe(201);
      expect(created.json().topicId).toBe(topic.id);
      await call('POST', '/questions', questionBody({ externalId: 'math-901' }));

      const filtered = (await call('GET', `/questions?topicId=${topic.id}`)).json();
      expect(filtered.pagination.total).toBe(1);
      expect(filtered.items[0]).toMatchObject({ externalId: 'math-900', topicId: topic.id });
      const all = (await call('GET', '/questions?subject=math&limit=50')).json();
      expect(all.items.find((x: { externalId: string }) => x.externalId === 'math-901').topicId).toBeNull();
      expect((await call('GET', '/questions?topicId=nope')).statusCode).toBe(400);
    });

    it('400: mavzu mavjud emas yoki boshqa fanniki', async () => {
      const physics = await createTopic(t.prisma, { subject: 'PHYSICS' });
      const unknown = await call('POST', '/questions', questionBody({ topicId: UNKNOWN_ID }));
      expect(unknown.statusCode).toBe(400);
      expect(unknown.json().code).toBe('TOPIC_NOT_FOUND');
      const wrong = await call('POST', '/questions', questionBody({ topicId: physics.id }));
      expect(wrong.statusCode).toBe(400);
      expect(wrong.json().code).toBe('QUESTION_SUBJECT_MISMATCH');
      expect((await call('POST', '/questions', questionBody({ topicId: 'nope' }))).statusCode).toBe(400);
      expect(await t.prisma.learningQuestion.count()).toBe(0);
    });

    it('tahrirlash: topicId o\'rnatiladi, almashtiriladi, null bilan ajratiladi; berilmasa o\'zgarmaydi', async () => {
      const a = await createTopic(t.prisma, { key: 'a' });
      const b = await createTopic(t.prisma, { key: 'b' });
      const physics = await createTopic(t.prisma, { key: 'p', subject: 'PHYSICS' });
      const id = (await call('POST', '/questions', questionBody())).json().id;

      expect((await call('PATCH', `/questions/${id}`, { topicId: a.id })).json().topicId).toBe(a.id);
      expect((await call('PATCH', `/questions/${id}`, { prompt: { uz: 'Yangi?', ru: 'Новый?', en: 'New?' } })).json().topicId).toBe(a.id);
      expect((await call('PATCH', `/questions/${id}`, { topicId: b.id })).json().topicId).toBe(b.id);
      expect((await call('PATCH', `/questions/${id}`, { topicId: physics.id })).statusCode).toBe(400);
      expect((await call('PATCH', `/questions/${id}`, { topicId: UNKNOWN_ID })).statusCode).toBe(400);
      expect((await call('PATCH', `/questions/${id}`, { topicId: null })).json().topicId).toBeNull();
      expect((await call('GET', `/questions/${id}`)).json().topicId).toBeNull();
    });

    it('import: topicId berilsa yangi va yangilangan savollar mavzuga bog\'lanadi', async () => {
      const topic = await createTopic(t.prisma, { subject: 'HISTORY', key: 'h' });
      const bank = (id: string) => ({ id, difficulty: 1, grades: [5, 9], topic: 'Tarix', question: `${id}?`, options: ['a', 'b', 'c', 'd'], answer: 0, explanation: 'izoh' });
      const first = await call('POST', '/questions/import', { subject: 'history', topicId: topic.id, questions: [bank('history-90'), bank('history-91')] });
      expect(first.json()).toMatchObject({ created: 2 });
      expect(await t.prisma.learningQuestion.count({ where: { topicId: topic.id } })).toBe(2);

      // Mavjud savol: 'skip' tegmaydi, 'update' mavzuga bog'laydi.
      await t.prisma.learningQuestion.updateMany({ data: { topicId: null } });
      await call('POST', '/questions/import', { subject: 'history', topicId: topic.id, questions: [bank('history-90')] });
      expect(await t.prisma.learningQuestion.count({ where: { topicId: topic.id } })).toBe(0);
      const updated = await call('POST', '/questions/import', { subject: 'history', topicId: topic.id, existing: 'update', questions: [bank('history-90')] });
      expect(updated.json()).toMatchObject({ updated: 1 });
      expect(await t.prisma.learningQuestion.count({ where: { topicId: topic.id } })).toBe(1);

      const wrong = await call('POST', '/questions/import', { subject: 'math', topicId: topic.id, questions: [bank('math-90')] });
      expect(wrong.statusCode).toBe(400);
      expect(await t.prisma.learningQuestion.count()).toBe(2);
    });

    it('mavzu o\'chirilsa (to\'g\'ridan-to\'g\'ri bazada) savollar bog\'lanishi SetNull bo\'ladi', async () => {
      const topic = await createTopic(t.prisma);
      const [q] = await createQuestions(t.prisma, 1, topic.id);
      await t.prisma.learningTopic.delete({ where: { id: topic.id } });
      expect((await t.prisma.learningQuestion.findUniqueOrThrow({ where: { id: q.id } })).topicId).toBeNull();
    });
  });

  describe('audit jurnali', () => {
    it('yaratish, tahrirlash, tartiblash va bog\'lash audit qilinadi', async () => {
      const created = await createViaApi();
      await call('PATCH', `/topics/${created.id}`, { position: 1 });
      await call('POST', '/topics/reorder', { subject: 'math', ids: [created.id] });
      const [q] = await createQuestions(t.prisma, 1, null);
      await call('POST', `/topics/${created.id}/questions`, { questionIds: [q.id] });

      for (const action of ['create', 'update', 'reorder', 'link_questions']) {
        const rows = await auditRows(`learning.topic.${action}`);
        expect(rows).toHaveLength(1);
        expect(rows[0]).toMatchObject({ moderatorId: admin.id, resourceType: 'learning_topic', status: 'success' });
      }
      expect((await auditRows('learning.topic.create'))[0].resourceId).toBe(created.id);
    });
  });
});

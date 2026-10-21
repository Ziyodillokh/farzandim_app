// Admin — Parvoz Kelajak savollar banki haqiqiy Postgres'da: ruxsat, filtrlar,
// yaratish (ADMIN-xxxxxxxx, takroriy externalId), javob berilgan savolni
// bloklash, nofaol savol tanlanmasligi va statistika (docs/KELAJAK-REJA.md §6).

import { buildKelajakBankRows, KelajakBankRow } from '../../scripts/kelajak/build-bank-migration';
import { resetDb } from './db';
import { createChild, createModerator, createParent, TestChild, TestModerator } from './factories';
import {
  answerScale,
  Call,
  caller,
  INACTIVE_EXTERNAL_IDS,
  seedKelajakBank,
  setChildAge,
  shiftSessionDays,
} from './kelajak-fixtures';
import { createTestApp, TestApp } from './test-app';

type Method = 'GET' | 'POST' | 'PATCH';

interface Row {
  id: string;
  externalId: string;
  category: string;
  ageGroup: string;
  answerType: string;
  active: boolean;
  answerCount: number;
}

const AUDIT_WAIT_MS = 2000;
const AUDIT_POLL_MS = 50;

const question = (patch: object = {}) => ({
  category: 'learning',
  ageGroup: '10-12',
  text: { uz: 'Yangi mavzuni o\'rganish senga yoqadimi?', ru: 'Тебе нравится изучать новые темы?' },
  answerType: 'likert_5',
  options: [1, 2, 3, 4, 5].map((value) => ({ value, label: { uz: `${value}-variant` } })),
  ...patch,
});

describe('Admin Kelajak API', () => {
  let t: TestApp;
  let call: Call;
  let admin: TestModerator;
  const bank: KelajakBankRow[] = buildKelajakBankRows();
  const count = (predicate: (q: KelajakBankRow) => boolean) => bank.filter(predicate).length;

  const api = (method: Method, url: string, payload?: object, token = admin.token) =>
    t.app.inject({
      method,
      url: `/api/admin/kelajak${url}`,
      headers: { authorization: `Bearer ${token}` },
      ...(payload && { payload }),
    });
  const listOf = async (query: string) => {
    const res = await api('GET', `/questions?${query}`);
    expect(res.statusCode).toBe(200);
    return res.json() as { items: Row[]; pagination: { page: number; limit: number; total: number; totalPages: number } };
  };
  const byExternalId = (externalId: string) =>
    t.prisma.kelajakQuestion.findUniqueOrThrow({ where: { externalId } });
  const childOfAge = async (years: number): Promise<TestChild> => {
    const child = await createChild(t.prisma, await createParent(t.prisma));
    await setChildAge(t.prisma, child.childId, { via: 'age', years });
    return child;
  };
  const startSession = async (child: TestChild, type: string) => {
    const res = await call(child.token, 'POST', '/kelajak/sessions', { type });
    expect(res.statusCode).toBe(200);
    return res.json();
  };
  /** Audit yozuvi fonda yoziladi (`void log`) — paydo bo'lishini kutamiz. */
  const auditRows = async (action: string, resourceId: string) => {
    const deadline = Date.now() + AUDIT_WAIT_MS;
    for (;;) {
      const rows = await t.prisma.moderatorAuditLog.findMany({ where: { action, resourceId } });
      if (rows.length > 0 || Date.now() > deadline) return rows;
      await new Promise((resolve) => setTimeout(resolve, AUDIT_POLL_MS));
    }
  };

  beforeAll(async () => {
    t = await createTestApp();
    call = caller(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    await seedKelajakBank(t.prisma);
    admin = await createModerator(t.prisma, ['manage_learning']);
  });

  afterAll(() => t.close());

  it('manage_learning ruxsatisiz — 403, tokensiz — 401', async () => {
    const other = await createModerator(t.prisma, ['view_users']);
    const { id } = await byExternalId('PARVOZ-Q001');
    expect((await api('GET', '/questions', undefined, other.token)).statusCode).toBe(403);
    expect((await api('GET', `/questions/${id}`, undefined, other.token)).statusCode).toBe(403);
    expect((await api('GET', '/stats', undefined, other.token)).statusCode).toBe(403);
    expect((await api('POST', '/questions', question(), other.token)).statusCode).toBe(403);
    expect((await api('PATCH', `/questions/${id}`, { active: false }, other.token)).statusCode).toBe(403);
    const anonymous = await t.app.inject({ method: 'GET', url: '/api/admin/kelajak/questions' });
    expect(anonymous.statusCode).toBe(401);
    expect((await byExternalId('PARVOZ-Q001')).active).toBe(true);
  });

  it('ro\'yxat: sahifalash, filtrlar (kategoriya, yosh, holat, tur) va qidiruv', async () => {
    const all = await listOf('limit=100&page=3');
    expect(all.pagination).toEqual({ page: 3, limit: 100, total: 278, totalPages: 3 });
    expect(all.items).toHaveLength(78);
    expect(all.items.every((q) => q.answerCount === 0)).toBe(true);

    const careerYoung = await listOf('category=career_interest&ageGroup=7-9&limit=100');
    expect(careerYoung.pagination.total).toBe(count((q) => q.category === 'career_interest' && q.ageGroup === '7-9'));
    expect(careerYoung.items.every((q) => q.category === 'career_interest' && q.ageGroup === '7-9')).toBe(true);

    const inactive = await listOf('active=false&limit=100');
    expect(inactive.pagination.total).toBe(8);
    expect(inactive.items.map((q) => q.externalId).sort()).toEqual([...INACTIVE_EXTERNAL_IDS].sort());
    const activeLearning = await listOf('active=true&category=learning&limit=100');
    expect(activeLearning.pagination.total).toBe(count((q) => q.active && q.category === 'learning'));
    expect((await listOf('answerType=text&limit=100')).pagination.total).toBe(12);

    const byId = await listOf('q=q061');
    expect(byId.items.map((q) => q.externalId)).toEqual(['PARVOZ-Q061']);
    const byText = await listOf('q=QIZIQ&limit=100');
    expect(byText.pagination.total).toBe(count((q) => q.text.uz.toLowerCase().includes('qiziq')));
    expect(byText.pagination.total).toBeGreaterThan(0);
    const mixed = await listOf('q=qiziq&ageGroup=16-18&active=true&limit=100');
    expect(mixed.items.every((q) => q.ageGroup === '16-18' && q.active)).toBe(true);
    expect((await listOf('q=%25%25')).pagination.total).toBe(count((q) => q.text.uz.includes('%%')));

    expect((await api('GET', '/questions?limit=101')).statusCode).toBe(400);
    expect((await api('GET', '/questions?active=yes')).statusCode).toBe(400);
    expect((await api('GET', '/questions?category=unknown')).statusCode).toBe(400);
  });

  it('bitta savol: AdminQuestionView; yo\'q — 404', async () => {
    const stored = await byExternalId('PARVOZ-Q156');
    const res = await api('GET', `/questions/${stored.id}`);
    expect(res.statusCode).toBe(200);
    const view = res.json();
    expect(view).toMatchObject({
      id: stored.id,
      externalId: 'PARVOZ-Q156',
      category: stored.category,
      categoryName: { uz: expect.any(String), ru: expect.any(String), en: expect.any(String) },
      ageGroup: stored.ageGroup,
      reverse: true,
      required: true,
      active: true,
      answerCount: 0,
      sourceType: 'parvoz_original',
    });
    expect(Object.keys(view).sort()).toEqual(
      [
        'id', 'externalId', 'category', 'categoryName', 'ageGroup', 'text', 'answerType', 'options', 'scoring',
        'reverse', 'required', 'followUp', 'notes', 'reviewNote', 'sourceType', 'sourceName', 'sourceVersion',
        'active', 'answerCount', 'createdAt', 'updatedAt',
      ].sort(),
    );
    expect((await api('GET', '/questions/00000000-0000-4000-8000-000000000000')).statusCode).toBe(404);
    expect((await api('GET', '/questions/not-a-uuid')).statusCode).toBe(400);
  });

  it('yaratish: ADMIN-xxxxxxxx, parser validatsiyasi, takroriy externalId — 409, audit', async () => {
    const created = await api('POST', '/questions', question());
    expect(created.statusCode).toBe(201);
    const view = created.json();
    expect(view.externalId).toMatch(/^ADMIN-[0-9A-F]{8}$/);
    expect(view).toMatchObject({
      category: 'learning',
      categoryName: { uz: expect.any(String) },
      required: true,
      reverse: false,
      active: true,
      scoring: null,
      sourceType: 'parvoz_admin',
      answerCount: 0,
    });
    expect((await t.prisma.kelajakQuestion.findUniqueOrThrow({ where: { id: view.id } })).createdBy).toBe(admin.id);
    const audit = await auditRows('kelajak.question.create', view.id);
    expect(audit).toHaveLength(1);
    expect(audit[0]).toMatchObject({ moderatorId: admin.id, resourceType: 'kelajak_question' });

    const voice = await api('POST', '/questions', question({ externalId: 'ADMIN-VOICE-1', answerType: 'text', options: [] }));
    expect(voice.statusCode).toBe(201);
    expect(voice.json()).toMatchObject({ externalId: 'ADMIN-VOICE-1', required: false, options: [] });

    const dup = await api('POST', '/questions', question({ externalId: 'ADMIN-VOICE-1' }));
    expect(dup.statusCode).toBe(409);
    expect(dup.json().code).toBe('DUPLICATE_EXTERNAL_ID');
    // PARVOZ- nomlar fazosi bank uchun band (mavjud ham, kelajakdagi ham).
    for (const externalId of ['PARVOZ-Q001', 'PARVOZ-Q279']) {
      const reserved = await api('POST', '/questions', question({ externalId }));
      expect(reserved.statusCode).toBe(400);
      expect(reserved.json()).toMatchObject({ code: 'INVALID_QUESTION', message: expect.stringMatching(/PARVOZ-/) });
    }

    const invalid = [
      question({ externalId: 'kichik-harf' }),
      question({ options: [{ value: 1, label: { uz: 'Bitta' } }] }),
      question({ options: [1, 1].map((value) => ({ value, label: { uz: 'Bir xil' } })) }),
      question({ answerType: 'text' }),
      question({ category: 'career_interest' }),
      question({ category: 'career_interest', scoring: { dimension: 'X' } }),
      question({ text: { uz: '' } }),
      question({ text: { uz: 'x'.repeat(501) } }),
      question({ category: 'child_voice', answerType: 'text', options: [], required: true }),
      question({ scoring: { method: 'simple_sum', min: 1, max: 5, payload: { deep: true } } }),
    ];
    for (const payload of invalid) {
      const res = await api('POST', '/questions', payload);
      expect(res.statusCode).toBe(400);
      expect(res.json().code).toBe('INVALID_QUESTION');
    }
    expect((await api('POST', '/questions', question({ ageGroup: '19-21' }))).statusCode).toBe(400);
    expect((await api('POST', '/questions', question({ id: 'x' }))).statusCode).toBe(400);
    const interest = await api('POST', '/questions', question({
      category: 'career_interest',
      answerType: 'interest_4',
      options: [1, 2, 3, 4].map((value) => ({ value, label: { uz: `${value}` } })),
      scoring: { method: 'dimension_sum', dimension: 'A', min: 1, max: 4 },
    }));
    expect(interest.statusCode).toBe(201);
    expect(await t.prisma.kelajakQuestion.count()).toBe(281);
  });

  it('admin-web shaklidagi payload bilan "Kasbiy qiziqishlar" savoli yaratiladi va savol shu toifaga o\'tkaziladi', async () => {
    // admin-web toCreatePayload() chiqishi bilan bir xil shakl.
    const options = ['Umuman yoqmaydi', 'Unchalik yoqmaydi', 'Yoqadi', 'Juda yoqadi'].map((uz, i) => ({ value: i + 1, label: { uz } }));
    const payload = {
      category: 'career_interest',
      ageGroup: '13-15',
      text: { uz: 'Odamlarga yangi narsa o\'rgatish senga yoqadimi?' },
      answerType: 'interest_4',
      options,
      reverse: false,
      required: true,
      active: true,
      scoring: { method: 'dimension_sum', dimension: 'S', min: 1, max: 4 },
    };
    const created = await api('POST', '/questions', payload);
    expect(created.statusCode).toBe(201);
    expect(created.json()).toMatchObject({ category: 'career_interest', scoring: payload.scoring, required: true });
    const withoutScoring = Object.fromEntries(Object.entries(payload).filter(([key]) => key !== 'scoring'));
    expect((await api('POST', '/questions', withoutScoring)).json().code).toBe('INVALID_QUESTION');

    // Javobsiz savol boshqa toifadan career_interest'ga — scoring bilan.
    const { id } = await byExternalId('PARVOZ-Q062');
    const moved = await api('PATCH', `/questions/${id}`, {
      category: 'career_interest',
      answerType: 'interest_4',
      options,
      scoring: { method: 'dimension_sum', dimension: 'I', min: 1, max: 4 },
    });
    expect(moved.statusCode).toBe(200);
    expect(moved.json()).toMatchObject({ category: 'career_interest', scoring: { dimension: 'I', min: 1, max: 4 } });
    const noDimension = await api('PATCH', `/questions/${(await byExternalId('PARVOZ-Q063')).id}`, { category: 'career_interest' });
    expect(noDimension.json().code).toBe('INVALID_QUESTION');
  });

  it('bugungi ochiq sessiyadagi (javobsiz) savol: yosh / kategoriya / variantlar — 409; matn — ruxsat', async () => {
    const child = await childOfAge(11);
    const session = await startSession(child, 'learning');
    const target = session.questions[0];
    expect((await api('GET', `/questions/${target.id}`)).json().answerCount).toBe(0);
    const otherCategory = target.category === 'learning' ? 'school_quality' : 'learning';
    for (const patch of [{ ageGroup: '16-18' }, { category: otherCategory }, { reverse: true }]) {
      const res = await api('PATCH', `/questions/${target.id}`, patch);
      expect(res.statusCode).toBe(409);
      expect(res.json()).toMatchObject({ code: 'QUESTION_IN_USE', message: expect.stringMatching(/open session/) });
    }
    expect((await api('PATCH', `/questions/${target.id}`, { text: { uz: 'Aniqroq matn?' } })).statusCode).toBe(200);
    // O'tgan kunda qolib ketgan ochiq sessiya bloklamaydi (u yopilgan hisoblanadi).
    await shiftSessionDays(t.prisma, session.id, 1);
    const moved = await api('PATCH', `/questions/${target.id}`, { ageGroup: '16-18' });
    expect(moved.statusCode).toBe(200);
    expect(moved.json().ageGroup).toBe('16-18');
  });

  it('javob berilgan savol: matn tuzatiladi, variantlar / kategoriya / reverse — 409 QUESTION_IN_USE', async () => {
    const child = await childOfAge(11);
    const session = await startSession(child, 'daily');
    // career_interest'ni `text`ga aylantirib bo'lmaydi (RIASEC scoring) — 400 bo'lardi, 409 emas.
    const target = session.questions.find(
      (q: { answerType: string; category: string }) => q.answerType !== 'text' && q.category !== 'career_interest',
    );
    const answer = await call(child.token, 'PUT', `/kelajak/sessions/${session.id}/answers/${target.id}`, {
      value: target.options[0].value,
    });
    expect(answer.statusCode).toBe(200);
    expect((await api('GET', `/questions/${target.id}`)).json().answerCount).toBe(1);
    const before = await t.prisma.kelajakQuestion.findUniqueOrThrow({ where: { id: target.id } });

    const fixed = await api('PATCH', `/questions/${target.id}`, {
      text: { uz: 'Tuzatilgan matn?' },
      notes: 'Imlo tuzatildi',
      followUp: null,
    });
    expect(fixed.statusCode).toBe(200);
    expect(fixed.json()).toMatchObject({ text: { uz: 'Tuzatilgan matn?' }, notes: 'Imlo tuzatildi', answerCount: 1 });
    expect((await auditRows('kelajak.question.update', target.id))[0].details).toMatchObject({
      fields: expect.arrayContaining(['text', 'notes']),
    });

    const relabeled = target.options.map((o: { value: number }) => ({ value: o.value + 1, label: { uz: `${o.value}` } }));
    const locked = [
      { options: relabeled },
      { options: target.options.slice(0, 2) },
      { category: target.category === 'learning' ? 'school_quality' : 'learning' },
      { ageGroup: '16-18' },
      { answerType: 'text', options: [] },
      { reverse: !before.reverse },
    ];
    for (const patch of locked) {
      const res = await api('PATCH', `/questions/${target.id}`, patch);
      expect(res.statusCode).toBe(409);
      expect(res.json()).toMatchObject({ code: 'QUESTION_IN_USE', fields: expect.any(Array) });
    }
    const after = await t.prisma.kelajakQuestion.findUniqueOrThrow({ where: { id: target.id } });
    expect(after).toMatchObject({
      category: before.category,
      ageGroup: before.ageGroup,
      answerType: before.answerType,
      options: before.options,
      reverse: before.reverse,
    });

    // Bir xil variantlar — o'zgarish emas; faollik va majburiylik — ruxsat.
    expect((await api('PATCH', `/questions/${target.id}`, { options: before.options })).statusCode).toBe(200);
    const toggled = await api('PATCH', `/questions/${target.id}`, { active: false, required: false });
    expect(toggled.statusCode).toBe(200);
    expect(toggled.json()).toMatchObject({ active: false, required: false });
    expect((await api('PATCH', `/questions/${target.id}`, { active: null })).statusCode).toBe(400);
    expect((await api('PATCH', `/questions/${target.id}`, { externalId: 'NEW-ID' })).statusCode).toBe(400);
  });

  it('javobsiz nofaol savol: ochiq savolga aylantirib faollashtiriladi (Q090)', async () => {
    const { id } = await byExternalId('PARVOZ-Q090');
    const res = await api('PATCH', `/questions/${id}`, {
      answerType: 'text',
      options: [],
      reviewNote: null,
      active: true,
    });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({
      answerType: 'text',
      options: [],
      scoring: null,
      required: false,
      reviewNote: null,
      active: true,
      answerCount: 0,
    });
    const invalid = await api('PATCH', `/questions/${id}`, { options: [{ value: 1, label: { uz: 'A' } }] });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().code).toBe('INVALID_QUESTION');
  });

  it('nofaol qilingan savol bola sessiyasiga tushmaydi', async () => {
    const voiceIds = (await t.prisma.kelajakQuestion.findMany({
      where: { ageGroup: '7-9', category: 'child_voice', active: true },
      orderBy: { externalId: 'asc' },
    })).map((q) => q.id);
    expect(voiceIds).toHaveLength(3);
    const [hidden, ...kept] = voiceIds;
    const res = await api('PATCH', `/questions/${hidden}`, { active: false });
    expect(res.statusCode).toBe(200);
    expect(res.json().active).toBe(false);

    const session = await startSession(await childOfAge(8), 'voice');
    const ids = session.questions.map((q: { id: string }) => q.id);
    expect(ids).not.toContain(hidden);
    expect([...ids].sort()).toEqual([...kept].sort());
    expect(session.total).toBe(kept.length);
    expect((await listOf('active=false&limit=100')).pagination.total).toBe(9);
  });

  it('statistika: seed bank bilan mos (278 / 270 / 8) va sessiyalar', async () => {
    const empty = (await api('GET', '/stats')).json();
    expect(empty).toMatchObject({ total: 278, active: 270, inactive: 8 });
    expect(empty.needsReview).toBe(count((q) => q.reviewNote !== null));
    expect(empty.needsReview).toBe(11);
    expect(empty.sessions).toEqual({ total: 0, completed: 0, completedLast7Days: 0 });
    for (const c of empty.byCategory) {
      expect(c).toMatchObject({
        total: count((q) => q.category === c.category),
        active: count((q) => q.category === c.category && q.active),
        name: { uz: expect.any(String) },
      });
    }
    expect(empty.byCategory).toHaveLength(12);
    expect(empty.byAgeGroup).toEqual([
      { ageGroup: '7-9', total: 70, active: count((q) => q.ageGroup === '7-9' && q.active) },
      { ageGroup: '10-12', total: 68, active: count((q) => q.ageGroup === '10-12' && q.active) },
      { ageGroup: '13-15', total: 69, active: count((q) => q.ageGroup === '13-15' && q.active) },
      { ageGroup: '16-18', total: 71, active: count((q) => q.ageGroup === '16-18' && q.active) },
    ]);
    const byType = Object.fromEntries(empty.byAnswerType.map((a: { answerType: string; total: number }) => [a.answerType, a.total]));
    expect(byType).toMatchObject({ likert_5: 186, interest_4: 60, career_lab_5: 20, text: 12 });

    const child = await childOfAge(11);
    const lab = await startSession(child, 'career_lab');
    await answerScale(call, child.token, lab);
    expect((await call(child.token, 'POST', `/kelajak/sessions/${lab.id}/complete`)).statusCode).toBe(200);
    await startSession(child, 'daily');
    const after = (await api('GET', '/stats')).json();
    expect(after.sessions).toEqual({ total: 2, completed: 1, completedLast7Days: 1 });
  });
});

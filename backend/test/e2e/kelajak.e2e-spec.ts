// Parvoz Kelajak — bola sessiyalari haqiqiy Postgres'da: qat'iy yosh guruhi,
// kuniga bitta sessiya, javobni o'zgartirish, idempotent yakunlash, kunlik
// aylanish va ochiq matn shifrlanishi (docs/KELAJAK-REJA.md §3–§5, §8).

import { addDays, tashkentDay } from '../../src/common/time/tashkent';
import { KELAJAK_TEST_TYPES, KELAJAK_TESTS, testCategories } from '../../src/modules/kelajak/domain/catalog';
import { resetDb } from './db';
import { createChild, createParent, TestChild, TestParent } from './factories';
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

interface Q {
  id: string;
  externalId: string;
  category: string;
  answerType: string;
  required: boolean;
  options: Array<{ value: number }>;
}

describe('Kelajak API — sessiyalar', () => {
  let t: TestApp;
  let call: Call;
  let parent: TestParent;
  let child: TestChild;

  const start = (token: string, type: string) => call(token, 'POST', '/kelajak/sessions', { type });
  const put = (token: string, sessionId: string, questionId: string, body: object) =>
    call(token, 'PUT', `/kelajak/sessions/${sessionId}/answers/${questionId}`, body);
  const complete = (token: string, sessionId: string) => call(token, 'POST', `/kelajak/sessions/${sessionId}/complete`);
  const startOk = async (type: string, token = child.token) => {
    const res = await start(token, type);
    expect(res.statusCode).toBe(200);
    return res.json();
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

  afterAll(() => t.close());

  describe('yosh guruhi (fallback yo\'q)', () => {
    const groups = [[8, '7-9'], [11, '10-12'], [14, '13-15'], [17, '16-18']] as const;
    const cases = groups.flatMap(([years, group], i) =>
      (['birthDate', 'age'] as const).map((via) => [i + 1, years, group, via] as const),
    );

    it.each(cases)('CASE %i: %i yosh (%s, %s orqali) — har turda faqat shu guruhning faol savollari', async (_n, years, group, via) => {
      await setChildAge(t.prisma, child.childId, { via, years });
      for (const type of KELAJAK_TEST_TYPES) {
        const session = await startOk(type);
        expect(session).toMatchObject({ type, ageGroup: group, status: 'STARTED', day: tashkentDay(), answers: [] });
        const ids: string[] = session.questions.map((q: Q) => q.id);
        expect(ids.length).toBeGreaterThan(0);
        expect(session.total).toBe(ids.length);
        const rows = await t.prisma.kelajakQuestion.findMany({ where: { id: { in: ids } } });
        expect(rows).toHaveLength(ids.length);
        const allowed: string[] = testCategories(KELAJAK_TESTS[type]);
        for (const row of rows) {
          expect(row.ageGroup).toBe(group);
          expect(row.active).toBe(true);
          expect(INACTIVE_EXTERNAL_IDS).not.toContain(row.externalId);
          expect(allowed).toContain(row.category);
        }
        const stored = await t.prisma.kelajakSession.findUniqueOrThrow({ where: { id: session.id } });
        expect(stored).toMatchObject({ ageGroup: group, questionIds: ids });
      }
    });

    it('yosh ham, tug\'ilgan sana ham yo\'q — 409 AGE_REQUIRED, sessiya yaratilmaydi', async () => {
      await setChildAge(t.prisma, child.childId, { via: 'none' });
      const res = await start(child.token, 'daily');
      expect(res.statusCode).toBe(409);
      expect(res.json()).toMatchObject({ statusCode: 409, code: 'AGE_REQUIRED' });
      expect(await t.prisma.kelajakSession.count()).toBe(0);
    });

    it.each([[6, 'age'], [19, 'age'], [6, 'birthDate'], [19, 'birthDate']] as const)(
      '%i yosh (%s) — 409 AGE_OUT_OF_RANGE',
      async (years, via) => {
        await setChildAge(t.prisma, child.childId, { via, years });
        const res = await start(child.token, 'career');
        expect(res.statusCode).toBe(409);
        expect(res.json().code).toBe('AGE_OUT_OF_RANGE');
        expect(await t.prisma.kelajakSession.count()).toBe(0);
      },
    );

    it('noma\'lum tur — 400 UNKNOWN_TYPE; ortiqcha maydon — 400', async () => {
      const unknown = await start(child.token, 'astrology');
      expect(unknown.statusCode).toBe(400);
      expect(unknown.json().code).toBe('UNKNOWN_TYPE');
      const extra = await call(child.token, 'POST', '/kelajak/sessions', { type: 'daily', grade: 5 });
      expect(extra.statusCode).toBe(400);
    });
  });

  describe('asosiy oqim', () => {
    it('start → javob → javobni o\'zgartirish (orqaga) → complete → natija saqlanadi', async () => {
      const session = await startOk('daily');
      expect(session.total).toBe(KELAJAK_TESTS.daily.count);
      const [first, ...rest] = session.questions as Q[];

      const values = first.options.map((o) => o.value);
      const [low, high] = [Math.min(...values), Math.max(...values)];
      const answered = await put(child.token, session.id, first.id, { value: low });
      expect(answered.statusCode).toBe(200);
      expect(answered.json()).toEqual({ questionId: first.id, value: low, text: null, sessionStatus: 'IN_PROGRESS', answeredCount: 1 });
      const changed = (await put(child.token, session.id, first.id, { value: high })).json();
      expect(changed).toMatchObject({ value: high, answeredCount: 1 });
      const rows = await t.prisma.kelajakAnswer.findMany({ where: { sessionId: session.id } });
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ questionId: first.id, value: high, textEnc: null, position: 0 });

      await answerScale(call, child.token, { id: session.id, questions: rest });
      const res = await complete(child.token, session.id);
      expect(res.statusCode).toBe(200);
      const done = res.json();
      expect(done).toMatchObject({ id: session.id, status: 'COMPLETED', answeredCount: session.total });
      expect(done.completedAt).not.toBeNull();
      expect(done.result).toMatchObject({ answered: session.total, total: session.total });
      expect(done.result.disclaimer.uz.length).toBeGreaterThan(0);
      expect(done.result.insights.next.length).toBeGreaterThan(0);
      const categories = done.result.categories.map((c: { category: string }) => c.category);
      expect(categories).not.toContain('wellbeing');
      expect(categories).not.toContain('safety');

      const stored = await t.prisma.kelajakSession.findUniqueOrThrow({ where: { id: session.id } });
      expect(stored).toMatchObject({ status: 'COMPLETED', scoringVersion: 1 });
      expect(stored.result).toMatchObject({ version: 1, scores: { categories: expect.any(Array) }, insightCodes: expect.any(Object) });
    });

    it('ikki marta (parallel) complete — bir xil natija, bitta sessiya va har savolga bitta javob', async () => {
      const session = await startOk('learning');
      await answerScale(call, child.token, session);
      const results = await Promise.all(Array.from({ length: 4 }, () => complete(child.token, session.id)));
      for (const r of results) expect(r.statusCode).toBe(200);
      const [firstResult, ...others] = results.map((r) => r.json());
      for (const other of others) expect(other).toEqual(firstResult);
      expect((await complete(child.token, session.id)).json()).toEqual(firstResult);

      expect(await t.prisma.kelajakSession.count({ where: { childId: child.childId, type: 'learning' } })).toBe(1);
      const answers = await t.prisma.kelajakAnswer.findMany({ where: { sessionId: session.id } });
      expect(answers).toHaveLength(session.total);
      expect(new Set(answers.map((a) => a.questionId)).size).toBe(session.total);

      // Yakunlangandan keyin qayta POST (refresh) — o'sha sessiya, natijasi bilan.
      const again = await startOk('learning');
      expect(again).toEqual(firstResult);
    });

    it('yarim yo\'lda qayta POST — o\'sha sessiya, berilgan javoblari bilan', async () => {
      const session = await startOk('self');
      const picked = (session.questions as Q[]).slice(0, 3);
      for (const q of picked) expect((await put(child.token, session.id, q.id, { value: 2 })).statusCode).toBe(200);
      const again = await startOk('self');
      expect(again.id).toBe(session.id);
      expect(again.status).toBe('IN_PROGRESS');
      expect(again.questions.map((q: Q) => q.id)).toEqual(session.questions.map((q: Q) => q.id));
      expect(again.answers).toEqual(picked.map((q) => ({ questionId: q.id, value: 2, text: null })));
      const viewed = (await call(child.token, 'GET', `/kelajak/sessions/${session.id}`)).json();
      expect(viewed).toEqual(again);
    });

    it('majburiy savol javobsiz — 400 UNANSWERED (+remaining)', async () => {
      const session = await startOk('wellbeing');
      const [missing, ...rest] = session.questions as Q[];
      await answerScale(call, child.token, { id: session.id, questions: rest });
      const res = await complete(child.token, session.id);
      expect(res.statusCode).toBe(400);
      expect(res.json()).toMatchObject({ code: 'UNANSWERED', remaining: [missing.id] });
      expect((await t.prisma.kelajakSession.findUniqueOrThrow({ where: { id: session.id } })).status).toBe('IN_PROGRESS');
    });

    it('ixtiyoriy savollar (career_lab, ochiq matn) o\'tkazib yuboriladi, lekin bo\'sh test yakunlanmaydi', async () => {
      const lab = await startOk('career_lab');
      expect(lab.questions.every((q: Q) => q.answerType === 'career_lab_5' && q.required === false)).toBe(true);
      expect(lab.questions.every((q: object) => !('followUp' in q))).toBe(true);
      const empty = await complete(child.token, lab.id);
      expect(empty.statusCode).toBe(400);
      expect(empty.json()).toMatchObject({ code: 'UNANSWERED', remaining: lab.questions.map((q: Q) => q.id) });
      expect((await put(child.token, lab.id, lab.questions[0].id, { value: 4 })).statusCode).toBe(200);
      const labDone = await complete(child.token, lab.id);
      expect(labDone.statusCode).toBe(200);
      expect(labDone.json()).toMatchObject({ status: 'COMPLETED', answeredCount: 1 });

      const voice = await startOk('voice');
      expect(voice.questions.every((q: Q & { maxLength: number }) => q.answerType === 'text' && q.maxLength === 1000)).toBe(true);
      await put(child.token, voice.id, voice.questions[0].id, { text: 'Robot yasashni yoqtiraman' });
      expect((await complete(child.token, voice.id)).json()).toMatchObject({ status: 'COMPLETED', answeredCount: 1 });
    });

    it('noto\'g\'ri javob — 400 (INVALID_ANSWER / QUESTION_NOT_IN_SESSION / validatsiya)', async () => {
      const session = await startOk('learning');
      const q: Q = session.questions[0];
      const expectCode = async (body: object, code: string | null) => {
        const res = await put(child.token, session.id, q.id, body);
        expect(res.statusCode).toBe(400);
        if (code) expect(res.json().code).toBe(code);
      };
      await expectCode({ value: 9 }, 'INVALID_ANSWER');
      await expectCode({ value: 0 }, 'INVALID_ANSWER');
      await expectCode({ text: 'ha' }, 'INVALID_ANSWER');
      await expectCode({}, 'INVALID_ANSWER');
      await expectCode({ value: 2.5 }, null);
      await expectCode({ value: 3, extra: true }, null);

      const foreign = await t.prisma.kelajakQuestion.findFirstOrThrow({ where: { id: { notIn: session.questions.map((x: Q) => x.id) } } });
      const notIn = await put(child.token, session.id, foreign.id, { value: 3 });
      expect(notIn.statusCode).toBe(400);
      expect(notIn.json().code).toBe('QUESTION_NOT_IN_SESSION');

      const voice = await startOk('voice');
      const open: Q = voice.questions[0];
      const valueOnText = await put(child.token, voice.id, open.id, { value: 1 });
      expect(valueOnText.json().code).toBe('INVALID_ANSWER');
      expect((await put(child.token, voice.id, open.id, { text: 'a'.repeat(1001) })).statusCode).toBe(400);
      expect(await t.prisma.kelajakAnswer.count()).toBe(0);
    });

    it('yakunlangandan keyin javob — 409 SESSION_CLOSED; begona bolaning sessiyasi — 404', async () => {
      const session = await startOk('career_lab');
      await put(child.token, session.id, session.questions[0].id, { value: 5 });
      expect((await complete(child.token, session.id)).statusCode).toBe(200);
      const closed = await put(child.token, session.id, session.questions[0].id, { value: 4 });
      expect(closed.statusCode).toBe(409);
      expect(closed.json().code).toBe('SESSION_CLOSED');

      const other = await createChild(t.prisma, parent, { name: 'Malika' });
      await setChildAge(t.prisma, other.childId, { via: 'age', years: 11 });
      expect((await call(other.token, 'GET', `/kelajak/sessions/${session.id}`)).statusCode).toBe(404);
      expect((await put(other.token, session.id, session.questions[0].id, { value: 4 })).statusCode).toBe(404);
      expect((await complete(other.token, session.id)).statusCode).toBe(404);
      // Ota-ona tokeni bola yo'llariga kira olmaydi.
      expect((await call(parent.token, 'GET', '/kelajak/overview')).statusCode).toBe(403);
    });
  });

  describe('kunlar va tanlov', () => {
    it('ertasi kuni kunlik savollar takrorlanmaydi (ko\'rilmaganlari bor ekan)', async () => {
      const yesterday = await startOk('daily');
      await answerScale(call, child.token, yesterday);
      expect((await complete(child.token, yesterday.id)).statusCode).toBe(200);
      await shiftSessionDays(t.prisma, yesterday.id, 1);

      const today = await startOk('daily');
      expect(today.id).not.toBe(yesterday.id);
      expect(today.day).toBe(tashkentDay());
      const seen = new Set(yesterday.questions.map((q: Q) => q.id));
      expect(today.questions.filter((q: Q) => seen.has(q.id))).toEqual([]);
      expect(today.total).toBe(KELAJAK_TESTS.daily.count);
    });

    it('o\'tgan kundagi ochiq sessiya ABANDONED bo\'ladi va yopiq', async () => {
      const stale = await startOk('daily');
      await put(child.token, stale.id, stale.questions[0].id, { value: 3 });
      await shiftSessionDays(t.prisma, stale.id, 1);

      const fresh = await startOk('daily');
      expect(fresh.id).not.toBe(stale.id);
      expect(fresh).toMatchObject({ status: 'STARTED', day: tashkentDay() });
      const closed = await t.prisma.kelajakSession.findUniqueOrThrow({ where: { id: stale.id } });
      expect(closed).toMatchObject({ status: 'ABANDONED', day: addDays(tashkentDay(), -1) });
      expect((await complete(child.token, stale.id)).json().code).toBe('SESSION_CLOSED');
      expect((await put(child.token, stale.id, stale.questions[0].id, { value: 4 })).statusCode).toBe(409);
    });

    it('o\'tgan kundagi ochiq sessiyaga POSTsiz javob / yakunlash — 409 SESSION_CLOSED va ABANDONED', async () => {
      const stale = await startOk('daily');
      await answerScale(call, child.token, stale);
      await shiftSessionDays(t.prisma, stale.id, 1);

      const late = await put(child.token, stale.id, stale.questions[0].id, { value: 3 });
      expect(late.statusCode).toBe(409);
      expect(late.json().code).toBe('SESSION_CLOSED');
      expect((await t.prisma.kelajakSession.findUniqueOrThrow({ where: { id: stale.id } })).status).toBe('ABANDONED');
      expect((await complete(child.token, stale.id)).json().code).toBe('SESSION_CLOSED');

      const other = await startOk('learning');
      await shiftSessionDays(t.prisma, other.id, 1);
      const viewed = (await call(child.token, 'GET', `/kelajak/sessions/${other.id}`)).json();
      expect(viewed.status).toBe('ABANDONED');
      expect(await t.prisma.kelajakSession.count({ where: { status: 'COMPLETED' } })).toBe(0);
    });

    it('parallel POST (ikki marta bosish) — bitta sessiya, hammasi bir xil id', async () => {
      const results = await Promise.all(Array.from({ length: 4 }, () => start(child.token, 'daily')));
      for (const r of results) expect(r.statusCode).toBe(200);
      expect(new Set(results.map((r) => r.json().id)).size).toBe(1);
      expect(await t.prisma.kelajakSession.count({ where: { childId: child.childId, type: 'daily' } })).toBe(1);
    });

    it('kun ichida yosh guruhi o\'zgarsa — ochiq sessiya ABANDONED, yangi guruh savollari; yakunlangani saqlanadi', async () => {
      const learning = await startOk('learning');
      await answerScale(call, child.token, learning);
      expect((await complete(child.token, learning.id)).statusCode).toBe(200);
      const open = await startOk('daily');
      await put(child.token, open.id, open.questions[0].id, { value: open.questions[0].options[0].value });

      await setChildAge(t.prisma, child.childId, { via: 'birthDate', years: 14 });
      const fresh = await startOk('daily');
      expect(fresh.id).not.toBe(open.id);
      expect(fresh).toMatchObject({ ageGroup: '13-15', status: 'STARTED', answers: [] });
      const rows = await t.prisma.kelajakQuestion.findMany({ where: { id: { in: fresh.questions.map((q: Q) => q.id) } } });
      expect(rows.length).toBe(fresh.questions.length);
      expect(rows.every((r) => r.ageGroup === '13-15')).toBe(true);
      expect((await t.prisma.kelajakSession.findUniqueOrThrow({ where: { id: open.id } })).status).toBe('ABANDONED');

      // Yakunlangan sessiya o'z guruhi bilan qoladi (natija o'zgarmaydi).
      const kept = await startOk('learning');
      expect(kept).toMatchObject({ id: learning.id, ageGroup: '10-12', status: 'COMPLETED' });
    });

    it('savol boshqa yosh guruhiga o\'tkazilgan bo\'lsa, eski sessiyadagi javob — 400 QUESTION_NOT_IN_SESSION', async () => {
      const session = await startOk('learning');
      const [moved] = session.questions as Q[];
      await t.prisma.kelajakQuestion.update({ where: { id: moved.id }, data: { ageGroup: '16-18' } });
      const res = await put(child.token, session.id, moved.id, { value: moved.options[0].value });
      expect(res.statusCode).toBe(400);
      expect(res.json().code).toBe('QUESTION_NOT_IN_SESSION');
      expect(await t.prisma.kelajakAnswer.count({ where: { sessionId: session.id } })).toBe(0);
    });

    it('nofaol savol (Q061, Q090 ...) tanlanmaydi; savol qolmasa — 404 NO_QUESTIONS', async () => {
      await setChildAge(t.prisma, child.childId, { via: 'age', years: 8 });
      const categories = testCategories(KELAJAK_TESTS.learning);
      const keep = await t.prisma.kelajakQuestion.findMany({
        where: { ageGroup: '7-9', active: true, category: { in: categories } },
        orderBy: { externalId: 'asc' },
        take: 2,
      });
      await t.prisma.kelajakQuestion.updateMany({
        where: { ageGroup: '7-9', category: { in: categories }, id: { notIn: keep.map((q) => q.id) } },
        data: { active: false },
      });
      const session = await startOk('learning');
      expect(session.questions.map((q: Q) => q.id).sort()).toEqual(keep.map((q) => q.id).sort());
      expect(session.questions.map((q: Q) => q.externalId)).not.toContain('PARVOZ-Q061');

      await t.prisma.kelajakQuestion.updateMany({ where: { ageGroup: '7-9', category: 'child_voice' }, data: { active: false } });
      const none = await start(child.token, 'voice');
      expect(none.statusCode).toBe(404);
      expect(none.json().code).toBe('NO_QUESTIONS');
    });
  });

  describe('ochiq matn', () => {
    const PLAIN = 'Men kelajakda shifokor bo\'lmoqchiman';

    it('shifrlangan saqlanadi, bolaga qaytadi, "" o\'chiradi, ota-onaga chiqmaydi', async () => {
      const voice = await startOk('voice');
      const q: Q = voice.questions[0];
      const saved = await put(child.token, voice.id, q.id, { text: `  ${PLAIN}  ` });
      expect(saved.json()).toMatchObject({ text: PLAIN, value: null, sessionStatus: 'IN_PROGRESS', answeredCount: 1 });

      const row = await t.prisma.kelajakAnswer.findFirstOrThrow({ where: { sessionId: voice.id, questionId: q.id } });
      expect(row.value).toBeNull();
      expect(row.textEnc).not.toBeNull();
      expect(row.textEnc!.startsWith('v1.')).toBe(true);
      expect(row.textEnc).not.toContain(PLAIN);
      expect(row.textEnc).not.toContain('shifokor');

      const cleared = await put(child.token, voice.id, q.id, { text: '' });
      expect(cleared.json()).toMatchObject({ text: null, value: null, answeredCount: 0 });
      expect(await t.prisma.kelajakAnswer.count({ where: { sessionId: voice.id } })).toBe(0);
      await put(child.token, voice.id, q.id, { text: PLAIN });

      const viewed = (await call(child.token, 'GET', `/kelajak/sessions/${voice.id}`)).json();
      expect(viewed.answers).toEqual([{ questionId: q.id, value: null, text: PLAIN }]);
      expect((await complete(child.token, voice.id)).statusCode).toBe(200);
      expect(JSON.stringify((await call(child.token, 'GET', `/kelajak/sessions/${voice.id}`)).json().result)).not.toContain(PLAIN);

      const summary = await call(parent.token, 'GET', `/children/${child.childId}/kelajak/summary`);
      expect(summary.statusCode).toBe(200);
      const raw = summary.body;
      expect(raw).not.toContain(PLAIN);
      expect(raw).not.toContain('shifokor');
      expect(raw).not.toContain(row.textEnc!);
      expect(raw).not.toMatch(/text_?enc/i);
    });
  });
});

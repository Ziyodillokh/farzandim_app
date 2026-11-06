// Bola ovozi — murojaat yozishmasi (bola <-> psixolog): idempotent yaratish, bosqichlar,
// "ochildi" yozuvi (faqat care.individual, bir marta, poygada ham), xodim javobi + neutral push,
// o'qilmaganlar, limitlar, tenant izolyatsiyasi.

import { SchoolCryptoService } from '../../src/school/common/school-crypto.service';
import { resetDb } from './db';
import { createTestApp, TestApp } from './test-app';
import { addFcmToken, AssessWorld, buildWorld, careChild, careStaff, createRequest, psychologist, uuid } from './school-care-fixtures';

describe('Bola ovozi — murojaat yozishmasi', () => {
  let t: TestApp;
  let w: AssessWorld;
  let staff: ReturnType<typeof careStaff>;
  let child: ReturnType<typeof careChild>;

  beforeAll(async () => {
    t = await createTestApp();
    staff = careStaff(t);
    child = careChild(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    w = await buildWorld(t);
  });

  afterEach(() => jest.restoreAllMocks());
  afterAll(() => t.close());

  const kid = () => w.kids7a[0]!;

  it('yaratish: batafsil javob, birinchi bola xabari, matn shifrlangan, default mavzu va shoshilinchlik', async () => {
    const res = await child(kid(), 'POST', '/requests', { message: 'Sinfdoshlarim meni masxara qilishyapti' });
    expect(res.statusCode).toBe(201);
    const body = res.json();
    expect(body).toEqual({
      id: expect.any(String),
      urgency: 'NORMAL',
      status: 'NEW',
      stage: 'RECEIVED',
      createdAt: expect.any(String),
      openedAt: null,
      repliedAt: null,
      resolvedAt: null,
      meetingAt: null,
      // Sozlama yo'q: maktabdagi yagona faol psixolog mas'ul hisoblanadi (contact bilan bir xil).
      handler: { name: 'PSYCHOLOGIST xodim', isDeputy: false },
      messages: [{ id: expect.any(String), author: 'CHILD', authorName: null, text: 'Sinfdoshlarim meni masxara qilishyapti', createdAt: expect.any(String) }],
    });
    const stored = await t.prisma.schoolCareRequest.findFirstOrThrow();
    expect(stored.topic).toBe('OTHER');
    expect(stored.messageEnc).not.toContain('masxara');
    const message = await t.prisma.schoolCareMessage.findFirstOrThrow();
    expect(message.bodyEnc).toMatch(/^v1\./);
    expect(message.bodyEnc).not.toContain('masxara');
    expect(stored.lastMessageAt).not.toBeNull();
  });

  it('clientRequestId: takror yuborish dublikat yaratmaydi va kunlik limitni yemaydi', async () => {
    const clientRequestId = uuid();
    const first = (await child(kid(), 'POST', '/requests', { message: 'Birinchi', clientRequestId })).json();
    const replay = await child(kid(), 'POST', '/requests', { message: 'Birinchi', clientRequestId });
    expect(replay.statusCode).toBe(201);
    expect(replay.json().id).toBe(first.id);
    expect(await t.prisma.schoolCareRequest.count()).toBe(1);
    expect(await t.prisma.schoolCareMessage.count()).toBe(1);

    for (let i = 0; i < 4; i += 1) await createRequest(t, kid(), { message: `Xabar ${i}` });
    expect((await child(kid(), 'POST', '/requests', { message: 'Oltinchi' })).statusCode).toBe(429);
    // Limitga yetgan bo'lsa ham takror — o'sha murojaat (yangi emas).
    expect((await child(kid(), 'POST', '/requests', { message: 'Birinchi', clientRequestId })).json().id).toBe(first.id);
    // Boshqa bolada bir xil clientRequestId alohida murojaat.
    const other = (await child(w.kids7a[1]!, 'POST', '/requests', { message: 'Boshqa', clientRequestId })).json();
    expect(other.id).not.toBe(first.id);
    expect(await t.prisma.schoolCareRequest.count()).toBe(6);
  });

  it('parallel bir xil clientRequestId: bitta murojaat', async () => {
    const clientRequestId = uuid();
    const results = await Promise.all(Array.from({ length: 4 }, () => child(kid(), 'POST', '/requests', { message: 'Parallel', clientRequestId })));
    expect(new Set(results.map((r) => r.json().id)).size).toBe(1);
    expect(await t.prisma.schoolCareRequest.count()).toBe(1);
  });

  it('tekshiruvlar: matn 1..1000, noma\'lum mavzu / shoshilinchlik, noto\'g\'ri clientRequestId', async () => {
    const post = (body: unknown) => child(kid(), 'POST', '/requests', body);
    expect((await post({ message: '' })).statusCode).toBe(400);
    expect((await post({ message: 'x'.repeat(1001) })).json().message).toBe('message: errors.form.tooLong');
    expect((await post({ message: 'a', topic: 'NOPE' })).statusCode).toBe(400);
    expect((await post({ message: 'a', urgency: 'HIGH' })).statusCode).toBe(400);
    expect((await post({ message: 'a', clientRequestId: 'not-a-uuid' })).statusCode).toBe(400);
    expect((await post({ message: 'x'.repeat(1000) })).statusCode).toBe(201);
    expect(await t.prisma.schoolCareRequest.count()).toBe(1);
  });

  it('ro\'yxat matnsiz; detail xodim xabarlarini o\'qilgan qiladi; ichki eslatmalar bolaga ko\'rinmaydi', async () => {
    const created = await createRequest(t, kid(), { message: 'Maxfiy matn', urgency: 'URGENT', topic: 'BULLYING' });
    await staff(w.psych, 'POST', `/requests/${created.id}/notes`, { text: 'ICHKI ESLATMA: ehtiyot bo\'ling' });
    await staff(w.psych, 'POST', `/requests/${created.id}/messages`, { text: 'Salom, men senga yordam beraman' });
    await staff(w.psych, 'POST', `/requests/${created.id}/messages`, { text: 'Ertaga gaplashamizmi?' });

    const list = await child(kid(), 'GET', '/requests');
    expect(list.json()).toEqual([
      {
        id: created.id,
        topic: 'BULLYING',
        urgency: 'URGENT',
        status: 'IN_PROGRESS',
        stage: 'REPLIED',
        createdAt: expect.any(String),
        meetingAt: null,
        lastMessageAt: expect.any(String),
        unread: 2,
      },
    ]);
    expect(list.body).not.toContain('Maxfiy matn');
    expect(list.body).not.toContain('Salom');

    const detail = await child(kid(), 'GET', `/requests/${created.id}`);
    expect(detail.statusCode).toBe(200);
    expect(detail.json().messages.map((m: { author: string; text: string }) => [m.author, m.text])).toEqual([
      ['CHILD', 'Maxfiy matn'],
      ['STAFF', 'Salom, men senga yordam beraman'],
      ['STAFF', 'Ertaga gaplashamizmi?'],
    ]);
    expect(detail.body).not.toContain('ICHKI ESLATMA');
    expect(detail.body).not.toMatch(/notes|byStaffId|studentId|schoolId/);
    expect((await child(kid(), 'GET', '/requests')).json()[0].unread).toBe(0);
  });

  it('bosqichlar: RECEIVED -> OPENED -> REPLIED -> CLOSED; qayta ochilganda resolvedAt tozalanadi', async () => {
    const { id } = await createRequest(t, kid());
    const stage = async () => (await child(kid(), 'GET', `/requests/${id}`)).json();
    expect(await stage()).toMatchObject({ stage: 'RECEIVED', openedAt: null });

    expect((await staff(w.psych, 'GET', `/requests/${id}`)).statusCode).toBe(200);
    expect(await stage()).toMatchObject({ stage: 'OPENED', openedAt: expect.any(String), repliedAt: null });

    await staff(w.psych, 'POST', `/requests/${id}/messages`, { text: 'Javob' });
    expect(await stage()).toMatchObject({ stage: 'REPLIED', status: 'IN_PROGRESS', repliedAt: expect.any(String) });

    const resolved = (await staff(w.psych, 'PUT', `/requests/${id}/status`, { status: 'RESOLVED' })).json();
    expect(resolved.resolvedAt).toEqual(expect.any(String));
    expect(await stage()).toMatchObject({ stage: 'CLOSED', status: 'RESOLVED', resolvedAt: resolved.resolvedAt });
    // Qayta RESOLVED bosilsa asl vaqt saqlanadi.
    expect((await staff(w.psych, 'PUT', `/requests/${id}/status`, { status: 'RESOLVED' })).json().resolvedAt).toBe(resolved.resolvedAt);

    const reopened = (await staff(w.psych, 'PUT', `/requests/${id}/status`, { status: 'IN_PROGRESS' })).json();
    expect(reopened.resolvedAt).toBeNull();
    expect(await stage()).toMatchObject({ stage: 'REPLIED', resolvedAt: null });
  });

  describe('xodim: birinchi ochgan', () => {
    it('faqat care.individual: direktor ko\'rolmaydi va yozuv qoldirmaydi', async () => {
      const { id } = await createRequest(t, kid());
      expect((await staff(w.director, 'GET', `/requests/${id}`)).statusCode).toBe(403);
      expect((await staff(w.homeroom, 'GET', `/requests/${id}`)).statusCode).toBe(403);
      expect((await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } })).openedAt).toBeNull();
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'care.request.open' } })).toBe(0);
    });

    it('birinchi psixolog yoziladi, ikkinchisi o\'zgartirmaydi; audit bitta, matnsiz', async () => {
      const other = await psychologist(t, w.schoolId, 'psix2', 'Ikkinchi Psixolog');
      const { id } = await createRequest(t, kid(), { message: 'Yashirin so\'z' });
      const first = (await staff(w.psych, 'GET', `/requests/${id}`)).json();
      expect(first.openedAt).toEqual(expect.any(String));
      expect(first.openedBy).toEqual({ id: w.psych.staffId, name: 'PSYCHOLOGIST xodim' });
      const second = (await staff(other, 'GET', `/requests/${id}`)).json();
      expect(second.openedAt).toBe(first.openedAt);
      expect(second.openedBy).toEqual(first.openedBy);

      const audit = await t.prisma.schoolAuditLog.findMany({ where: { action: 'care.request.open' } });
      expect(audit).toHaveLength(1);
      expect(audit[0]).toMatchObject({ module: 'CARE', entityId: null, actorId: w.psych.staffId });
      expect(JSON.stringify(audit)).not.toMatch(/Yashirin|Alfa|7-A/);
    });

    it('parallel ko\'rishlarda ham aniq bitta g\'olib va bitta audit', async () => {
      const others = await Promise.all([1, 2, 3].map((n) => psychologist(t, w.schoolId, `psix-race-${n}`, `Poyga ${n}`)));
      const { id } = await createRequest(t, kid());
      const responses = await Promise.all([w.psych, ...others, w.psych, ...others].map((who) => staff(who, 'GET', `/requests/${id}`)));
      expect(responses.every((r) => r.statusCode === 200)).toBe(true);

      const stored = await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } });
      expect(stored.openedByStaffId).not.toBeNull();
      expect(new Set(responses.map((r) => r.json().openedBy.id))).toEqual(new Set([stored.openedByStaffId]));
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'care.request.open' } })).toBe(1);
    });

    it('eslatma / suhbat vaqti ham birinchi ochish hisoblanadi (ko\'rmasdan tegilgan murojaat)', async () => {
      const { id } = await createRequest(t, kid());
      await staff(w.psych, 'POST', `/requests/${id}/notes`, { text: 'Eslatma' });
      const stored = await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } });
      expect(stored.openedByStaffId).toBe(w.psych.staffId);
      expect(await t.prisma.schoolAuditLog.count({ where: { action: 'care.request.open' } })).toBe(1);
    });

    it('detail va ro\'yxat qatorlari yangi maydonlarni beradi', async () => {
      const { id } = await createRequest(t, kid(), { message: 'Savol 1' });
      await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Savol 2' });
      const list = (await staff(w.psych, 'GET', '/requests')).json();
      expect(list.items[0]).toMatchObject({ id, openedAt: null, repliedAt: null, unreadFromChild: 2, assignedTo: null, escalatedAt: null });

      const detail = (await staff(w.psych, 'GET', `/requests/${id}`)).json();
      expect(detail).toMatchObject({ resolvedAt: null, repliedAt: null, escalatedAt: null, assignedTo: null, unreadFromChild: 0, studentName: 'Alfaov Alfa0', className: '7-A' });
      expect(detail.messages.map((m: { author: string; text: string; authorName: unknown }) => [m.author, m.text, m.authorName])).toEqual([
        ['CHILD', 'Savol 1', null],
        ['CHILD', 'Savol 2', null],
      ]);
      expect((await staff(w.psych, 'GET', '/requests')).json().items[0]).toMatchObject({ openedAt: expect.any(String), unreadFromChild: 0 });
    });
  });

  describe('xodim javobi', () => {
    it('xabar, repliedAt, lastMessageAt, NEW -> IN_PROGRESS; audit matnsiz', async () => {
      const { id } = await createRequest(t, kid());
      const res = await staff(w.psych, 'POST', `/requests/${id}/messages`, { text: 'Menda sirli javob bor' });
      expect(res.statusCode).toBe(201);
      expect(res.json()).toEqual({ id: expect.any(String), author: 'STAFF', authorName: 'PSYCHOLOGIST xodim', text: 'Menda sirli javob bor', createdAt: expect.any(String) });

      const stored = await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } });
      expect(stored).toMatchObject({ status: 'IN_PROGRESS', repliedAt: expect.any(Date), lastMessageAt: expect.any(Date), openedByStaffId: w.psych.staffId });
      const message = await t.prisma.schoolCareMessage.findFirstOrThrow({ where: { author: 'STAFF' } });
      expect(message.bodyEnc).not.toContain('sirli');
      expect(t.app.get(SchoolCryptoService).decrypt(message.bodyEnc)).toBe('Menda sirli javob bor');

      const audit = await t.prisma.schoolAuditLog.findMany({ where: { module: 'CARE' } });
      expect(audit.map((a) => a.action).sort()).toEqual(['care.request.open', 'care.request.reply']);
      expect(JSON.stringify(audit)).not.toContain('sirli');
      expect(audit.every((a) => a.entityId === null)).toBe(true);

      const firstReply = stored.repliedAt!.getTime();
      await staff(w.psych, 'POST', `/requests/${id}/messages`, { text: 'Ikkinchi' });
      expect((await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } })).repliedAt!.getTime()).toBe(firstReply);
    });

    it('tekshiruvlar va ruxsat: 1..2000 belgi; direktor / sinf rahbari 403; yopiq murojaat 409', async () => {
      const { id } = await createRequest(t, kid());
      const reply = (who: typeof w.psych, body: unknown) => staff(who, 'POST', `/requests/${id}/messages`, body);
      expect((await reply(w.psych, { text: '' })).statusCode).toBe(400);
      expect((await reply(w.psych, { text: 'x'.repeat(2001) })).json().message).toBe('text: errors.form.tooLong');
      expect((await reply(w.psych, { text: 'x'.repeat(2000) })).statusCode).toBe(201);
      expect((await reply(w.director, { text: 'a' })).statusCode).toBe(403);
      expect((await reply(w.homeroom, { text: 'a' })).statusCode).toBe(403);
      await staff(w.psych, 'PUT', `/requests/${id}/status`, { status: 'RESOLVED' });
      expect((await reply(w.psych, { text: 'kech qoldi' })).statusCode).toBe(409);
      expect(await t.prisma.schoolCareMessage.count({ where: { author: 'STAFF' } })).toBe(1);
    });

    it('bolaga NEYTRAL push: matn ham, "psixolog" so\'zi ham yo\'q; til bola tiliga mos', async () => {
      await addFcmToken(t, kid());
      await addFcmToken(t, w.kids7b[0]!);
      const mine = await createRequest(t, kid());
      await staff(w.psych, 'POST', `/requests/${mine.id}/messages`, { text: 'Mutlaqo maxfiy javob matni' });

      const pushes = t.fcm.pushesTo(kid().userId);
      expect(pushes).toEqual([{ title: 'Parvoz', body: 'Sizga yangi xabar keldi', data: { type: 'CARE_MESSAGE', requestId: mine.id } }]);
      expect(JSON.stringify(pushes)).not.toMatch(/maxfiy|psixolog|psycholog|психолог/i);
      expect(t.fcm.sent).toHaveLength(1);

      // Rus tilidagi bola (7-B) — ruscha neytral matn.
      const ru = await createRequest(t, w.kids7b[0]!);
      await staff(w.psych, 'POST', `/requests/${ru.id}/messages`, { text: 'Ответ' });
      expect(t.fcm.pushesTo(w.kids7b[0]!.userId)).toEqual([{ title: 'Parvoz', body: 'Вам новое сообщение', data: { type: 'CARE_MESSAGE', requestId: ru.id } }]);
    });

    it('qurilma tokeni yo\'q bola: push o\'tkazib yuboriladi, javob muvaffaqiyatli', async () => {
      const { id } = await createRequest(t, kid());
      const res = await staff(w.psych, 'POST', `/requests/${id}/messages`, { text: 'Javob' });
      expect(res.statusCode).toBe(201);
      expect(t.fcm.sent).toHaveLength(0);
    });

    it('FCM yiqilsa ham javob yoziladi', async () => {
      await addFcmToken(t, kid());
      jest.spyOn(t.fcm, 'sendPushToUser').mockRejectedValue(new Error('fcm down'));
      const { id } = await createRequest(t, kid());

      const res = await staff(w.psych, 'POST', `/requests/${id}/messages`, { text: 'Javob' });

      expect(res.statusCode).toBe(201);
      expect(await t.prisma.schoolCareMessage.count({ where: { author: 'STAFF' } })).toBe(1);
    });
  });

  describe('bola xabarlari', () => {
    it('xabar qo\'shish, clientMessageId takrori o\'sha xabarni qaytaradi', async () => {
      const { id } = await createRequest(t, kid());
      const clientMessageId = uuid();
      const first = await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Qo\'shimcha', clientMessageId });
      expect(first.statusCode).toBe(201);
      expect(first.json()).toEqual({ id: expect.any(String), author: 'CHILD', authorName: null, text: 'Qo\'shimcha', createdAt: expect.any(String) });
      const replay = await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Qo\'shimcha', clientMessageId });
      expect(replay.statusCode).toBe(201);
      expect(replay.json().id).toBe(first.json().id);
      expect(await t.prisma.schoolCareMessage.count({ where: { author: 'CHILD' } })).toBe(2);
      expect((await child(kid(), 'POST', `/requests/${id}/messages`, { text: '' })).statusCode).toBe(400);
      expect((await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'x', clientMessageId: 'bad' })).statusCode).toBe(400);
    });

    it('yopilgan murojaat — 409 REQUEST_CLOSED (takror esa o\'sha xabar)', async () => {
      const { id } = await createRequest(t, kid());
      const clientMessageId = uuid();
      const sent = await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Oldin', clientMessageId });
      await staff(w.psych, 'PUT', `/requests/${id}/status`, { status: 'RESOLVED' });
      const closed = await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Keyin' });
      expect(closed.statusCode).toBe(409);
      expect(closed.json().code).toBe('REQUEST_CLOSED');
      expect((await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Oldin', clientMessageId })).json().id).toBe(sent.json().id);
    });

    it('kuniga 30 ta xabar; 31-si — 429 (boshlang\'ich xabarlar ham hisobda)', async () => {
      const { id } = await createRequest(t, kid());
      for (let i = 0; i < 29; i += 1) {
        expect((await child(kid(), 'POST', `/requests/${id}/messages`, { text: `Xabar ${i}` })).statusCode).toBe(201);
      }
      const limited = await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Ortiqcha' });
      expect(limited.statusCode).toBe(429);
      expect(limited.json().code).toBe('TOO_MANY_REQUESTS');
      // Boshqa bolaning limiti alohida.
      const other = await createRequest(t, w.kids7a[1]!);
      expect((await child(w.kids7a[1]!, 'POST', `/requests/${other.id}/messages`, { text: 'Salom' })).statusCode).toBe(201);
    });

    it('xabar murojaatning lastMessageAt ini yangilaydi va xodim uchun o\'qilmagan bo\'ladi', async () => {
      const { id } = await createRequest(t, kid());
      const before = (await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } })).lastMessageAt!;
      await new Promise((resolve) => setTimeout(resolve, 15));
      await child(kid(), 'POST', `/requests/${id}/messages`, { text: 'Yana' });
      const after = (await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } })).lastMessageAt!;
      expect(after.getTime()).toBeGreaterThan(before.getTime());
      expect((await staff(w.psych, 'GET', '/requests')).json().items[0].unreadFromChild).toBe(2);
    });
  });

  describe('izolyatsiya', () => {
    it('boshqa bolaning murojaati bolaga 404 (o\'qish va yozish); ro\'yxatda ham ko\'rinmaydi', async () => {
      const mine = await createRequest(t, kid(), { message: 'Mening' });
      const theirs = await createRequest(t, w.kids7a[1]!, { message: 'Boshqaning' });
      expect((await child(kid(), 'GET', `/requests/${theirs.id}`)).statusCode).toBe(404);
      expect((await child(kid(), 'POST', `/requests/${theirs.id}/messages`, { text: 'Hujum' })).statusCode).toBe(404);
      expect((await child(kid(), 'GET', '/requests')).json().map((r: { id: string }) => r.id)).toEqual([mine.id]);
      expect(await t.prisma.schoolCareMessage.count({ where: { author: 'CHILD', requestId: theirs.id } })).toBe(1);
      // Bola o'qigani boshqa bolaning xodim xabarlarini o'qilgan qilmaydi.
      await staff(w.psych, 'POST', `/requests/${theirs.id}/messages`, { text: 'Javob' });
      await child(kid(), 'GET', `/requests/${theirs.id}`);
      expect((await child(w.kids7a[1]!, 'GET', '/requests')).json()[0].unread).toBe(1);
      expect((await child(kid(), 'GET', `/requests/${uuid()}`)).statusCode).toBe(404);
      expect((await child(kid(), 'GET', '/requests/not-a-uuid')).statusCode).toBe(400);
    });

    it('boshqa maktab: xodim 404, boshqa maktab bolasi 404; ulanmagan bola NOT_ENROLLED', async () => {
      const other = await buildWorld(t, 'other-school');
      const { id } = await createRequest(t, kid());
      expect((await staff(other.psych, 'GET', `/requests/${id}`)).statusCode).toBe(404);
      expect((await staff(other.psych, 'POST', `/requests/${id}/messages`, { text: 'Hujum' })).statusCode).toBe(404);
      expect((await staff(other.psych, 'PUT', `/requests/${id}/status`, { status: 'RESOLVED' })).statusCode).toBe(404);
      expect((await staff(other.psych, 'GET', '/requests')).json().items).toEqual([]);
      expect((await child(other.kids7a[0]!, 'GET', `/requests/${id}`)).statusCode).toBe(404);
      expect((await child(other.kids7a[0]!, 'POST', `/requests/${id}/messages`, { text: 'Hujum' })).statusCode).toBe(404);
      const stored = await t.prisma.schoolCareRequest.findUniqueOrThrow({ where: { id } });
      expect(stored).toMatchObject({ openedAt: null, status: 'NEW' });
      expect(await t.prisma.schoolCareMessage.count()).toBe(1);

      const loner = await t.prisma.user.create({ data: { role: 'CHILD' } });
      const { consumerToken } = await import('./factories');
      const ghost = { token: consumerToken(loner.id, 'CHILD') };
      const parent = await t.prisma.user.create({ data: { role: 'PARENT', email: `p-${uuid()}@e2e.test`, name: 'P' } });
      await t.prisma.child.create({ data: { parentId: parent.id, childUserId: loner.id, name: 'Yolg\'iz', age: 10, familyCode: `fc-${uuid().slice(0, 8)}`, pairedAt: new Date() } });
      for (const [method, url, body] of [
        ['GET', `/requests/${id}`, undefined],
        ['POST', `/requests/${id}/messages`, { text: 'a' }],
        ['POST', '/requests', { message: 'a' }],
        ['GET', '/contact', undefined],
      ] as const) {
        const res = await child(ghost, method, url, body);
        expect([res.statusCode, res.json().code]).toEqual([404, 'NOT_ENROLLED']);
      }
      expect((await child(ghost, 'GET', '/requests')).json()).toEqual([]);
    });

    it('ota-ona tokeni 403, tokensiz 401', async () => {
      const { id } = await createRequest(t, kid());
      const parent = await t.prisma.user.findFirstOrThrow({ where: { role: 'PARENT' } });
      const { consumerToken } = await import('./factories');
      const asParent = await t.app.inject({ method: 'GET', url: `/api/child/school/care/requests/${id}`, headers: { authorization: `Bearer ${consumerToken(parent.id, 'PARENT')}` } });
      expect(asParent.statusCode).toBe(403);
      expect((await t.app.inject({ method: 'GET', url: `/api/child/school/care/requests/${id}` })).statusCode).toBe(401);
    });
  });

  it('eski (xabarsiz) murojaat: yozishma messageEnc dan "initial" xabar bilan tuziladi', async () => {
    const student = kid();
    const legacy = await t.prisma.schoolCareRequest.create({
      data: {
        schoolId: w.schoolId,
        studentId: student.studentId,
        classId: w.classes.c7a,
        topic: 'FAMILY',
        urgency: 'NORMAL',
        messageEnc: t.app.get(SchoolCryptoService).encrypt('Eski murojaat matni'),
      },
    });
    const detail = (await child(student, 'GET', `/requests/${legacy.id}`)).json();
    expect(detail).toMatchObject({ id: legacy.id, stage: 'RECEIVED', handler: { name: 'PSYCHOLOGIST xodim', isDeputy: false } });
    expect(detail.messages).toEqual([{ id: 'initial', author: 'CHILD', authorName: null, text: 'Eski murojaat matni', createdAt: legacy.createdAt.toISOString() }]);
    expect((await child(student, 'GET', '/requests')).json()[0]).toMatchObject({ id: legacy.id, lastMessageAt: legacy.createdAt.toISOString(), unread: 0 });

    const staffView = (await staff(w.psych, 'GET', `/requests/${legacy.id}`)).json();
    expect(staffView.messages).toEqual([{ id: 'initial', author: 'CHILD', authorName: null, text: 'Eski murojaat matni', createdAt: legacy.createdAt.toISOString() }]);
    // Javob yozilgach yozishma: eski murojaat uchun sintetik xabar yo'qoladi (haqiqiy xabarlar bor)
    // — shuning uchun javob yozilganda boshlang'ich xabar ham saqlanadi.
    await staff(w.psych, 'POST', `/requests/${legacy.id}/messages`, { text: 'Javob' });
    const after = (await child(student, 'GET', `/requests/${legacy.id}`)).json();
    expect(after.messages.map((m: { text: string }) => m.text)).toEqual(['Eski murojaat matni', 'Javob']);
  });
});

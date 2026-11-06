// Men (I07): bildirishnoma sozlamalari (GET/PUT, bola va ota-ona) va oila xabari push'lari
// (familyMessages / hideText). SOS va qo'ng'iroqlar bu sozlamalardan ta'sirlanmaydi.

import { resetDb } from './db';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { appReq } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const DEFAULTS = {
  studyNudge: true,
  healthNudge: true,
  contentReminder: true,
  quietFrom: null,
  quietTo: null,
  homeworkReminder: true,
  schoolAnnouncements: true,
  familyMessages: true,
  dailyReminder: true,
  dailyReminderTime: '18:00',
  hideText: false,
};

describe('Men notify: bildirishnoma sozlamalari', () => {
  let t: TestApp;
  let parent: TestParent;
  let child: TestChild;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    t.fcm.reset();
    parent = await createParent(t.prisma, { name: 'Dilnoza' });
    child = await createChild(t.prisma, parent, { name: 'Aziz' });
  });

  afterAll(() => t.close());

  const prefsUrl = (id = child.childId) => `/children/${id}/notification-preferences`;
  const get = (token: string, id?: string) => appReq(t, token, 'GET', prefsUrl(id));
  const put = (token: string, body: object, id?: string) => appReq(t, token, 'PUT', prefsUrl(id), body);

  describe('GET / PUT', () => {
    it('returns the documented defaults (child and parent) when nothing was saved', async () => {
      const asChild = await get(child.token);
      const asParent = await get(parent.token);

      expect(asChild.statusCode).toBe(200);
      expect(asChild.json()).toEqual(DEFAULTS);
      expect(asParent.json()).toEqual(DEFAULTS);
    });

    it('lets the child update a subset and keeps the rest', async () => {
      const res = await put(child.token, { hideText: true, dailyReminderTime: '07:45', familyMessages: false });

      expect(res.statusCode).toBe(200);
      expect(res.json()).toEqual({ ...DEFAULTS, hideText: true, dailyReminderTime: '07:45', familyMessages: false });
      const again = await get(parent.token);
      expect(again.json()).toEqual({ ...DEFAULTS, hideText: true, dailyReminderTime: '07:45', familyMessages: false });
    });

    it('lets the parent update the new switches too (and the old ones keep working)', async () => {
      const res = await put(parent.token, { homeworkReminder: false, schoolAnnouncements: false, dailyReminder: false, studyNudge: false, quietFrom: '22:00', quietTo: '08:00' });

      expect(res.statusCode).toBe(200);
      expect(res.json()).toMatchObject({ homeworkReminder: false, schoolAnnouncements: false, dailyReminder: false, studyNudge: false, quietFrom: '22:00', quietTo: '08:00' });
      expect(res.json().familyMessages).toBe(true);
    });

    it('accepts the boundaries 06:00 and 21:00', async () => {
      expect((await put(child.token, { dailyReminderTime: '06:00' })).json().dailyReminderTime).toBe('06:00');
      expect((await put(child.token, { dailyReminderTime: '21:00' })).json().dailyReminderTime).toBe('21:00');
    });

    it.each(['05:59', '21:01', '6:00', '18:60', '24:00', 'noon', '', null, 1800])(
      'rejects dailyReminderTime %p with 400 VALIDATION',
      async (value) => {
        const res = await put(child.token, { dailyReminderTime: value, hideText: true });

        expect(res.statusCode).toBe(400);
        expect(res.json()).toMatchObject({ statusCode: 400, code: 'VALIDATION' });
        // Hech narsa saqlanmadi (hideText ham).
        expect((await get(child.token)).json()).toEqual(DEFAULTS);
      },
    );

    it('rejects non-boolean switches, null switches and unknown fields with 400', async () => {
      expect((await put(child.token, { hideText: 'yes' })).statusCode).toBe(400);
      expect((await put(child.token, { familyMessages: null })).statusCode).toBe(400);
      expect((await put(child.token, { isAdmin: true })).statusCode).toBe(400);
    });

    it('keeps the response free of internal bookkeeping columns', async () => {
      await put(child.token, { hideText: true });

      expect(Object.keys((await get(child.token)).json()).sort()).toEqual(Object.keys(DEFAULTS).sort());
    });

    it('forbids a stranger and 404s an unknown child; requires a token', async () => {
      const stranger = await createParent(t.prisma);

      expect((await get(stranger.token)).statusCode).toBe(403);
      expect((await put(stranger.token, { hideText: false })).statusCode).toBe(403);
      expect((await get(parent.token, '00000000-0000-0000-0000-000000000000')).statusCode).toBe(404);
      expect((await t.app.inject({ method: 'GET', url: `/api${prefsUrl()}` })).statusCode).toBe(401);
    });
  });

  describe('family message push to the child', () => {
    const sendText = (token: string, receiverId: string, text = 'Kechqurun uyda bo\'laman') =>
      appReq(t, token, 'POST', '/voice-messages/text', { receiverId, text });

    it('is neutral when hideText is on: "Parvoz" / "Yangi xabar", no sender, no content', async () => {
      await put(child.token, { hideText: true });

      const res = await sendText(parent.token, child.userId);

      expect(res.statusCode).toBe(201);
      const pushes = t.fcm.pushesTo(child.userId);
      expect(pushes).toHaveLength(1);
      expect(pushes[0]).toEqual({ title: 'Parvoz', body: 'Yangi xabar', data: { type: 'voice', messageId: res.json().id } });
      expect(JSON.stringify(pushes)).not.toContain('Dilnoza');
      expect(JSON.stringify(pushes)).not.toContain('uyda');
    });

    it('is neutral in Russian for a Russian-speaking child', async () => {
      await t.prisma.user.update({ where: { id: child.userId }, data: { language: 'ru' } });
      await put(child.token, { hideText: true });

      await sendText(parent.token, child.userId);

      expect(t.fcm.pushesTo(child.userId)[0]).toMatchObject({ title: 'Parvoz', body: 'Новое сообщение' });
    });

    it('shows sender and text by default (hideText is off)', async () => {
      const res = await sendText(parent.token, child.userId, 'Salom, o\'g\'lim');

      expect(t.fcm.pushesTo(child.userId)[0]).toEqual({
        title: 'Dilnoza',
        body: "Salom, o'g'lim",
        data: { type: 'voice', messageId: res.json().id, senderId: parent.userId },
      });
    });

    it('sends no push when family messages are switched off, but still stores the message and notification', async () => {
      await put(child.token, { familyMessages: false });

      const res = await sendText(parent.token, child.userId);

      expect(res.statusCode).toBe(201);
      expect(t.fcm.pushesTo(child.userId)).toHaveLength(0);
      expect(await t.prisma.voiceMessage.count({ where: { id: res.json().id } })).toBe(1);
      expect(await t.prisma.notification.count({ where: { childId: child.childId } })).toBe(1);
    });

    it('applies to media messages as well', async () => {
      await put(child.token, { familyMessages: false });
      const boundary = '----e2e';
      const payload = Buffer.concat([
        Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="receiverId"\r\n\r\n${child.userId}\r\n`),
        Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="a.jpg"\r\nContent-Type: image/jpeg\r\n\r\n`),
        Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ]);

      const res = await t.app.inject({
        method: 'POST',
        url: '/api/voice-messages/media',
        headers: { authorization: `Bearer ${parent.token}`, 'content-type': `multipart/form-data; boundary=${boundary}` },
        payload,
      });

      expect(res.statusCode).toBe(201);
      expect(t.fcm.pushesTo(child.userId)).toHaveLength(0);
    });

    it('does not apply the child preferences to messages the child sends to the parent', async () => {
      await put(child.token, { familyMessages: false, hideText: true });
      await t.prisma.user.update({ where: { id: child.userId }, data: { name: 'Aziz' } });

      await sendText(child.token, parent.userId, 'Dars tugadi');

      expect(t.fcm.pushesTo(parent.userId)).toEqual([
        expect.objectContaining({ title: 'Aziz', body: 'Dars tugadi', data: expect.objectContaining({ type: 'voice' }) }),
      ]);
    });

    it('only affects the child whose preferences changed', async () => {
      const other = await createChild(t.prisma, parent, { name: 'Zilola' });
      await put(child.token, { familyMessages: false });

      await sendText(parent.token, other.userId);

      expect(t.fcm.pushesTo(other.userId)).toHaveLength(1);
      expect(t.fcm.pushesTo(child.userId)).toHaveLength(0);
    });
  });
});

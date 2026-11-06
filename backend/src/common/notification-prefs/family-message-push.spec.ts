import { buildFamilyMessagePush } from './family-message-push';
import { FamilyMessagePushService } from './family-message-push.service';

const shown = { title: 'Ona', body: "Kechqurun uyda bo'laman" };
const data = { type: 'voice' as const, messageId: 'm-1', senderId: 'parent-1' };

describe('buildFamilyMessagePush', () => {
  it('sends nothing when family messages are switched off', () => {
    const payload = buildFamilyMessagePush({ prefs: { familyMessages: false, hideText: true }, lang: 'uz', shown, data });

    expect(payload).toBeNull();
  });

  it('is neutral in Uzbek when text is hidden: no sender, no content', () => {
    const payload = buildFamilyMessagePush({ prefs: { familyMessages: true, hideText: true }, lang: 'uz', shown, data });

    expect(payload?.title).toBe('Parvoz');
    expect(payload?.body).toBe('Yangi xabar');
    expect(JSON.stringify(payload)).not.toContain('Ona');
    expect(JSON.stringify(payload)).not.toContain('uyda');
    expect(payload?.data).toEqual({ type: 'voice', messageId: 'm-1' });
  });

  it('is neutral in Russian and English too', () => {
    const prefs = { familyMessages: true, hideText: true };

    expect(buildFamilyMessagePush({ prefs, lang: 'ru', shown, data })?.body).toBe('Новое сообщение');
    expect(buildFamilyMessagePush({ prefs, lang: 'en', shown, data })?.body).toBe('New message');
  });

  it('shows the sender and a snippet when text is not hidden', () => {
    const payload = buildFamilyMessagePush({ prefs: { familyMessages: true, hideText: false }, lang: 'uz', shown, data });

    expect(payload).toEqual({ ...shown, data });
  });
});

describe('FamilyMessagePushService', () => {
  const link = { childId: 'child-1', childUserId: 'child-user' };

  function setup(prefs: Partial<{ familyMessages: boolean; hideText: boolean }> = {}) {
    const fcm = {
      sendPushToUser: jest.fn().mockResolvedValue({ sent: 1, failed: 0, invalidTokens: [] }),
      getUserLang: jest.fn().mockResolvedValue('uz'),
    };
    const prefsService = { forChild: jest.fn().mockResolvedValue({ familyMessages: true, hideText: false, ...prefs }) };
    const service = new FamilyMessagePushService(fcm as never, prefsService as never);
    return { fcm, prefsService, service };
  }

  it('keeps the usual push (sender and text) for the child by default (hideText is off)', async () => {
    const { fcm, service } = setup();

    await service.send({ link, receiverId: 'child-user', shown, data });

    expect(fcm.sendPushToUser).toHaveBeenCalledWith('child-user', { ...shown, data });
  });

  it('sends the neutral push to the child when hideText is on', async () => {
    const { fcm, service } = setup({ hideText: true });

    await service.send({ link, receiverId: 'child-user', shown, data });

    expect(fcm.sendPushToUser).toHaveBeenCalledWith('child-user', {
      title: 'Parvoz',
      body: 'Yangi xabar',
      data: { type: 'voice', messageId: 'm-1' },
    });
  });

  it('sends nothing to the child when family messages are off', async () => {
    const { fcm, service } = setup({ familyMessages: false });

    await service.send({ link, receiverId: 'child-user', shown, data });

    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('never applies the child preferences to the parent (the parent still gets the full push)', async () => {
    const { fcm, prefsService, service } = setup({ familyMessages: false });

    await service.send({ link, receiverId: 'parent-1', shown, data });

    expect(prefsService.forChild).not.toHaveBeenCalled();
    expect(fcm.sendPushToUser).toHaveBeenCalledWith('parent-1', { ...shown, data });
  });

  it('swallows push failures so the message flow is never broken', async () => {
    const { fcm, service } = setup();
    fcm.sendPushToUser.mockRejectedValue(new Error('fcm down'));

    await expect(service.send({ link, receiverId: 'child-user', shown, data })).resolves.toBeUndefined();
  });

  it('swallows preference lookup failures too', async () => {
    const { prefsService, fcm, service } = setup();
    prefsService.forChild.mockRejectedValue(new Error('db down'));

    await expect(service.send({ link, receiverId: 'child-user', shown, data })).resolves.toBeUndefined();
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });
});

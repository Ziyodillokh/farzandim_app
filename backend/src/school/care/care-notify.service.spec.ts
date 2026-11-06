import { CareNotifyService } from './care-notify.service';

function setup(options: { tokens?: number; sendFails?: boolean; lang?: 'uz' | 'ru' | 'en'; sent?: number } = {}) {
  const prisma = { fcmToken: { count: jest.fn().mockResolvedValue(options.tokens ?? 1) } };
  const fcm = {
    getUserLang: jest.fn().mockResolvedValue(options.lang ?? 'uz'),
    sendPushToUser: options.sendFails
      ? jest.fn().mockRejectedValue(new Error('fcm down'))
      : jest.fn().mockResolvedValue({ sent: options.sent ?? 1, failed: 0, invalidTokens: [] }),
  };
  return { service: new CareNotifyService(prisma as never, fcm as never), prisma, fcm };
}

describe('CareNotifyService.notifyChildOfReply', () => {
  it('sends the neutral uz text with only type and request id in data', async () => {
    const { service, fcm } = setup();

    await service.notifyChildOfReply('child-user', 'req-1');

    expect(fcm.sendPushToUser).toHaveBeenCalledWith('child-user', {
      title: 'Parvoz',
      body: 'Sizga yangi xabar keldi',
      data: { type: 'CARE_MESSAGE', requestId: 'req-1' },
    });
  });

  it('uses the Russian neutral text for a Russian-language child', async () => {
    const { service, fcm } = setup({ lang: 'ru' });

    await service.notifyChildOfReply('child-user', 'req-1');

    expect(fcm.sendPushToUser.mock.calls[0]![1].body).toBe('Вам новое сообщение');
  });

  it('never mentions the psychologist or any content', async () => {
    const { service, fcm } = setup();

    await service.notifyChildOfReply('child-user', 'req-1');

    expect(JSON.stringify(fcm.sendPushToUser.mock.calls[0]![1]).toLowerCase()).not.toMatch(/psixolog|психолог|psycholog/);
  });

  it('skips silently when the child has no device tokens', async () => {
    const { service, fcm } = setup({ tokens: 0 });

    await expect(service.notifyChildOfReply('child-user', 'req-1')).resolves.toBeUndefined();
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('skips when the child has no user account at all', async () => {
    const { service, fcm } = setup();

    await expect(service.notifyChildOfReply(null, 'req-1')).resolves.toBeUndefined();
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('never throws when FCM fails', async () => {
    const { service } = setup({ sendFails: true });

    await expect(service.notifyChildOfReply('child-user', 'req-1')).resolves.toBeUndefined();
  });

  it('tolerates FCM accepting nothing', async () => {
    const { service } = setup({ sent: 0 });

    await expect(service.notifyChildOfReply('child-user', 'req-1')).resolves.toBeUndefined();
  });
});

import { CareNotifyService } from './care-notify.service';

function setup(options: { tokens?: number; sendFails?: boolean; lang?: 'uz' | 'ru' | 'en'; sent?: number } = {}) {
  const prisma = { fcmToken: { count: jest.fn().mockResolvedValue(options.tokens ?? 1) } };
  const fcm = {
    getUserLang: jest.fn().mockResolvedValue(options.lang ?? 'uz'),
    sendPushToUser: options.sendFails
      ? jest.fn().mockRejectedValue(new Error('fcm down'))
      : jest.fn().mockResolvedValue({ sent: options.sent ?? 1, failed: 0, invalidTokens: [] }),
  };
  return { service: new CareNotifyService(prisma as never, fcm as never, {} as never), prisma, fcm };
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

describe('CareNotifyService.surveyActivated', () => {
  function surveySetup(students: unknown[] = [{ childId: 'ch-1', child: { childUserId: 'cu-1' } }]) {
    const prisma = { schoolStudent: { findMany: jest.fn().mockResolvedValue(students) } };
    const childPush = { sendOnce: jest.fn(async (recipients: unknown[]) => recipients.length) };
    const service = new CareNotifyService(prisma as never, {} as never, childPush as never);
    return { service, prisma, childPush };
  }

  it('pushes the neutral survey text once per child of the survey classes', async () => {
    const { service, prisma, childPush } = surveySetup();

    const delivered = await service.surveyActivated('s-1', 'sv-1', ['c-5a', 'c-6b']);

    expect(delivered).toBe(1);
    expect(prisma.schoolStudent.findMany.mock.calls[0][0].where).toMatchObject({
      schoolId: 's-1',
      archived: false,
      classId: { in: ['c-5a', 'c-6b'] },
      child: { childUserId: { not: null } },
      linkCorrections: { none: { status: 'OPEN' } },
    });
    const [recipients, kind, key, build] = childPush.sendOnce.mock.calls[0] as unknown as [unknown, string, string, (l: 'uz') => unknown];
    expect(recipients).toEqual([{ childId: 'ch-1', childUserId: 'cu-1' }]);
    expect([kind, key]).toEqual(['CARE_SURVEY', 'sv-1']);
    expect(build('uz')).toEqual({ title: 'Parvoz', body: 'Maktabdan yangi soʻrovnoma', data: { type: 'CARE_SURVEY', surveyId: 'sv-1' } });
  });

  it('no classes in the age groups — no query, no push', async () => {
    const { service, prisma, childPush } = surveySetup();

    expect(await service.surveyActivated('s-1', 'sv-1', [])).toBe(0);
    expect(prisma.schoolStudent.findMany).not.toHaveBeenCalled();
    expect(childPush.sendOnce).not.toHaveBeenCalled();
  });

  it('a database error never fails the activation', async () => {
    const { service, prisma } = surveySetup();
    prisma.schoolStudent.findMany.mockRejectedValue(new Error('db down'));

    await expect(service.surveyActivated('s-1', 'sv-1', ['c-5a'])).resolves.toBe(0);
  });
});

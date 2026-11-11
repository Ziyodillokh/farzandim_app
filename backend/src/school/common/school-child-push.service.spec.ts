import { PushPayload } from '../../common/fcm/fcm.service';
import { SchoolChildPushService, toRecipients } from './school-child-push.service';

const build = (): PushPayload => ({ title: 'Parvoz', body: 'Neytral', data: { type: 'T' } });

describe('SchoolChildPushService', () => {
  function setup(opts: { claimed?: string[]; failFor?: string } = {}) {
    const fcm = {
      getUserLang: jest.fn().mockResolvedValue('uz'),
      sendPushToUser: jest.fn(async (userId: string) => {
        if (userId === opts.failFor) throw new Error('fcm down');
        return { sent: 1 };
      }),
    };
    const dedupe = { claim: jest.fn(async (ids: string[]) => opts.claimed ?? ids) };
    return { fcm, dedupe, service: new SchoolChildPushService(fcm as never, dedupe as never) };
  }

  const recipients = [
    { childId: 'ch-1', childUserId: 'cu-1' },
    { childId: 'ch-2', childUserId: 'cu-2' },
    { childId: 'ch-1', childUserId: 'cu-1' },
  ];

  it('claims each child once and pushes only to the claimed ones', async () => {
    const { service, fcm, dedupe } = setup({ claimed: ['ch-2'] });

    const delivered = await service.sendOnce(recipients, 'KIND', 'ref-1', build);

    expect(dedupe.claim).toHaveBeenCalledWith(['ch-1', 'ch-2'], 'KIND', 'ref-1');
    expect(fcm.sendPushToUser.mock.calls.map((c) => c[0])).toEqual(['cu-2']);
    expect(delivered).toBe(1);
  });

  it('a failing push is counted as not delivered and never throws', async () => {
    const { service } = setup({ failFor: 'cu-1' });

    await expect(service.sendOnce(recipients, 'KIND', 'ref-1', build)).resolves.toBe(1);
  });

  it('a failing claim returns 0 and sends nothing', async () => {
    const { service, fcm, dedupe } = setup();
    dedupe.claim.mockRejectedValue(new Error('db down'));

    await expect(service.sendOnce(recipients, 'KIND', 'ref-1', build)).resolves.toBe(0);
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('nobody to notify — no database call', async () => {
    const { service, dedupe } = setup();

    expect(await service.sendOnce([], 'KIND', 'ref-1', build)).toBe(0);
    expect(dedupe.claim).not.toHaveBeenCalled();
  });
});

describe('toRecipients', () => {
  it('keeps app-linked children once', () => {
    expect(
      toRecipients([
        { childId: 'ch-1', child: { childUserId: 'cu-1' } },
        { childId: 'ch-1', child: { childUserId: 'cu-1' } },
        { childId: 'ch-2', child: { childUserId: null } },
        { childId: null, child: null },
      ]),
    ).toEqual([{ childId: 'ch-1', childUserId: 'cu-1' }]);
  });
});

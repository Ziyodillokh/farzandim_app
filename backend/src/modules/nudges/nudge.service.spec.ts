import { NudgeService } from './nudge.service';

// 13:00 UTC = 18:00 Tashkent (2026-11-06, juma)
const AT_1800 = new Date('2026-11-06T13:00:00Z');

describe('NudgeService hourly tick', () => {
  it('no longer sends the study nudge at the old fixed 16:00 (it moved to DailyReminderService)', async () => {
    const prisma = { child: { findMany: jest.fn() } };
    const service = new NudgeService(prisma as never, {} as never);

    const res = await service.tick(new Date('2026-11-06T11:00:00Z')); // 16:00 Tashkent

    expect(res).toEqual({ kind: null, sent: 0 });
    expect(prisma.child.findMany).not.toHaveBeenCalled();
  });

  it('still runs the health nudge at 18:00', async () => {
    const prisma = { child: { findMany: jest.fn().mockResolvedValue([]) } };
    const service = new NudgeService(prisma as never, {} as never);

    const res = await service.tick(AT_1800);

    expect(res.kind).toBe('HEALTH');
  });

  it('sends no content reminder on Saturday 11:00 (audio/video hidden)', async () => {
    const prisma = { child: { findMany: jest.fn().mockResolvedValue([]) } };
    const service = new NudgeService(prisma as never, {} as never);

    const res = await service.tick(new Date('2026-11-07T06:00:00Z')); // shanba 11:00 Tashkent

    expect(res).toEqual({ kind: null, sent: 0 });
    expect(prisma.child.findMany).not.toHaveBeenCalled();
  });

  it('skips a child in quiet hours for the health nudge', async () => {
    const child = {
      id: 'ch-1',
      name: 'Bola',
      childUserId: 'cu-1',
      notificationPreference: {
        healthNudge: true,
        contentReminder: true,
        quietFrom: '17:30',
        quietTo: '19:00',
        lastHealthNudgeAt: null,
        lastContentReminderAt: null,
      },
    };
    const prisma = { child: { findMany: jest.fn().mockResolvedValue([child]) } };
    const fcm = { sendPushToUser: jest.fn(), getUserLang: jest.fn() };
    const service = new NudgeService(prisma as never, fcm as never);

    const res = await service.tick(AT_1800);

    expect(res.sent).toBe(0);
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });
});

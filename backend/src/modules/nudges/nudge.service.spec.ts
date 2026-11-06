import { NudgeService } from './nudge.service';

// 13:00 UTC = 18:00 Tashkent (2026-11-06, juma)
const AT_1800 = new Date('2026-11-06T13:00:00Z');

type Pref = {
  studyNudge: boolean;
  healthNudge: boolean;
  contentReminder: boolean;
  dailyReminder: boolean;
  dailyReminderTime: string;
  quietFrom: string | null;
  quietTo: string | null;
  lastStudyNudgeAt: Date | null;
  lastHealthNudgeAt: Date | null;
  lastContentReminderAt: Date | null;
};

const pref = (over: Partial<Pref> = {}): Pref => ({
  studyNudge: true,
  healthNudge: true,
  contentReminder: true,
  dailyReminder: true,
  dailyReminderTime: '18:00',
  quietFrom: null,
  quietTo: null,
  lastStudyNudgeAt: null,
  lastHealthNudgeAt: null,
  lastContentReminderAt: null,
  ...over,
});

const child = (n: number, p: Pref | null) => ({ id: `ch-${n}`, name: `Bola ${n}`, childUserId: `cu-${n}`, notificationPreference: p });

describe('NudgeService daily reminder', () => {
  function setup(opts: { children?: unknown[]; olympiad?: number; learning?: number } = {}) {
    const prisma = {
      child: { findMany: jest.fn().mockResolvedValue(opts.children ?? []) },
      olympiadAttempt: { count: jest.fn().mockResolvedValue(opts.olympiad ?? 0) },
      learningAttempt: { count: jest.fn().mockResolvedValue(opts.learning ?? 0) },
      childStepDaily: { findFirst: jest.fn().mockResolvedValue(null) },
      notification: { create: jest.fn().mockResolvedValue({}) },
      notificationPreference: { upsert: jest.fn().mockResolvedValue({}) },
    };
    const fcm = {
      getUserLang: jest.fn().mockResolvedValue('uz'),
      sendPushToUser: jest.fn().mockResolvedValue({ sent: 1, failed: 0, invalidTokens: [] }),
    };
    return { prisma, fcm, service: new NudgeService(prisma as never, fcm as never) };
  }

  it('sends the study nudge at the configured time to a child who has not studied today', async () => {
    const { service, fcm } = setup({ children: [child(1, pref())] });

    const sent = await service.tickDailyReminder(AT_1800);

    expect(sent).toBe(1);
    expect(fcm.sendPushToUser).toHaveBeenCalledWith('cu-1', expect.objectContaining({ title: 'Parvoz', data: expect.objectContaining({ type: 'study_nudge' }) }));
  });

  it("queries only the preferences whose time falls in the catch-up window, plus the default for children without a row", async () => {
    const { service, prisma } = setup();

    await service.tickDailyReminder(AT_1800);

    const where = prisma.child.findMany.mock.calls[0][0].where;
    expect(where.OR[0].notificationPreference.is).toEqual({
      studyNudge: true,
      dailyReminder: true,
      dailyReminderTime: { in: ['17:56', '17:57', '17:58', '17:59', '18:00'] },
    });
    expect(where.OR[1]).toEqual({ notificationPreference: { is: null } });
  });

  it('does not touch the database at night (no reminder time can be stored outside 06:00-21:00)', async () => {
    const { service, prisma } = setup();

    const sent = await service.tickDailyReminder(new Date('2026-11-06T22:00:00Z')); // 03:00 Tashkent

    expect(sent).toBe(0);
    expect(prisma.child.findMany).not.toHaveBeenCalled();
  });

  it('does not include children without a preference row outside the default 18:00 window', async () => {
    const { service, prisma } = setup();

    await service.tickDailyReminder(new Date('2026-11-06T14:00:00Z')); // 19:00 Tashkent

    expect(prisma.child.findMany.mock.calls[0][0].where.OR).toHaveLength(1);
  });

  it('treats a child without a preference row as 18:00', async () => {
    const { service, fcm } = setup({ children: [child(1, null)] });

    expect(await service.tickDailyReminder(AT_1800)).toBe(1);
    expect(fcm.sendPushToUser).toHaveBeenCalledTimes(1);
  });

  it('does not send before the child\'s own time', async () => {
    const { service, fcm } = setup({ children: [child(1, pref({ dailyReminderTime: '19:30' }))] });

    expect(await service.tickDailyReminder(AT_1800)).toBe(0);
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('still sends a little late (server was briefly down) but not after the catch-up window', async () => {
    const early = setup({ children: [child(1, pref({ dailyReminderTime: '17:58' }))] });
    const stale = setup({ children: [child(1, pref({ dailyReminderTime: '17:50' }))] });

    expect(await early.service.tickDailyReminder(AT_1800)).toBe(1);
    expect(await stale.service.tickDailyReminder(AT_1800)).toBe(0);
  });

  it.each([
    ['the parent switched the study nudge off', { studyNudge: false }],
    ['the child switched the daily reminder off', { dailyReminder: false }],
  ])('sends nothing when %s', async (_name, over) => {
    const { service, fcm } = setup({ children: [child(1, pref(over))] });

    expect(await service.tickDailyReminder(AT_1800)).toBe(0);
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('sends nothing to a child who already studied today (olympiad or completed daily learning)', async () => {
    const olympiad = setup({ children: [child(1, pref())], olympiad: 1 });
    const learning = setup({ children: [child(1, pref())], learning: 1 });

    expect(await olympiad.service.tickDailyReminder(AT_1800)).toBe(0);
    expect(await learning.service.tickDailyReminder(AT_1800)).toBe(0);
  });

  it('sends nothing during quiet hours or when it was already sent today', async () => {
    const quiet = setup({ children: [child(1, pref({ quietFrom: '17:00', quietTo: '19:00' }))] });
    const sentToday = setup({ children: [child(1, pref({ lastStudyNudgeAt: new Date('2026-11-06T04:00:00Z') }))] });

    expect(await quiet.service.tickDailyReminder(AT_1800)).toBe(0);
    expect(await sentToday.service.tickDailyReminder(AT_1800)).toBe(0);
  });

  it('records the send so the next minute does not repeat it', async () => {
    const { service, prisma } = setup({ children: [child(1, pref())] });

    await service.tickDailyReminder(AT_1800);

    expect(prisma.notificationPreference.upsert).toHaveBeenCalledWith(
      expect.objectContaining({ where: { childId: 'ch-1' }, update: { lastStudyNudgeAt: AT_1800 } }),
    );
  });
});

describe('NudgeService hourly tick', () => {
  it('no longer sends the study nudge at the old fixed 16:00', async () => {
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
});

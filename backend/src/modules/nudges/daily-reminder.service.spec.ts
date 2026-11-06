import { DailyReminderService } from './daily-reminder.service';

// 13:00 UTC = 18:00 Tashkent (2026-11-06, juma)
const AT_1800 = new Date('2026-11-06T13:00:00Z');

const child = (n: number, pref: { dailyReminderTime: string; quietFrom: string | null; quietTo: string | null } | null = null) => ({
  id: `ch-${n}`,
  childUserId: `cu-${n}`,
  notificationPreference: pref,
});
const pref = (over: Partial<{ dailyReminderTime: string; quietFrom: string | null; quietTo: string | null }> = {}) => ({
  dailyReminderTime: '18:00',
  quietFrom: null,
  quietTo: null,
  ...over,
});

describe('DailyReminderService', () => {
  function setup(opts: { children?: unknown[]; studied?: string[]; olympiad?: string[]; claimed?: string[] } = {}) {
    const prisma = {
      child: { findMany: jest.fn().mockResolvedValue(opts.children ?? []) },
      olympiadAttempt: { findMany: jest.fn().mockResolvedValue((opts.olympiad ?? []).map((childId) => ({ childId }))) },
      learningAttempt: { findMany: jest.fn().mockResolvedValue((opts.studied ?? []).map((childId) => ({ childId }))) },
      notification: { create: jest.fn().mockResolvedValue({}) },
      notificationPreference: { upsert: jest.fn().mockResolvedValue({}) },
    };
    const fcm = {
      getUserLang: jest.fn().mockResolvedValue('uz'),
      sendPushToUser: jest.fn().mockResolvedValue({ sent: 1, failed: 0, invalidTokens: [] }),
    };
    const dedupe = { claim: jest.fn(async (ids: string[]) => opts.claimed ?? ids) };
    const service = new DailyReminderService(prisma as never, fcm as never, dedupe as never);
    return { prisma, fcm, dedupe, service };
  }

  it('sends the study nudge at the configured time to a child who has not studied today', async () => {
    const { service, fcm } = setup({ children: [child(1, pref())] });

    const sent = await service.run(AT_1800);

    expect(sent).toBe(1);
    expect(fcm.sendPushToUser).toHaveBeenCalledWith('cu-1', {
      title: 'Parvoz',
      body: "Bugun bitta test yechib ko'rchi 📚",
      data: { type: 'study_nudge', childId: 'ch-1', relatedRoute: '/contests' },
    });
  });

  it('selects only what is due: window times, not yet handled today, not yet nudged today', async () => {
    const { service, prisma } = setup();

    await service.run(AT_1800);

    const where = prisma.child.findMany.mock.calls[0][0].where;
    expect(where.pushDedupe).toEqual({ none: { kind: 'STUDY_NUDGE', refKey: '2026-11-06' } });
    expect(where.OR[0].notificationPreference.is).toEqual({
      studyNudge: true,
      dailyReminder: true,
      dailyReminderTime: { in: ['17:56', '17:57', '17:58', '17:59', '18:00'] },
      OR: [{ lastStudyNudgeAt: null }, { lastStudyNudgeAt: { lt: new Date('2026-11-05T19:00:00Z') } }],
    });
    expect(where.OR[1]).toEqual({ notificationPreference: { is: null } });
  });

  it('does not include children without a preference row outside the default 18:00 window', async () => {
    const { service, prisma } = setup();

    await service.run(new Date('2026-11-06T14:00:00Z')); // 19:00 Tashkent

    expect(prisma.child.findMany.mock.calls[0][0].where.OR).toHaveLength(1);
  });

  it('does not touch the database at night (no reminder time can be stored outside 06:00-21:00)', async () => {
    const { service, prisma, dedupe } = setup();

    expect(await service.run(new Date('2026-11-06T22:00:00Z'))).toBe(0); // 03:00 Tashkent
    expect(prisma.child.findMany).not.toHaveBeenCalled();
    expect(dedupe.claim).not.toHaveBeenCalled();
  });

  it('treats a child without a preference row as 18:00', async () => {
    const { service, fcm } = setup({ children: [child(1, null)] });

    expect(await service.run(AT_1800)).toBe(1);
    expect(fcm.sendPushToUser).toHaveBeenCalledTimes(1);
  });

  it("does not send before the child's own time, and not after the catch-up window", async () => {
    const early = setup({ children: [child(1, pref({ dailyReminderTime: '19:30' }))] });
    const stale = setup({ children: [child(1, pref({ dailyReminderTime: '17:50' }))] });
    const late = setup({ children: [child(1, pref({ dailyReminderTime: '17:58' }))] });

    expect(await early.service.run(AT_1800)).toBe(0);
    expect(await stale.service.run(AT_1800)).toBe(0);
    expect(await late.service.run(AT_1800)).toBe(1);
    expect(early.dedupe.claim).not.toHaveBeenCalled();
  });

  it('claims the once-a-day row (kind STUDY_NUDGE, Tashkent day) BEFORE sending, and only sends to the claimed', async () => {
    const order: string[] = [];
    const { service, dedupe, fcm } = setup({ children: [child(1, pref()), child(2, pref())], claimed: ['ch-2'] });
    dedupe.claim.mockImplementation(async (ids: string[]) => {
      order.push('claim');
      return ids.filter((id) => id === 'ch-2');
    });
    fcm.sendPushToUser.mockImplementation(async () => {
      order.push('push');
      return { sent: 1, failed: 0, invalidTokens: [] };
    });

    const sent = await service.run(AT_1800);

    expect(dedupe.claim).toHaveBeenCalledWith(['ch-1', 'ch-2'], 'STUDY_NUDGE', '2026-11-06');
    expect(order).toEqual(['claim', 'push']);
    expect(sent).toBe(1);
    expect(fcm.sendPushToUser).toHaveBeenCalledWith('cu-2', expect.anything());
  });

  it('is a no-op when another instance/run already claimed everyone (no double send)', async () => {
    const { service, fcm } = setup({ children: [child(1, pref())], claimed: [] });

    expect(await service.run(AT_1800)).toBe(0);
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('sends nothing to a child who already studied today (olympiad or completed daily learning) but keeps the claim', async () => {
    const learning = setup({ children: [child(1, pref())], studied: ['ch-1'] });
    const olympiad = setup({ children: [child(1, pref())], olympiad: ['ch-1'] });

    expect(await learning.service.run(AT_1800)).toBe(0);
    expect(await olympiad.service.run(AT_1800)).toBe(0);
    expect(learning.dedupe.claim).toHaveBeenCalledTimes(1);
    expect(learning.fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it("checks today's attempts from the Tashkent midnight, in one query per kind", async () => {
    const { service, prisma } = setup({ children: [child(1, pref()), child(2, pref())] });

    await service.run(AT_1800);

    expect(prisma.learningAttempt.findMany).toHaveBeenCalledTimes(1);
    expect(prisma.learningAttempt.findMany.mock.calls[0][0].where).toEqual({
      childId: { in: ['ch-1', 'ch-2'] },
      status: 'COMPLETED',
      completedAt: { gte: new Date('2026-11-05T19:00:00Z') },
    });
    expect(prisma.olympiadAttempt.findMany).toHaveBeenCalledTimes(1);
  });

  it('sends nothing during quiet hours (and does not claim the child)', async () => {
    const { service, fcm, dedupe } = setup({ children: [child(1, pref({ quietFrom: '17:00', quietTo: '19:00' }))] });

    expect(await service.run(AT_1800)).toBe(0);
    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
    expect(dedupe.claim).not.toHaveBeenCalled();
  });

  it('records the nudge (notification row and last-sent time)', async () => {
    const { service, prisma } = setup({ children: [child(1, pref())] });

    await service.run(AT_1800);

    expect(prisma.notification.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ childId: 'ch-1', type: 'STUDY_NUDGE', title: 'Parvoz' }),
    });
    expect(prisma.notificationPreference.upsert).toHaveBeenCalledWith({
      where: { childId: 'ch-1' },
      create: { childId: 'ch-1', lastStudyNudgeAt: AT_1800 },
      update: { lastStudyNudgeAt: AT_1800 },
    });
  });

  it('a push failure for one child does not stop the others; a bookkeeping failure is not retried (claimed)', async () => {
    const { service, fcm, prisma, dedupe } = setup({ children: [child(1, pref()), child(2, pref()), child(3, pref())] });
    fcm.sendPushToUser.mockRejectedValueOnce(new Error('fcm down'));
    prisma.notification.create.mockRejectedValueOnce(new Error('db hiccup')).mockResolvedValue({});

    const sent = await service.run(AT_1800);

    // 1-bolada push yiqildi, lekin yozuv yaratildi; 2-bolada yozuv yiqildi; 3-bola to'liq o'tdi.
    expect(sent).toBe(2);
    expect(fcm.sendPushToUser).toHaveBeenCalledTimes(3);
    expect(dedupe.claim).toHaveBeenCalledTimes(1);
  });

  it('sends with bounded concurrency (never more than 8 pushes in flight)', async () => {
    const children = Array.from({ length: 30 }, (_, i) => child(i + 1, pref()));
    const { service, fcm } = setup({ children });
    let inFlight = 0;
    let peak = 0;
    fcm.sendPushToUser.mockImplementation(async () => {
      inFlight++;
      peak = Math.max(peak, inFlight);
      await new Promise((resolve) => setTimeout(resolve, 2));
      inFlight--;
      return { sent: 1, failed: 0, invalidTokens: [] };
    });

    expect(await service.run(AT_1800)).toBe(30);
    expect(peak).toBeLessThanOrEqual(8);
    expect(peak).toBeGreaterThan(1);
  });
});

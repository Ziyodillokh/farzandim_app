import { ChildPushDedupeService, DAILY_DEDUPE_RETENTION_DAYS, DEDUPE_RETENTION_DAYS } from './child-push-dedupe.service';

describe('ChildPushDedupeService', () => {
  function setup(inserted: string[] = []) {
    const prisma = {
      childPushDedupe: {
        createManyAndReturn: jest.fn().mockResolvedValue(inserted.map((childId) => ({ childId }))),
        deleteMany: jest.fn().mockResolvedValue({ count: 3 }),
      },
    };
    return { prisma, service: new ChildPushDedupeService(prisma as never) };
  }

  it('returns only the children whose row was newly inserted', async () => {
    const { prisma, service } = setup(['ch-2']);

    const claimed = await service.claim(['ch-1', 'ch-2'], 'HOMEWORK_DUE', '2026-11-06');

    expect(claimed).toEqual(['ch-2']);
    expect(prisma.childPushDedupe.createManyAndReturn).toHaveBeenCalledWith({
      data: [
        { childId: 'ch-1', kind: 'HOMEWORK_DUE', refKey: '2026-11-06' },
        { childId: 'ch-2', kind: 'HOMEWORK_DUE', refKey: '2026-11-06' },
      ],
      skipDuplicates: true,
      select: { childId: true },
    });
  });

  it('collapses duplicate ids and skips the database for an empty list', async () => {
    const { prisma, service } = setup(['ch-1']);

    await service.claim(['ch-1', 'ch-1'], 'X', 'k');
    await service.claim([], 'X', 'k');

    expect(prisma.childPushDedupe.createManyAndReturn).toHaveBeenCalledTimes(1);
    expect(prisma.childPushDedupe.createManyAndReturn.mock.calls[0][0].data).toHaveLength(1);
  });

  it('claims big lists in batches and returns everyone that was newly inserted', async () => {
    const { prisma, service } = setup();
    const ids = Array.from({ length: 2500 }, (_, i) => `ch-${i}`);
    prisma.childPushDedupe.createManyAndReturn.mockImplementation(async ({ data }: { data: Array<{ childId: string }> }) =>
      data.map((d) => ({ childId: d.childId })),
    );

    const claimed = await service.claim(ids, 'STUDY_NUDGE', '2026-11-06');

    expect(prisma.childPushDedupe.createManyAndReturn).toHaveBeenCalledTimes(3);
    expect(claimed).toHaveLength(2500);
  });

  it('prunes rows older than the retention window, and the per-day kinds sooner', async () => {
    const { prisma, service } = setup();
    const now = new Date('2026-11-06T12:00:00Z');
    const day = 24 * 60 * 60 * 1000;

    const removed = await service.prune(now);

    const [old, daily] = prisma.childPushDedupe.deleteMany.mock.calls.map((c) => c[0] as { where: { createdAt: { lt: Date }; kind?: { in: string[] } } });
    expect(now.getTime() - old!.where.createdAt.lt.getTime()).toBe(DEDUPE_RETENTION_DAYS * day);
    expect(old!.where.kind).toBeUndefined();
    expect(daily!.where.kind).toEqual({ in: ['STUDY_NUDGE'] });
    expect(now.getTime() - daily!.where.createdAt.lt.getTime()).toBe(DAILY_DEDUPE_RETENTION_DAYS * day);
    expect(removed).toBe(6);
  });
});

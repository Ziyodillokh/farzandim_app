import { ChildPushDedupeService, DEDUPE_RETENTION_DAYS } from './child-push-dedupe.service';

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

  it('prunes rows older than the retention window', async () => {
    const { prisma, service } = setup();
    const now = new Date('2026-11-06T12:00:00Z');

    const removed = await service.prune(now);

    const cutoff = (prisma.childPushDedupe.deleteMany.mock.calls[0][0] as { where: { createdAt: { lt: Date } } }).where.createdAt.lt;
    expect(now.getTime() - cutoff.getTime()).toBe(DEDUPE_RETENTION_DAYS * 24 * 60 * 60 * 1000);
    expect(removed).toBe(3);
  });
});

import { LeaderboardPeriod } from './dto/leaderboard-query.dto';
import { LEADERBOARD_MAX_ROWS, LeaderboardService } from './leaderboard.service';

/**
 * F16/F17: reyting begonalarga boshqa bolalarning id'sini (rasm proksisiga
 * yo'l) va to'liq ismini bermaydi; `childId` so'rov parametri faqat o'z
 * oilasidagi bola uchun qabul qilinadi.
 */
describe('LeaderboardService privacy', () => {
  const ME = 'child-me';
  const STRANGER = 'child-stranger';

  function profile(childId: string, name: string, don: number) {
    return {
      childId,
      donBalance: don,
      child: { id: childId, name, region: 'Toshkent', age: 9, gender: 'male' },
    };
  }

  let prisma: {
    child: { findMany: jest.Mock; findUnique: jest.Mock };
    childProfile: { count: jest.Mock; findMany: jest.Mock; findUnique: jest.Mock };
  };
  let service: LeaderboardService;

  beforeEach(() => {
    prisma = {
      child: {
        findMany: jest.fn().mockResolvedValue([{ id: ME }]),
        findUnique: jest.fn().mockResolvedValue({ region: 'Toshkent' }),
      },
      childProfile: {
        count: jest.fn().mockResolvedValue(2),
        findMany: jest
          .fn()
          .mockResolvedValue([
            profile(STRANGER, 'Muhammad Abror Karimov', 50),
            profile(ME, 'Ali Valiyev', 10),
          ]),
        findUnique: jest.fn().mockResolvedValue(profile(ME, 'Ali Valiyev', 10)),
      },
    };
    service = new LeaderboardService(prisma as never);
  });

  const query = (childId?: string, page = 1) => ({
    period: LeaderboardPeriod.all,
    page,
    limit: 15,
    childId,
    viewer: { userId: 'child-user-me', role: 'CHILD' as const },
  });

  it("hides other children's ids and full names but keeps the viewer's own id", async () => {
    // Act
    const res = await service.getLeaderboard(query(ME));

    // Assert
    const [stranger, me] = res.entries;
    expect(stranger.childId).toBe('');
    expect(stranger.name).toBe('Muhammad K.');
    expect(me.childId).toBe(ME);
    expect(res.currentChild?.childId).toBe(ME);
    expect(prisma.child.findMany).toHaveBeenCalledWith({
      where: { childUserId: 'child-user-me' },
      select: { id: true },
    });
  });

  it("ignores a childId that does not belong to the viewer's family", async () => {
    const res = await service.getLeaderboard(query(STRANGER));

    expect(res.currentChild).toBeNull();
    expect(prisma.childProfile.findUnique).not.toHaveBeenCalled();
  });

  it("uses the parent's children as the family for parent viewers", async () => {
    await service.getLeaderboard({
      ...query(ME),
      viewer: { userId: 'parent-1', role: 'PARENT' },
    });

    expect(prisma.child.findMany).toHaveBeenCalledWith({
      where: { parentId: 'parent-1' },
      select: { id: true },
    });
  });

  it('stops paging after the top rows so the list cannot be enumerated', async () => {
    prisma.childProfile.count.mockResolvedValue(5000);

    const beyond = await service.getLeaderboard({
      ...query(ME),
      page: LEADERBOARD_MAX_ROWS / 10 + 1,
      limit: 10,
    });

    expect(beyond.entries).toEqual([]);
    expect(beyond.hasMore).toBe(false);
    expect(beyond.currentChild?.childId).toBe(ME);
  });
});

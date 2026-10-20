// DON / XP mukofoti: parallel chaqiruvlarda ikki marta berilmaydi va
// yangilanishlar yo'qolmaydi (advisory lock + increment).

import { GamificationService } from '../../src/modules/gamification/gamification.service';
import { XpEventType } from '../../src/modules/gamification/dto/create-xp-event.dto';
import { createChild, createParent } from './factories';
import { resetDb } from './db';
import { createTestApp, TestApp } from './test-app';

describe('Gamification award (parallel)', () => {
  let t: TestApp;
  let service: GamificationService;

  beforeAll(async () => {
    t = await createTestApp();
    service = t.app.get(GamificationService);
  });

  beforeEach(() => resetDb(t.prisma));
  afterAll(() => t.close());

  it('bir xil relatedId — 20 parallel chaqiruvdan faqat bittasi beriladi', async () => {
    const child = await createChild(t.prisma, await createParent(t.prisma));

    await Promise.all(
      Array.from({ length: 20 }, () =>
        service.awardXp(child.childId, {
          type: XpEventType.CONTEST_WIN,
          xpDelta: 10,
          donDelta: 7,
          relatedId: 'attempt-1',
        }),
      ),
    );

    const events = await t.prisma.xpEvent.count({ where: { childId: child.childId } });
    const profile = await t.prisma.childProfile.findUniqueOrThrow({
      where: { childId: child.childId },
    });
    expect(events).toBe(1);
    expect(profile.donBalance).toBe(7);
    expect(profile.xp).toBe(10);
    expect(profile.streakDays).toBe(1);
  });

  it('har xil relatedId — barcha mukofotlar yo\'qolmasdan qo\'shiladi', async () => {
    const child = await createChild(t.prisma, await createParent(t.prisma));

    await Promise.all(
      Array.from({ length: 15 }, (_, i) =>
        service.awardXp(child.childId, {
          type: XpEventType.BOOK_READ,
          xpDelta: 20,
          donDelta: 5,
          relatedId: `book-${i}`,
        }),
      ),
    );
    await service.awardStepDon(child.childId, 10, true);

    const profile = await t.prisma.childProfile.findUniqueOrThrow({
      where: { childId: child.childId },
    });
    expect(profile.xp).toBe(300);
    expect(profile.donBalance).toBe(85);
    expect(profile.level).toBe(4);
    expect(profile.status).toBe('Izlanuvchi');
    expect(await t.prisma.xpEvent.count({ where: { childId: child.childId } })).toBe(16);
  });

  it('qadam: don 0 bo\'lsa ledger yozuvi yo\'q, lekin streak yangilanadi', async () => {
    const child = await createChild(t.prisma, await createParent(t.prisma));
    await service.awardStepDon(child.childId, 0, true);

    const profile = await t.prisma.childProfile.findUniqueOrThrow({
      where: { childId: child.childId },
    });
    expect(profile.streakDays).toBe(1);
    expect(profile.donBalance).toBe(0);
    expect(await t.prisma.xpEvent.count({ where: { childId: child.childId } })).toBe(0);
  });
});

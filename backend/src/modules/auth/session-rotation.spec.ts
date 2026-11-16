import { UnauthorizedException } from '@nestjs/common';
import type { UserSession } from '@prisma/client';
import { isWithinRotationGrace, ROTATION_GRACE_MS, rotateSessionJti } from './session-rotation';

const NOW = new Date('2026-11-14T08:00:00.000Z');

function session(overrides: Partial<UserSession> = {}): UserSession {
  return {
    id: 'session-1',
    userId: 'user-1',
    jti: 'jti-current',
    deviceModel: null,
    platform: 'android',
    ipAddress: null,
    city: null,
    country: null,
    userAgent: null,
    createdAt: NOW,
    lastSeenAt: NOW,
    revokedAt: null,
    deviceId: null,
    kind: null,
    revokedReason: null,
    isMain: false,
    prevJti: null,
    rotatedAt: null,
    ...overrides,
  };
}

function db(updated: number, fresh: UserSession | null = null) {
  return {
    userSession: {
      updateMany: jest.fn().mockResolvedValue({ count: updated }),
      findUnique: jest.fn().mockResolvedValue(fresh),
    },
  };
}

describe('rotateSessionJti', () => {
  it('joriy jti bilan kelsa atomik rotatsiya qiladi va oldingi jti saqlanadi', async () => {
    const store = db(1);

    const next = await rotateSessionJti(store as never, session(), 'jti-current', NOW);

    expect(next).not.toBe('jti-current');
    expect(store.userSession.updateMany).toHaveBeenCalledWith({
      where: { id: 'session-1', jti: 'jti-current', revokedAt: null },
      data: { jti: next, prevJti: 'jti-current', rotatedAt: NOW, lastSeenAt: NOW },
    });
  });

  it("parallel so'rov oldin rotatsiya qilgan bo'lsa yutqazgan joriy jti'ni oladi", async () => {
    const winner = session({ jti: 'jti-winner', prevJti: 'jti-current', rotatedAt: NOW });
    const store = db(0, winner);

    await expect(rotateSessionJti(store as never, session(), 'jti-current', NOW)).resolves.toBe('jti-winner');
  });

  it('oldingi jti imtiyoz ichida kelsa hech narsa yozmasdan joriy jti qaytadi', async () => {
    const rotated = session({ jti: 'jti-new', prevJti: 'jti-old', rotatedAt: new Date(NOW.getTime() - 5_000) });
    const store = db(1);

    await expect(rotateSessionJti(store as never, rotated, 'jti-old', NOW)).resolves.toBe('jti-new');
    expect(store.userSession.updateMany).not.toHaveBeenCalled();
  });

  it("imtiyozdan keyin kelgan oldingi jti va begona jti rad etiladi ('Session rotated')", async () => {
    const late = session({ jti: 'jti-new', prevJti: 'jti-old', rotatedAt: new Date(NOW.getTime() - ROTATION_GRACE_MS - 1) });

    await expect(rotateSessionJti(db(1) as never, late, 'jti-old', NOW)).rejects.toThrow(new UnauthorizedException('Session rotated'));
    await expect(rotateSessionJti(db(1) as never, late, 'jti-unknown', NOW)).rejects.toThrow('Session rotated');
  });

  it("yozish vaqtida sessiya yopilgan bo'lsa imtiyoz berilmaydi", async () => {
    const closed = session({ jti: 'jti-winner', prevJti: 'jti-current', rotatedAt: NOW, revokedAt: NOW });

    await expect(rotateSessionJti(db(0, closed) as never, session(), 'jti-current', NOW)).rejects.toThrow('Session rotated');
  });

  it("rjti'siz eski token ham atomik rotatsiyadan o'tadi", async () => {
    const store = db(1);

    await expect(rotateSessionJti(store as never, session(), undefined, NOW)).resolves.toEqual(expect.any(String));
    expect(store.userSession.updateMany).toHaveBeenCalledTimes(1);
  });
});

describe('isWithinRotationGrace', () => {
  it("faqat oldingi jti va imtiyoz muddati ichida true", () => {
    const state = { prevJti: 'jti-old', rotatedAt: NOW };

    expect(isWithinRotationGrace(state, 'jti-old', new Date(NOW.getTime() + ROTATION_GRACE_MS))).toBe(true);
    expect(isWithinRotationGrace(state, 'jti-old', new Date(NOW.getTime() + ROTATION_GRACE_MS + 1))).toBe(false);
    expect(isWithinRotationGrace(state, 'jti-other', NOW)).toBe(false);
    expect(isWithinRotationGrace({ prevJti: null, rotatedAt: null }, 'jti-old', NOW)).toBe(false);
    expect(isWithinRotationGrace(state, undefined, NOW)).toBe(false);
  });
});

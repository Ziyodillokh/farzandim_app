import { ChildSessionsService } from './child-sessions.service';

const T0 = new Date('2026-11-09T09:00:00.000Z');
const DEVICE = { id: 'dev-1', model: 'Redmi', platform: 'android' as const };

/** Interaktiv tranzaksiyani soddalashtirilgan soxta `tx` bilan ishga tushiradi. */
function setup(
  cred: { passwordHash: string; lockedUntil: Date | null } | null,
  mains: { sameDevice?: boolean; other?: boolean } = {},
) {
  const created: unknown[] = [];
  const tx = {
    $queryRaw: jest.fn().mockResolvedValue([]),
    child: {
      findUnique: jest.fn().mockResolvedValue({
        id: 'child-1',
        name: 'Aziza',
        childUser: { id: 'user-1', tokenVersion: 0, isActive: true, role: 'CHILD', createdVia: 'LOGIN' },
      }),
      update: jest.fn(),
    },
    childCredential: { findUnique: jest.fn().mockResolvedValue(cred) },
    user: { create: jest.fn() },
    userSession: {
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      // `deviceId` bilan so'rov — shu qurilmadagi ASOSIY sessiya (almashtiriladigan); boshqasi — qolgan ASOSIY sessiya.
      count: jest.fn(async ({ where }: { where: { deviceId?: string } }) => Number(where.deviceId ? mains.sameDevice : mains.other)),
      create: jest.fn(async ({ data }: { data: unknown }) => {
        created.push(data);
        return { id: 'sid-1' };
      }),
    },
  };
  const prisma = { $transaction: jest.fn(async (fn: (t: typeof tx) => unknown) => fn(tx)) };
  const realtime = { emitToUser: jest.fn() };
  return { service: new ChildSessionsService(prisma as never, realtime as never), tx, created };
}

const status = (err: unknown) => (err as { getStatus(): number }).getStatus();
const body = (err: unknown) => (err as { getResponse(): Record<string, unknown> }).getResponse();
const caught = async (promise: Promise<unknown>) => promise.then(() => null, (e: unknown) => e);

describe('ChildSessionsService.open: the verified credential is rechecked under the child lock', () => {
  it('opens the session when the password hash is still the verified one', async () => {
    const t = setup({ passwordHash: 'verified-hash', lockedUntil: null });

    const opened = await t.service.open('child-1', DEVICE, T0, { passwordHash: 'verified-hash' });

    expect(opened).toMatchObject({ sessionId: 'sid-1', deviceRole: 'MAIN' });
    expect(t.created).toHaveLength(1);
  });

  it('refuses (401 INVALID_CREDENTIALS) and creates nothing when a reset changed the password meanwhile', async () => {
    const t = setup({ passwordHash: 'new-hash-after-reset', lockedUntil: null });

    const err = await caught(t.service.open('child-1', DEVICE, T0, { passwordHash: 'verified-hash' }));

    expect(status(err)).toBe(401);
    expect(body(err)).toMatchObject({ code: 'INVALID_CREDENTIALS' });
    expect(t.created).toEqual([]);
    expect(t.tx.userSession.updateMany).not.toHaveBeenCalled();
  });

  it('refuses (401) when the credential disappeared', async () => {
    const t = setup(null);

    expect(status(await caught(t.service.open('child-1', DEVICE, T0, { passwordHash: 'verified-hash' })))).toBe(401);
    expect(t.created).toEqual([]);
  });

  it('refuses (429 LOCKED) when the account got locked between the check and the session', async () => {
    const t = setup({ passwordHash: 'verified-hash', lockedUntil: new Date(T0.getTime() + 600_000) });

    const err = await caught(t.service.open('child-1', DEVICE, T0, { passwordHash: 'verified-hash' }));

    expect(status(err)).toBe(429);
    expect(body(err)).toMatchObject({ code: 'LOCKED', retryAfterSeconds: 600 });
    expect(t.created).toEqual([]);
  });

  it('does not check the credential when no expectation is given', async () => {
    const t = setup(null);

    await t.service.open('child-1', DEVICE, T0);

    expect(t.tx.childCredential.findUnique).not.toHaveBeenCalled();
    expect(t.created).toHaveLength(1);
  });
});

describe('ChildSessionsService.open: the device role and device.hostsControl', () => {
  const GOOD = { passwordHash: 'h', lockedUntil: null };
  const sessionData = (t: ReturnType<typeof setup>) => t.created[0] as { isMain: boolean };

  it('the first login becomes MAIN (hostsControl absent or true)', async () => {
    for (const hostsControl of [undefined, true]) {
      const t = setup(GOOD);

      const opened = await t.service.open('child-1', { ...DEVICE, hostsControl }, T0);

      expect(opened.deviceRole).toBe('MAIN');
      expect(sessionData(t).isMain).toBe(true);
    }
  });

  it('hostsControl:false never makes a NEW session MAIN, even when the child has no main device', async () => {
    const t = setup(GOOD);

    const opened = await t.service.open('child-1', { ...DEVICE, hostsControl: false }, T0);

    expect(opened.deviceRole).toBe('SECONDARY');
    expect(sessionData(t).isMain).toBe(false);
  });

  it('hostsControl:false keeps MAIN for the owner re-authenticating on the same device (replacing its own MAIN session)', async () => {
    const t = setup(GOOD, { sameDevice: true });

    const opened = await t.service.open('child-1', { ...DEVICE, hostsControl: false }, T0);

    expect(opened.deviceRole).toBe('MAIN');
    expect(sessionData(t).isMain).toBe(true);
  });

  it('reads whether the replaced session was MAIN BEFORE closing it (closing clears isMain)', async () => {
    const t = setup(GOOD, { sameDevice: true });
    t.tx.userSession.findMany.mockResolvedValueOnce([{ id: 'old-session' }]);

    await t.service.open('child-1', { ...DEVICE, hostsControl: false }, T0);

    const sameDeviceCount = t.tx.userSession.count.mock.calls.findIndex((c) => (c[0] as { where: { deviceId?: string } }).where.deviceId);
    expect(sameDeviceCount).toBe(0);
    expect(t.tx.userSession.count.mock.invocationCallOrder[0]).toBeLessThan(t.tx.userSession.updateMany.mock.invocationCallOrder[0]!);
  });

  it('never creates a second MAIN: another main session makes the new one SECONDARY (any hostsControl)', async () => {
    for (const hostsControl of [undefined, true, false]) {
      const t = setup(GOOD, { other: true });

      const opened = await t.service.open('child-1', { ...DEVICE, hostsControl }, T0);

      expect(opened.deviceRole).toBe('SECONDARY');
      expect(sessionData(t).isMain).toBe(false);
    }
  });

  it('stores nothing about hostsControl on the session (it only decides the role)', async () => {
    const t = setup(GOOD);

    await t.service.open('child-1', { ...DEVICE, hostsControl: false }, T0);

    expect(JSON.stringify(t.created[0])).not.toContain('hostsControl');
  });
});

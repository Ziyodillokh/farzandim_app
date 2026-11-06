import { ChildAuthClock } from './child-auth-clock';
import { ChildAuthEffects } from './child-auth-effects';
import { ChildCredentialsService, toCredentialView, toIssued } from './child-credentials.service';

const T0 = new Date('2026-11-09T09:00:00.000Z');

function setup(over: { tokens?: number; child?: unknown; lang?: string } = {}) {
  const prisma = {
    child: { findUnique: jest.fn().mockResolvedValue(over.child === undefined ? { parentId: 'parent-1' } : over.child) },
    fcmToken: { count: jest.fn().mockResolvedValue(over.tokens ?? 1) },
  };
  const fcm = { getUserLang: jest.fn().mockResolvedValue(over.lang ?? 'uz'), sendPushToUser: jest.fn().mockResolvedValue({ sent: 1 }) };
  const effects = new ChildAuthEffects();
  const clock = new ChildAuthClock();
  clock.now = () => T0;
  const service = new ChildCredentialsService(prisma as never, {} as never, {} as never, clock, fcm as never, effects);
  return { service, prisma, fcm, effects };
}

describe('ChildCredentialsService.notifyParentOfSchoolAction (transparency push)', () => {
  it('sends the parent a neutral push of type CHILD_CREDENTIAL_SCHOOL with only the child id', async () => {
    const t = setup();

    t.service.notifyParentOfSchoolAction('child-1', false);
    await t.effects.drain();

    expect(t.fcm.sendPushToUser).toHaveBeenCalledTimes(1);
    expect(t.fcm.sendPushToUser).toHaveBeenCalledWith('parent-1', {
      title: 'Parvoz',
      body: 'Maktab farzandingizga kirish maʼlumotlarini berdi',
      data: { type: 'CHILD_CREDENTIAL_SCHOOL', childId: 'child-1' },
    });
  });

  it('says "renewed" for a reset', async () => {
    const t = setup();

    t.service.notifyParentOfSchoolAction('child-1', true);
    await t.effects.drain();

    expect(t.fcm.sendPushToUser.mock.calls[0]![1].body).toBe('Maktab farzandingizning kirish maʼlumotlarini yangiladi');
  });

  it('speaks the parent language (ru, en)', async () => {
    for (const [lang, issued, reset] of [
      ['ru', 'Школа выдала вашему ребёнку данные для входа', 'Школа обновила данные для входа вашего ребёнка'],
      ['en', 'The school gave your child sign-in details', 'The school renewed your child’s sign-in details'],
    ] as const) {
      const t = setup({ lang });
      t.service.notifyParentOfSchoolAction('child-1', false);
      t.service.notifyParentOfSchoolAction('child-1', true);
      await t.effects.drain();

      expect(t.fcm.sendPushToUser.mock.calls.map((c) => c[1].body).sort()).toEqual([issued, reset].sort());
    }
  });

  it('never puts a login, a password or the child name into the push', async () => {
    const t = setup();

    t.service.notifyParentOfSchoolAction('child-1', false);
    t.service.notifyParentOfSchoolAction('child-1', true);
    await t.effects.drain();

    for (const [, payload] of t.fcm.sendPushToUser.mock.calls) {
      expect(Object.keys(payload.data).sort()).toEqual(['childId', 'type']);
      expect(JSON.stringify(payload)).not.toMatch(/login|parol|password|пароль/i);
    }
  });

  it('sends nothing when the parent has no FCM tokens', async () => {
    const t = setup({ tokens: 0 });

    t.service.notifyParentOfSchoolAction('child-1', false);
    await t.effects.drain();

    expect(t.prisma.fcmToken.count).toHaveBeenCalledWith({ where: { userId: 'parent-1' } });
    expect(t.fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it('sends nothing for an unknown child, and a failing push never throws to the caller', async () => {
    const unknown = setup({ child: null });
    unknown.service.notifyParentOfSchoolAction('missing', false);
    await unknown.effects.drain();
    expect(unknown.fcm.sendPushToUser).not.toHaveBeenCalled();

    const failing = setup();
    failing.fcm.sendPushToUser.mockRejectedValue(new Error('fcm down'));
    expect(() => failing.service.notifyParentOfSchoolAction('child-1', false)).not.toThrow();
    await expect(failing.effects.drain()).resolves.toBeUndefined();
  });

  it('returns before the push is delivered (the school response is not delayed by FCM)', async () => {
    const t = setup();
    let release: () => void = () => undefined;
    t.fcm.sendPushToUser.mockImplementation(() => new Promise((resolve) => (release = () => resolve({ sent: 1 }))));

    t.service.notifyParentOfSchoolAction('child-1', false);

    for (let i = 0; i < 50 && t.fcm.sendPushToUser.mock.calls.length === 0; i++) await new Promise((r) => setImmediate(r));
    expect(t.fcm.sendPushToUser).toHaveBeenCalledTimes(1);
    release();
    await t.effects.drain();
  });
});

describe('credential views', () => {
  const row = (over: Record<string, unknown> = {}) =>
    ({
      childId: 'c1',
      login: 'aziza.k24',
      passwordHash: 'hash',
      mustChangePassword: true,
      failedLogins: 0,
      failedWindowStartedAt: null,
      lockedUntil: null,
      issuedBy: 'PARENT',
      issuedByUserId: 'p1',
      issuedByStaffId: null,
      issuedAt: new Date('2026-11-09T09:00:00.000Z'),
      passwordChangedAt: null,
      lastLoginAt: null,
      createdAt: T0,
      updatedAt: T0,
      ...over,
    }) as never;

  it('shows temporaryPasswordExpiresAt = issuedAt + 14 days while the password is temporary', () => {
    expect(toCredentialView(row())).toEqual({
      login: 'aziza.k24',
      issuedBy: 'PARENT',
      issuedAt: '2026-11-09T09:00:00.000Z',
      mustChangePassword: true,
      temporaryPasswordExpiresAt: '2026-11-23T09:00:00.000Z',
      lastLoginAt: null,
    });
  });

  it('shows null when the temporary password no longer applies', () => {
    expect(toCredentialView(row({ mustChangePassword: false })).temporaryPasswordExpiresAt).toBeNull();
  });

  it('never exposes the hash or counters', () => {
    expect(Object.keys(toCredentialView(row())).sort()).toEqual([
      'issuedAt',
      'issuedBy',
      'lastLoginAt',
      'login',
      'mustChangePassword',
      'temporaryPasswordExpiresAt',
    ]);
  });

  it('toIssued keeps exactly the one-time response fields', () => {
    expect(
      toIssued({
        login: 'a.b01',
        temporaryPassword: 'k7m2qx9d',
        issuedAt: 'i',
        temporaryPasswordExpiresAt: 'e',
        reset: true,
        extra: 1,
      } as never),
    ).toEqual({ login: 'a.b01', temporaryPassword: 'k7m2qx9d', issuedAt: 'i', temporaryPasswordExpiresAt: 'e' });
  });
});

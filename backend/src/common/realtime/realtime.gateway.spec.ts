import { Logger } from '@nestjs/common';
import { RealtimeGateway } from './realtime.gateway';

jest.useFakeTimers();

// Gateway har ulanishda log yozadi — test chiqishini toza saqlaymiz.
beforeAll(() => {
  jest.spyOn(Logger.prototype, 'log').mockImplementation();
  jest.spyOn(Logger.prototype, 'warn').mockImplementation();
});
afterAll(() => jest.restoreAllMocks());

type Prisma = {
  userSession: { findUnique: jest.Mock };
  user: { findUnique: jest.Mock };
};

function setup(over: { payload?: Record<string, unknown>; session?: unknown; user?: unknown; dbError?: boolean } = {}) {
  const payload = over.payload ?? { userId: 'user-1', role: 'CHILD', tokenVersion: 0, sid: 'sid-1' };
  const prisma: Prisma = {
    userSession: {
      findUnique: jest.fn(async () => {
        if (over.dbError) throw new Error('db down');
        return over.session === undefined ? { userId: 'user-1', revokedAt: null } : over.session;
      }),
    },
    user: {
      findUnique: jest.fn(async () => {
        if (over.dbError) throw new Error('db down');
        return over.user === undefined ? { tokenVersion: 0, isActive: true } : over.user;
      }),
    },
  };
  const jwt = { verify: jest.fn().mockReturnValue(payload) };
  const config = { get: jest.fn().mockReturnValue('secret') };
  const gateway = new RealtimeGateway(jwt as never, config as never, prisma as never);
  const client = { handshake: { auth: { token: 'token' } }, data: {} as Record<string, unknown>, join: jest.fn(), disconnect: jest.fn() };
  return { gateway, client, prisma, jwt };
}

describe('RealtimeGateway.handleConnection: revoked tokens cannot connect', () => {
  it('accepts a valid token of an active session and joins the user room', async () => {
    const t = setup();

    await t.gateway.handleConnection(t.client as never);

    expect(t.client.disconnect).not.toHaveBeenCalled();
    expect(t.client.join).toHaveBeenCalledWith('user:user-1');
    expect(t.client.data).toMatchObject({ userId: 'user-1', role: 'CHILD' });
  });

  it('rejects a token whose session was revoked', async () => {
    const t = setup({ session: { userId: 'user-1', revokedAt: new Date() } });

    await t.gateway.handleConnection(t.client as never);

    expect(t.client.disconnect).toHaveBeenCalled();
    expect(t.client.join).not.toHaveBeenCalled();
  });

  it('rejects a token whose session is missing or belongs to another user', async () => {
    for (const session of [null, { userId: 'someone-else', revokedAt: null }]) {
      const t = setup({ session });
      await t.gateway.handleConnection(t.client as never);
      expect(t.client.disconnect).toHaveBeenCalled();
    }
  });

  it('rejects a stale tokenVersion (logout everywhere / credential reset) and an inactive user', async () => {
    const stale = setup({ user: { tokenVersion: 3, isActive: true } });
    await stale.gateway.handleConnection(stale.client as never);
    expect(stale.client.disconnect).toHaveBeenCalled();

    const inactive = setup({ user: { tokenVersion: 0, isActive: false } });
    await inactive.gateway.handleConnection(inactive.client as never);
    expect(inactive.client.disconnect).toHaveBeenCalled();
  });

  it('a legacy sid-less token only checks the tokenVersion (no session lookup)', async () => {
    const t = setup({ payload: { userId: 'user-1', role: 'CHILD', tokenVersion: 0 } });

    await t.gateway.handleConnection(t.client as never);

    expect(t.prisma.userSession.findUnique).not.toHaveBeenCalled();
    expect(t.client.join).toHaveBeenCalledWith('user:user-1');
  });

  it('a token without tokenVersion and sid is accepted as before (nothing to compare)', async () => {
    const t = setup({ payload: { userId: 'user-1', role: 'PARENT' } });

    await t.gateway.handleConnection(t.client as never);

    expect(t.prisma.user.findUnique).not.toHaveBeenCalled();
    expect(t.client.join).toHaveBeenCalled();
  });

  it('does not block connections when the database check itself fails (the JWT signature suffices as before)', async () => {
    const t = setup({ dbError: true });

    await t.gateway.handleConnection(t.client as never);

    expect(t.client.disconnect).not.toHaveBeenCalled();
    expect(t.client.join).toHaveBeenCalled();
  });

  it('still disconnects a client without a token or with an invalid token', async () => {
    const noToken = setup();
    noToken.client.handshake.auth = {} as never;
    await noToken.gateway.handleConnection(noToken.client as never);
    expect(noToken.client.disconnect).toHaveBeenCalled();

    const bad = setup();
    bad.jwt.verify.mockImplementation(() => {
      throw new Error('jwt');
    });
    await bad.gateway.handleConnection(bad.client as never);
    expect(bad.client.disconnect).toHaveBeenCalled();
  });
});

describe('RealtimeGateway.disconnectUser', () => {
  afterEach(() => jest.clearAllTimers());

  it('disconnects every socket of the user room after a short delay (so session:closed can be delivered first)', () => {
    const t = setup();
    const disconnectSockets = jest.fn();
    const inRoom = jest.fn().mockReturnValue({ disconnectSockets });
    (t.gateway as unknown as { server: unknown }).server = { in: inRoom };

    t.gateway.disconnectUser('user-1');
    expect(disconnectSockets).not.toHaveBeenCalled();
    jest.advanceTimersByTime(2_000);

    expect(inRoom).toHaveBeenCalledWith('user:user-1');
    expect(disconnectSockets).toHaveBeenCalledWith(true);
  });

  it('never throws when the WebSocket server is not running', () => {
    const t = setup();

    t.gateway.disconnectUser('user-1', 10);

    expect(() => jest.advanceTimersByTime(20)).not.toThrow();
  });
});

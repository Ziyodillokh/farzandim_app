import { announceSessionsClosed, closeSessions, SESSION_CLOSE_REASONS, SESSION_CLOSED_EVENT } from './session-revocation';

describe('closeSessions', () => {
  const NOW = new Date('2026-11-09T10:00:00.000Z');

  function fakeDb(rows: Array<{ id: string }>) {
    return {
      userSession: {
        findMany: jest.fn().mockResolvedValue(rows),
        updateMany: jest.fn().mockResolvedValue({ count: rows.length }),
      },
    };
  }

  it('revokes the matching active sessions with the reason and the given time', async () => {
    const db = fakeDb([{ id: 's1' }, { id: 's2' }]);

    const ids = await closeSessions(db as never, 'user-1', 'RECOVERED', { kind: 'LOGIN' }, NOW);

    expect(ids).toEqual(['s1', 's2']);
    expect(db.userSession.findMany).toHaveBeenCalledWith({
      where: { userId: 'user-1', revokedAt: null, kind: 'LOGIN' },
      select: { id: true },
    });
    expect(db.userSession.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['s1', 's2'] }, revokedAt: null },
      data: { revokedAt: NOW, revokedReason: 'RECOVERED', isMain: false },
    });
  });

  it('never touches an already revoked session (the filter always includes revokedAt: null)', async () => {
    const db = fakeDb([{ id: 's1' }]);

    await closeSessions(db as never, 'user-1', 'SIGNED_OUT', { id: 's1' });

    expect(db.userSession.findMany.mock.calls[0]![0].where).toMatchObject({ revokedAt: null, userId: 'user-1' });
    expect(db.userSession.updateMany.mock.calls[0]![0].where).toMatchObject({ revokedAt: null });
  });

  it('does nothing when no active session matches', async () => {
    const db = fakeDb([]);

    expect(await closeSessions(db as never, 'user-1', 'SIGNED_OUT')).toEqual([]);
    expect(db.userSession.updateMany).not.toHaveBeenCalled();
  });
});

describe('announceSessionsClosed', () => {
  it('emits session:closed to the user room with the ids and the reason', () => {
    const realtime = { emitToUser: jest.fn() };

    announceSessionsClosed(realtime, 'user-1', ['s1', 's2'], 'SIGNED_IN_ELSEWHERE');

    expect(realtime.emitToUser).toHaveBeenCalledWith('user-1', SESSION_CLOSED_EVENT, {
      sessionIds: ['s1', 's2'],
      reason: 'SIGNED_IN_ELSEWHERE',
    });
    expect(SESSION_CLOSED_EVENT).toBe('session:closed');
  });

  it('stays silent for an empty list unless asked (legacy token only)', () => {
    const realtime = { emitToUser: jest.fn() };

    announceSessionsClosed(realtime, 'user-1', [], 'RECOVERED');
    expect(realtime.emitToUser).not.toHaveBeenCalled();

    announceSessionsClosed(realtime, 'user-1', [], 'RECOVERED', true);
    expect(realtime.emitToUser).toHaveBeenCalledWith('user-1', 'session:closed', { sessionIds: [], reason: 'RECOVERED' });
  });

  it('never throws when the WebSocket server is down', () => {
    const realtime = {
      emitToUser: jest.fn(() => {
        throw new TypeError('server is undefined');
      }),
    };

    expect(() => announceSessionsClosed(realtime, 'user-1', ['s1'], 'SIGNED_OUT')).not.toThrow();
  });

  it('knows exactly the four contract reasons', () => {
    expect([...SESSION_CLOSE_REASONS]).toEqual(['RECOVERED', 'SIGNED_IN_ELSEWHERE', 'SIGNED_OUT', 'PERMISSIONS_CHANGED']);
  });
});

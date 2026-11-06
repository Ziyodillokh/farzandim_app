import { INITIAL_MESSAGE_ID, MessageRow, stageOf, threadOf } from './care-thread';

const at = (iso: string) => new Date(iso);
const base = { status: 'NEW', openedAt: null, repliedAt: null };

describe('stageOf', () => {
  it('is RECEIVED while nobody opened a NEW request', () => {
    expect(stageOf(base)).toBe('RECEIVED');
  });

  it('is OPENED once opened and before any staff message', () => {
    expect(stageOf({ ...base, openedAt: at('2026-11-06T05:00:00Z') })).toBe('OPENED');
  });

  it('is OPENED for a legacy request staff already moved forward without openedAt', () => {
    expect(stageOf({ ...base, status: 'IN_PROGRESS' })).toBe('OPENED');
    expect(stageOf({ ...base, status: 'SCHEDULED' })).toBe('OPENED');
  });

  it('is REPLIED after the first staff message', () => {
    expect(stageOf({ status: 'IN_PROGRESS', openedAt: at('2026-11-06T05:00:00Z'), repliedAt: at('2026-11-06T05:10:00Z') })).toBe('REPLIED');
  });

  it('is CLOSED for a resolved request regardless of the other markers', () => {
    expect(stageOf({ status: 'RESOLVED', openedAt: null, repliedAt: at('2026-11-06T05:10:00Z') })).toBe('CLOSED');
  });
});

describe('threadOf', () => {
  const deps = { decrypt: (t: string) => t.replace('enc:', ''), nameOf: (id: string | null) => (id === 'staff-1' ? 'Dilnoza opa' : null) };
  const request = { messageEnc: 'enc:eski matn', createdAt: at('2026-11-01T04:00:00Z') };

  it('synthesizes one CHILD message with id "initial" for a legacy request', () => {
    expect(threadOf(request, [], deps)).toEqual([
      { id: INITIAL_MESSAGE_ID, author: 'CHILD', authorName: null, text: 'eski matn', createdAt: '2026-11-01T04:00:00.000Z' },
    ]);
  });

  it('orders messages oldest first and names only staff authors', () => {
    const rows: MessageRow[] = [
      { id: 'b', author: 'STAFF', staffId: 'staff-1', bodyEnc: 'enc:javob', createdAt: at('2026-11-01T05:00:00Z') },
      { id: 'a', author: 'CHILD', staffId: null, bodyEnc: 'enc:savol', createdAt: at('2026-11-01T04:00:00Z') },
    ];

    const thread = threadOf(request, rows, deps);

    expect(thread.map((m) => [m.id, m.author, m.authorName, m.text])).toEqual([
      ['a', 'CHILD', null, 'savol'],
      ['b', 'STAFF', 'Dilnoza opa', 'javob'],
    ]);
  });

  it('keeps the original text first when a legacy request later got real messages', () => {
    const rows: MessageRow[] = [
      { id: 'r1', author: 'STAFF', staffId: 'staff-1', bodyEnc: 'enc:javob', createdAt: at('2026-11-02T05:00:00Z') },
      { id: 'r2', author: 'CHILD', staffId: null, bodyEnc: 'enc:yana', createdAt: at('2026-11-02T06:00:00Z') },
    ];

    expect(threadOf(request, rows, deps).map((m) => [m.id, m.text])).toEqual([
      [INITIAL_MESSAGE_ID, 'eski matn'],
      ['r1', 'javob'],
      ['r2', 'yana'],
    ]);
  });

  it('does not duplicate the original text for a new-style request', () => {
    const rows: MessageRow[] = [{ id: 'a', author: 'CHILD', staffId: null, bodyEnc: 'enc:eski matn', createdAt: request.createdAt }];

    expect(threadOf(request, rows, deps).map((m) => m.id)).toEqual(['a']);
  });

  it('never exposes more than the five contract fields', () => {
    const [m] = threadOf(request, [{ id: 'a', author: 'CHILD', staffId: null, bodyEnc: 'enc:x', createdAt: at('2026-11-01T04:00:00Z') }], deps);
    expect(Object.keys(m!).sort()).toEqual(['author', 'authorName', 'createdAt', 'id', 'text']);
  });
});

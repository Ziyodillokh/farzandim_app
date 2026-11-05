import { afterCursorWhere, childVisibleWhere, decodeCursor, encodeCursor } from './child-announcements-view';

describe('announcement feed cursor', () => {
  it('round-trips (sentAt, id)', () => {
    const sentAt = new Date('2026-11-05T09:30:00.123Z');
    const cursor = encodeCursor({ sentAt, id: 'abc-1' });

    expect(cursor).not.toBeNull();
    expect(decodeCursor(cursor!)).toEqual({ sentAt, id: 'abc-1' });
  });

  it('cannot encode a row that was never sent', () => {
    expect(encodeCursor({ sentAt: null, id: 'x' })).toBeNull();
  });

  it.each([
    ['not base64 json', '%%%'],
    ['json without fields', Buffer.from('{}').toString('base64url')],
    ['bad date', Buffer.from(JSON.stringify({ s: 'nope', i: 'x' })).toString('base64url')],
    ['id too long', Buffer.from(JSON.stringify({ s: '2026-11-05T00:00:00Z', i: 'x'.repeat(65) })).toString('base64url')],
    ['array', Buffer.from('[1]').toString('base64url')],
  ])('rejects %s', (_label, raw) => {
    expect(decodeCursor(raw)).toBeNull();
  });

  it('continues strictly after the cursor row in (sentAt desc, id desc) order', () => {
    const sentAt = new Date('2026-11-05T09:30:00Z');

    expect(afterCursorWhere({ sentAt, id: 'k' })).toEqual({ OR: [{ sentAt: { lt: sentAt } }, { sentAt, id: { lt: 'k' } }] });
  });
});

describe('childVisibleWhere', () => {
  it("scopes to the child's school, SENT, includeStudents and (SCHOOL or the child's class)", () => {
    const where = childVisibleWhere('school-1', 'class-1');

    expect(where.schoolId).toBe('school-1');
    expect(where.status).toBe('SENT');
    expect(JSON.stringify(where)).toContain('"includeStudents"');
    expect(JSON.stringify(where)).toContain('"array_contains":["class-1"]');
    expect(JSON.stringify(where)).not.toContain('GUARDIANS');
  });
});

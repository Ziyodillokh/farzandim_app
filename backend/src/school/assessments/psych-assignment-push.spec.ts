import { isQuietHour, PsychAssignmentPushService } from './psych-assignment-push.service';
import {
  assignmentRecipientsWhere,
  isOpenNow,
  psychAssignmentPush,
  selectPsychRecipients,
} from './psych-assignment-push';

const NOW = new Date('2026-11-11T07:00:00Z'); // Toshkent 12:00
const assignment = (over: Record<string, unknown> = {}) => ({
  id: 'as-1',
  schoolId: 's-1',
  testId: 'test-1',
  status: 'OPEN',
  classIds: ['c-5a'],
  studentIds: [] as string[],
  opensAt: new Date('2026-11-11T06:00:00Z'),
  closesAt: new Date('2026-11-18T18:00:00Z'),
  createdAt: new Date('2026-11-11T06:00:00Z'),
  ...over,
});
const row = (n: number, child: Record<string, unknown> = {}) => ({
  childId: `ch-${n}`,
  child: { childUserId: `cu-${n}`, birthDate: null, age: 12, ...child },
});

describe('psych assignment push — recipients and text', () => {
  it('targets the classes and personally assigned students of the school, app-linked only', () => {
    const where = assignmentRecipientsWhere({ schoolId: 's-1', classIds: ['c-5a'], studentIds: ['st-9'] });

    expect(where).toMatchObject({
      schoolId: 's-1',
      archived: false,
      childId: { not: null },
      child: { childUserId: { not: null } },
      school: { status: 'ACTIVE' },
      linkCorrections: { none: { status: 'OPEN' } },
      OR: [{ classId: { in: ['c-5a'] } }, { id: { in: ['st-9'] } }],
    });
  });

  it('empty target — nobody', () => {
    expect(assignmentRecipientsWhere({ schoolId: 's-1', classIds: [], studentIds: [] })).toBeNull();
  });

  it('skips rows without a linked child app and removes duplicates', () => {
    const recipients = selectPsychRecipients(
      [row(1), row(1), { childId: 'ch-2', child: { childUserId: null, birthDate: null, age: 12 } }, { childId: null, child: null }],
      { iq: false, day: '2026-11-11' },
    );

    expect(recipients).toEqual([{ childId: 'ch-1', childUserId: 'cu-1' }]);
  });

  it('Parvoz IQ — only children of IQ age (9–20)', () => {
    const recipients = selectPsychRecipients([row(1, { age: 7 }), row(2, { age: 12 }), row(3, { age: null })], {
      iq: true,
      day: '2026-11-11',
    });

    expect(recipients.map((r) => r.childId)).toEqual(['ch-2']);
  });

  it('open only between opensAt and closesAt while OPEN', () => {
    expect(isOpenNow(assignment() as never, NOW)).toBe(true);
    expect(isOpenNow(assignment({ opensAt: new Date('2026-11-12T03:00:00Z') }) as never, NOW)).toBe(false);
    expect(isOpenNow(assignment({ status: 'CLOSED' }) as never, NOW)).toBe(false);
    expect(isOpenNow(assignment({ closesAt: new Date('2026-11-10T00:00:00Z') }) as never, NOW)).toBe(false);
  });

  it('push text is neutral: no test name, no "psixolog", no school', () => {
    const payload = psychAssignmentPush('uz', { id: 'as-1', iq: false });

    expect(payload).toEqual({
      title: 'Parvoz',
      body: 'Sizga yangi test yuborildi',
      data: { type: 'PSYCH_ASSIGNMENT', assignmentId: 'as-1', kind: 'TEST' },
    });
    expect(psychAssignmentPush('ru', { id: 'as-1', iq: true }).data).toEqual({
      type: 'PSYCH_ASSIGNMENT',
      assignmentId: 'as-1',
      kind: 'IQ',
    });
  });

  it('quiet hours are 22:00–07:00 Tashkent', () => {
    expect(isQuietHour(new Date('2026-11-11T16:59:00Z'))).toBe(false); // 21:59
    expect(isQuietHour(new Date('2026-11-11T17:00:00Z'))).toBe(true); // 22:00
    expect(isQuietHour(new Date('2026-11-11T01:59:00Z'))).toBe(true); // 06:59
    expect(isQuietHour(new Date('2026-11-11T02:00:00Z'))).toBe(false); // 07:00
  });
});

describe('PsychAssignmentPushService', () => {
  function setup(opts: { assignment?: unknown; opened?: unknown[]; students?: unknown[] } = {}) {
    const prisma = {
      schoolPsychAssignment: {
        findUnique: jest.fn().mockResolvedValue('assignment' in opts ? opts.assignment : assignment()),
        findMany: jest.fn().mockResolvedValue(opts.opened ?? []),
      },
      schoolStudent: { findMany: jest.fn().mockResolvedValue(opts.students ?? [row(1), row(2)]) },
    };
    const push = { sendOnce: jest.fn(async (recipients: unknown[]) => recipients.length) };
    const service = new PsychAssignmentPushService(prisma as never, push as never);
    return { prisma, push, service };
  }

  it('open assignment — pushes once per child, keyed by the assignment', async () => {
    const { service, push } = setup();

    const delivered = await service.notify('as-1', NOW);

    expect(delivered).toBe(2);
    const [recipients, kind, key, build] = push.sendOnce.mock.calls[0] as unknown as [unknown, string, string, (l: 'uz') => unknown];
    expect(recipients).toEqual([
      { childId: 'ch-1', childUserId: 'cu-1' },
      { childId: 'ch-2', childUserId: 'cu-2' },
    ]);
    expect([kind, key]).toEqual(['PSYCH_ASSIGNMENT', 'as-1']);
    expect(build('uz')).toMatchObject({ data: { type: 'PSYCH_ASSIGNMENT', assignmentId: 'as-1' } });
  });

  it('not yet open, closed or missing — no push', async () => {
    for (const a of [assignment({ opensAt: new Date('2026-11-12T03:00:00Z') }), assignment({ status: 'CANCELLED' }), null]) {
      const { service, push } = setup({ assignment: a });

      expect(await service.notify('as-1', NOW)).toBe(0);
      expect(push.sendOnce).not.toHaveBeenCalled();
    }
  });

  it('never throws: a database error returns 0', async () => {
    const { service, prisma } = setup();
    prisma.schoolPsychAssignment.findUnique.mockRejectedValue(new Error('db down'));

    await expect(service.notify('as-1', NOW)).resolves.toBe(0);
  });

  it('sweep pushes only scheduled assignments (opened later than created)', async () => {
    const scheduled = { id: 'as-2', createdAt: new Date('2026-11-10T10:00:00Z'), opensAt: new Date('2026-11-11T05:00:00Z') };
    const immediate = { id: 'as-3', createdAt: new Date('2026-11-11T06:30:00Z'), opensAt: new Date('2026-11-11T06:30:00Z') };
    const { service, prisma } = setup({ opened: [scheduled, immediate] });
    const notify = jest.spyOn(service, 'notify');

    await service.sweep(NOW);

    expect(notify.mock.calls.map((c) => c[0])).toEqual(['as-2']);
    expect(prisma.schoolPsychAssignment.findMany.mock.calls[0][0].where).toMatchObject({
      status: 'OPEN',
      opensAt: { lte: NOW },
      closesAt: { gte: NOW },
    });
  });

  it('sweep is silent during quiet hours', async () => {
    const { service, prisma } = setup();

    expect(await service.sweep(new Date('2026-11-11T20:00:00Z'))).toBe(0); // 01:00 Toshkent
    expect(prisma.schoolPsychAssignment.findMany).not.toHaveBeenCalled();
  });
});

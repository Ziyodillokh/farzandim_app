import { PushPayload } from '../../common/fcm/fcm.service';
import { AnnouncementChildPushService } from './announcement-child-push.service';

const announcement = (over: Record<string, unknown> = {}) => ({
  id: 'ann-1',
  schoolId: 's-1',
  status: 'SENT',
  title: "Ertaga sayohat",
  audience: { kind: 'CLASSES', classIds: ['c-5a'], guardianIds: [], includeStudents: true },
  ...over,
});

const studentRow = (n: number, pref: { schoolAnnouncements: boolean; hideText: boolean } | null = null) => ({
  childId: `ch-${n}`,
  child: { childUserId: `cu-${n}`, notificationPreference: pref },
});

describe('AnnouncementChildPushService', () => {
  function setup(opts: { announcement?: unknown; students?: unknown[]; claimed?: string[] } = {}) {
    const prisma = {
      schoolAnnouncement: { findUnique: jest.fn().mockResolvedValue('announcement' in opts ? opts.announcement : announcement()) },
      schoolStudent: { findMany: jest.fn().mockResolvedValue(opts.students ?? [studentRow(1), studentRow(2)]) },
    };
    const sent: Array<{ userId: string; payload: PushPayload }> = [];
    const push = {
      schoolLabel: jest.fn().mockResolvedValue('5-maktab'),
      sendOne: jest.fn(async (userId: string, build: (lang: 'uz') => PushPayload) => {
        sent.push({ userId, payload: build('uz') });
        return true;
      }),
    };
    const dedupe = { claim: jest.fn(async (ids: string[]) => opts.claimed ?? ids) };
    const service = new AnnouncementChildPushService(prisma as never, push as never, dedupe as never);
    return { prisma, push, dedupe, sent, service };
  }

  it('pushes to every linked child of the audience, neutral when hideText is on', async () => {
    const hidden = { schoolAnnouncements: true, hideText: true };
    const { service, sent, dedupe } = setup({ students: [studentRow(1, hidden), studentRow(2, hidden)] });

    const delivered = await service.notify('ann-1');

    expect(delivered).toBe(2);
    expect(sent.map((s) => s.userId)).toEqual(['cu-1', 'cu-2']);
    expect(sent[0]?.payload).toEqual({
      title: 'Parvoz',
      body: 'Maktabdan yangi eʼlon',
      data: { type: 'SCHOOL_ANNOUNCEMENT', id: 'ann-1' },
    });
    expect(dedupe.claim).toHaveBeenCalledWith(['ch-1', 'ch-2'], 'SCHOOL_ANNOUNCEMENT', 'ann-1');
  });

  it('shows the school and the title when the child has no preference row (hideText defaults to off)', async () => {
    const { service, sent } = setup({ students: [studentRow(1)] });

    await service.notify('ann-1');

    expect(sent[0]?.payload).toEqual({
      title: '5-maktab',
      body: 'Ertaga sayohat',
      data: { type: 'SCHOOL_ANNOUNCEMENT', id: 'ann-1' },
    });
  });

  it('queries only the audience students (class filter comes from the announcement audience)', async () => {
    const { service, prisma } = setup();

    await service.notify('ann-1');

    expect(prisma.schoolStudent.findMany.mock.calls[0][0].where).toMatchObject({
      schoolId: 's-1',
      archived: false,
      classId: { in: ['c-5a'] },
      childId: { not: null },
    });
  });

  it('does not push twice when the same announcement is notified again (retry / resend)', async () => {
    const { service, sent } = setup({ claimed: [] });

    const delivered = await service.notify('ann-1');

    expect(delivered).toBe(0);
    expect(sent).toHaveLength(0);
  });

  it('only pushes to the children it managed to claim', async () => {
    const { service, sent } = setup({ claimed: ['ch-2'] });

    await service.notify('ann-1');

    expect(sent.map((s) => s.userId)).toEqual(['cu-2']);
  });

  it('skips children who turned school announcements off and shows the title for hideText=false', async () => {
    const students = [
      studentRow(1, { schoolAnnouncements: false, hideText: true }),
      studentRow(2, { schoolAnnouncements: true, hideText: false }),
    ];
    const { service, sent, dedupe } = setup({ students });

    await service.notify('ann-1');

    expect(dedupe.claim).toHaveBeenCalledWith(['ch-2'], 'SCHOOL_ANNOUNCEMENT', 'ann-1');
    expect(sent).toHaveLength(1);
    expect(sent[0]?.payload).toMatchObject({ title: '5-maktab', body: 'Ertaga sayohat' });
  });

  it('does nothing for a guardians-only announcement or when students are not included', async () => {
    for (const audience of [
      { kind: 'GUARDIANS', classIds: [], guardianIds: ['g-1'], includeStudents: true },
      { kind: 'SCHOOL', classIds: [], guardianIds: [], includeStudents: false },
    ]) {
      const { service, prisma, sent } = setup({ announcement: announcement({ audience }) });

      expect(await service.notify('ann-1')).toBe(0);
      expect(prisma.schoolStudent.findMany).not.toHaveBeenCalled();
      expect(sent).toHaveLength(0);
    }
  });

  it('does nothing for an announcement that is not SENT or no longer exists', async () => {
    expect(await setup({ announcement: announcement({ status: 'DRAFT' }) }).service.notify('ann-1')).toBe(0);
    expect(await setup({ announcement: null }).service.notify('ann-1')).toBe(0);
  });

  it('never throws: a database failure is swallowed', async () => {
    const { service, prisma } = setup();
    prisma.schoolStudent.findMany.mockRejectedValue(new Error('db down'));

    await expect(service.notify('ann-1')).resolves.toBe(0);
  });
});

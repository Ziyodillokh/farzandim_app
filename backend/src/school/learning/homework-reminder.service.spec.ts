import { PushPayload } from '../../common/fcm/fcm.service';
import { HomeworkReminderService } from './homework-reminder.service';

// 12:00 UTC = 17:00 Tashkent (2026-11-06); ertaga = 2026-11-07.
const NOW = new Date('2026-11-06T12:00:00Z');

const assignment = {
  id: 'a-1',
  schoolId: 's-1',
  classIds: ['c-5a'],
  materialKind: 'TEST',
  materialId: 'test:MATH',
  dueDate: '2026-11-07',
  createdAt: new Date('2026-11-04T08:00:00Z'),
};

const studentRow = (n: number, pref: { homeworkReminder: boolean; quietFrom: string | null; quietTo: string | null } | null = null) => ({
  id: `st-${n}`,
  schoolId: 's-1',
  classId: 'c-5a',
  childId: `ch-${n}`,
  child: { childUserId: `cu-${n}`, notificationPreference: pref },
});

describe('HomeworkReminderService', () => {
  function setup(opts: { assignments?: unknown[]; students?: unknown[]; attempts?: unknown[]; claimed?: string[] } = {}) {
    const prisma = {
      schoolLearningAssignment: { findMany: jest.fn().mockResolvedValue(opts.assignments ?? [assignment]) },
      schoolStudent: { findMany: jest.fn().mockResolvedValue(opts.students ?? [studentRow(1), studentRow(2)]) },
      schoolHomeworkSubmission: { findMany: jest.fn().mockResolvedValue([]) },
      learningAttempt: { findMany: jest.fn().mockResolvedValue(opts.attempts ?? []) },
    };
    const sent: Array<{ userId: string; payload: PushPayload }> = [];
    const fcm = {
      getUserLang: jest.fn().mockResolvedValue('uz'),
      sendPushToUser: jest.fn(async (userId: string, payload: PushPayload) => {
        sent.push({ userId, payload });
        return { sent: 1, failed: 0, invalidTokens: [] };
      }),
    };
    const dedupe = { claim: jest.fn(async (ids: string[]) => opts.claimed ?? ids), prune: jest.fn().mockResolvedValue(0) };
    const service = new HomeworkReminderService(prisma as never, fcm as never, dedupe as never);
    return { prisma, fcm, dedupe, sent, service };
  }

  it('sends one neutral HOMEWORK_DUE push per child with a pending assignment due tomorrow', async () => {
    const { service, sent, dedupe } = setup();

    const count = await service.remindDue(NOW);

    expect(count).toBe(2);
    expect(sent.map((s) => s.userId).sort()).toEqual(['cu-1', 'cu-2']);
    expect(sent[0]?.payload).toEqual({ title: 'Parvoz', body: 'Ertaga topshiriq muddati', data: { type: 'HOMEWORK_DUE' } });
    expect(dedupe.claim).toHaveBeenCalledWith(['ch-1', 'ch-2'], 'HOMEWORK_DUE', '2026-11-06');
  });

  it("looks for assignments due on the next Tashkent day, using the Tashkent date even late at night UTC", async () => {
    const { service, prisma } = setup();

    // 20:30 UTC = 01:30 Tashkent on 2026-11-07 -> "ertaga" = 2026-11-08
    await service.remindDue(new Date('2026-11-06T20:30:00Z'));

    expect(prisma.schoolLearningAssignment.findMany.mock.calls[0][0].where).toMatchObject({ dueDate: '2026-11-08' });
  });

  it('does not send a second push to children already reminded today (repeated cron run)', async () => {
    const { service, sent } = setup({ claimed: [] });

    expect(await service.remindDue(NOW)).toBe(0);
    expect(sent).toHaveLength(0);
  });

  it('excludes children who completed the assigned subject test after it was given', async () => {
    const attempts = [{ childId: 'ch-1', subject: 'MATH', completedAt: new Date('2026-11-05T10:00:00Z') }];
    const { service, sent } = setup({ attempts });

    await service.remindDue(NOW);

    expect(sent.map((s) => s.userId)).toEqual(['cu-2']);
  });

  it('skips children who switched homework reminders off or are in quiet hours', async () => {
    const students = [
      studentRow(1, { homeworkReminder: false, quietFrom: null, quietTo: null }),
      studentRow(2, { homeworkReminder: true, quietFrom: '16:00', quietTo: '18:00' }),
      studentRow(3, { homeworkReminder: true, quietFrom: '22:00', quietTo: '08:00' }),
    ];
    const { service, sent, dedupe } = setup({ students });

    await service.remindDue(NOW);

    expect(sent.map((s) => s.userId)).toEqual(['cu-3']);
    // Tinch soatdagi / o'chirgan bola uchun kun "sarflanmaydi": faqat yuboriladigan bola egallanadi.
    expect(dedupe.claim).toHaveBeenCalledWith(['ch-3'], 'HOMEWORK_DUE', '2026-11-06');
  });

  it('does nothing when no assignment is due tomorrow', async () => {
    const { service, sent, prisma } = setup({ assignments: [] });

    expect(await service.remindDue(NOW)).toBe(0);
    expect(prisma.schoolStudent.findMany).not.toHaveBeenCalled();
    expect(sent).toHaveLength(0);
  });

  it('counts only pushes that FCM accepted (a child without a token is skipped silently)', async () => {
    const { service, fcm } = setup();
    fcm.sendPushToUser.mockResolvedValueOnce({ sent: 0, failed: 0, invalidTokens: [] });

    expect(await service.remindDue(NOW)).toBe(1);
  });

  it('keeps going when one push throws', async () => {
    const { service, fcm } = setup();
    fcm.sendPushToUser.mockRejectedValueOnce(new Error('fcm down'));

    await expect(service.remindDue(NOW)).resolves.toBe(1);
  });

  it('prunes old dedupe rows on every run', async () => {
    const { service, dedupe } = setup({ assignments: [] });

    await service.remindDue(NOW);

    expect(dedupe.prune).toHaveBeenCalledWith(NOW);
  });
});

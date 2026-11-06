import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { NotificationPreferencesService } from './notification-preferences.service';

describe('NotificationPreferencesService', () => {
  const PARENT = 'parent-1';
  const CHILD_USER = 'child-user-1';

  function setup(stored: Record<string, unknown> | null = null) {
    const prisma = {
      child: { findUnique: jest.fn().mockResolvedValue({ id: 'child-1', parentId: PARENT, childUserId: CHILD_USER }) },
      notificationPreference: {
        findUnique: jest.fn().mockResolvedValue(stored),
        upsert: jest.fn(async ({ create }: { create: Record<string, unknown> }) => ({ ...create })),
      },
    };
    return { prisma, service: new NotificationPreferencesService(prisma as never) };
  }

  describe('get', () => {
    it('returns the documented defaults when no row exists', async () => {
      const { service } = setup();

      expect(await service.get('child-1', CHILD_USER)).toEqual({
        studyNudge: true,
        healthNudge: true,
        contentReminder: true,
        quietFrom: null,
        quietTo: null,
        homeworkReminder: true,
        schoolAnnouncements: true,
        familyMessages: true,
        dailyReminder: true,
        dailyReminderTime: '18:00',
        hideText: true,
      });
    });

    it('does not leak internal columns of the stored row', async () => {
      const { service } = setup({ id: 'x', childId: 'child-1', lastStudyNudgeAt: new Date(), hideText: false });

      const prefs = await service.get('child-1', PARENT);

      expect(prefs).not.toHaveProperty('id');
      expect(prefs).not.toHaveProperty('lastStudyNudgeAt');
      expect(prefs.hideText).toBe(false);
    });

    it('rejects a user who is neither the child nor the parent, and a missing child', async () => {
      const { service, prisma } = setup();

      await expect(service.get('child-1', 'stranger')).rejects.toBeInstanceOf(ForbiddenException);
      prisma.child.findUnique.mockResolvedValue(null);
      await expect(service.get('nope', PARENT)).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('update', () => {
    it('saves only the provided fields (partial update)', async () => {
      const { service, prisma } = setup();

      await service.update('child-1', CHILD_USER, { hideText: false, dailyReminderTime: '07:30' });

      expect(prisma.notificationPreference.upsert).toHaveBeenCalledWith({
        where: { childId: 'child-1' },
        create: { childId: 'child-1', hideText: false, dailyReminderTime: '07:30' },
        update: { hideText: false, dailyReminderTime: '07:30' },
      });
    });

    it.each(['05:59', '21:01', '6:00', '25:00', '18:60', 'abc', '', null, 1800])(
      'rejects dailyReminderTime %p with 400 VALIDATION and saves nothing',
      async (value) => {
        const { service, prisma } = setup();

        const call = service.update('child-1', CHILD_USER, { dailyReminderTime: value as never });

        await expect(call).rejects.toBeInstanceOf(BadRequestException);
        await expect(call).rejects.toMatchObject({ response: { code: 'VALIDATION' } });
        expect(prisma.notificationPreference.upsert).not.toHaveBeenCalled();
      },
    );

    it.each(['06:00', '21:00', '18:45'])('accepts dailyReminderTime %s', async (value) => {
      const { service } = setup();

      const result = await service.update('child-1', CHILD_USER, { dailyReminderTime: value });

      expect(result.dailyReminderTime).toBe(value);
    });

    it('lets both the parent and the child update, but not a stranger', async () => {
      const { service } = setup();

      await expect(service.update('child-1', PARENT, { familyMessages: false })).resolves.toMatchObject({ familyMessages: false });
      await expect(service.update('child-1', CHILD_USER, { familyMessages: false })).resolves.toBeDefined();
      await expect(service.update('child-1', 'stranger', { familyMessages: false })).rejects.toBeInstanceOf(ForbiddenException);
    });
  });
});

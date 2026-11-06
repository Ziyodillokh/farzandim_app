import { ChildDataPurgeService } from './child-data-purge.service';
import { UsersService } from '../users/users.service';
import { BUCKETS } from '../../common/storage/storage.constants';

/**
 * F15/F40: bola o'z akkauntini o'chirsa — uning ma'lumotlari o'chadi, ota-ona
 * profili QOLADI (qayta ulash mumkin); ota-ona profilni o'chirsa — bola User'i
 * va media ham o'chadi.
 */
describe('ChildDataPurgeService', () => {
  const PARENT = 'parent-1';
  const CHILD_USER = 'child-user-1';
  const CHILD_ID = 'child-1';

  function makePrisma() {
    const prisma = {
      child: {
        findUnique: jest.fn(),
        update: jest.fn().mockResolvedValue({}),
        delete: jest.fn().mockResolvedValue({}),
      },
      user: {
        findUnique: jest.fn().mockResolvedValue({ avatarUrl: 'users/c.jpg' }),
        delete: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      photoRequest: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ photoPath: 'photo-requests/p.jpg', thumbnailPath: null }]),
        deleteMany: jest.fn().mockResolvedValue({}),
      },
      aiMessage: { deleteMany: jest.fn().mockResolvedValue({}) },
      schoolHomeworkPhoto: { findMany: jest.fn().mockResolvedValue([]) },
      schoolHomeworkSubmission: { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
      schoolStudent: { findMany: jest.fn().mockResolvedValue([{ id: 'student-1' }]) },
      schoolCareRequest: {
        findMany: jest.fn().mockResolvedValue([{ id: 'req-1' }]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      schoolCareParticipation: { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) },
      schoolCareAnonResponse: { deleteMany: jest.fn() },
      schoolStaffNotification: { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) },
      schoolPsychAssignment: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        findMany: jest.fn().mockResolvedValue([]),
        update: jest.fn().mockResolvedValue({}),
      },
      kelajakSession: { deleteMany: jest.fn().mockResolvedValue({ count: 2 }) },
      schoolStudentInvite: {
        findMany: jest.fn().mockResolvedValue([{ id: 'invite-1' }]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      schoolLinkCorrection: {
        findMany: jest.fn().mockResolvedValue([{ id: 'corr-1' }]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      childDataDeletionRequest: {
        findMany: jest.fn().mockResolvedValue([{ id: 'dr-1' }]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      voiceMessage: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ storagePath: 'v/1.m4a', mediaKey: 'chat/1.jpg' }]),
      },
      videoMessage: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ storagePath: 'vid/1.mp4', thumbnailPath: 'vid/1.jpg' }]),
      },
      supportMessage: {
        findMany: jest.fn().mockResolvedValue([{ attachmentKey: null }]),
        deleteMany: jest.fn().mockResolvedValue({}),
      },
      notification: { create: jest.fn().mockResolvedValue({}) },
      $transaction: jest.fn(),
    };
    prisma.$transaction.mockImplementation((fn: (tx: unknown) => unknown) =>
      fn(prisma),
    );
    return prisma;
  }

  let prisma: ReturnType<typeof makePrisma>;
  let storage: { delete: jest.Mock };
  let fcm: { sendPushToUser: jest.Mock; getUserLang: jest.Mock };
  let realtime: { emitToUser: jest.Mock };
  let service: ChildDataPurgeService;

  beforeEach(() => {
    prisma = makePrisma();
    storage = { delete: jest.fn().mockResolvedValue(undefined) };
    fcm = {
      sendPushToUser: jest.fn().mockResolvedValue({ sent: 1 }),
      getUserLang: jest.fn().mockResolvedValue('en'),
    };
    realtime = { emitToUser: jest.fn() };
    service = new ChildDataPurgeService(
      prisma as never,
      storage as never,
      fcm as never,
      realtime as never,
    );
  });

  describe('deleteChildAccount (child deletes own account)', () => {
    beforeEach(() => {
      prisma.child.findUnique.mockResolvedValue({
        id: CHILD_ID,
        parentId: PARENT,
        name: 'Ali',
        childUserId: CHILD_USER,
        photoPath: 'child-avatars/child-1.jpg',
      });
    });

    it('keeps the parent-owned profile and frees it for re-pairing', async () => {
      // Act
      const result = await service.deleteChildAccount(CHILD_USER);

      // Assert
      expect(prisma.child.delete).not.toHaveBeenCalled();
      expect(prisma.child.update).toHaveBeenCalledWith({
        where: { id: CHILD_ID },
        data: expect.objectContaining({
          childUserId: null,
          isConnected: false,
          pairedAt: null,
          photoPath: null,
        }),
      });
      expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: CHILD_USER } });
      expect(result).toEqual({ childId: CHILD_ID, mediaObjects: 7 });
    });

    it("deletes the child's messages, photos and stored files", async () => {
      await service.deleteChildAccount(CHILD_USER);

      expect(prisma.photoRequest.deleteMany).toHaveBeenCalledWith({
        where: { childId: CHILD_ID },
      });
      expect(prisma.aiMessage.deleteMany).toHaveBeenCalledWith({
        where: { childId: CHILD_ID },
      });
      expect(prisma.supportMessage.deleteMany).toHaveBeenCalledWith({
        where: { userId: CHILD_USER },
      });
      // Kelajak javoblari (farovonlik, ochiq matn) ham o'chadi — javoblar cascade.
      expect(prisma.kelajakSession.deleteMany).toHaveBeenCalledWith({
        where: { childId: CHILD_ID },
      });
      const deleted = storage.delete.mock.calls.map((c) => `${c[0]}:${c[1]}`);
      expect(deleted).toEqual(
        expect.arrayContaining([
          `${BUCKETS.avatars}:child-avatars/child-1.jpg`,
          `${BUCKETS.avatars}:users/c.jpg`,
          `${BUCKETS.avatars}:photo-requests/p.jpg`,
          `${BUCKETS.voice}:v/1.m4a`,
          `${BUCKETS.chat}:chat/1.jpg`,
          `${BUCKETS.video}:vid/1.mp4`,
          `${BUCKETS.video}:vid/1.jpg`,
        ]),
      );
    });

    it("deletes the child's school homework submissions and photo objects", async () => {
      prisma.schoolHomeworkPhoto.findMany.mockResolvedValue([{ key: 'homework/s/a/st/1.jpg' }, { key: 'homework/s/a/st/2.png' }]);

      const result = await service.deleteChildAccount(CHILD_USER);

      expect(prisma.schoolHomeworkPhoto.findMany).toHaveBeenCalledWith({
        where: { submission: { student: { childId: { in: [CHILD_ID] } } } },
        select: { key: true },
      });
      expect(prisma.schoolHomeworkSubmission.deleteMany).toHaveBeenCalledWith({ where: { student: { childId: { in: [CHILD_ID] } } } });
      const deleted = storage.delete.mock.calls.map((c) => `${c[0]}:${c[1]}`);
      expect(deleted).toEqual(
        expect.arrayContaining([
          `${BUCKETS.schoolHomework}:homework/s/a/st/1.jpg`,
          `${BUCKETS.schoolHomework}:homework/s/a/st/2.png`,
        ]),
      );
      expect(result.mediaObjects).toBe(9);
    });

    it("deletes the child's care requests and survey participation, never the anonymous answers", async () => {
      await service.deleteChildAccount(CHILD_USER);

      expect(prisma.schoolStudent.findMany).toHaveBeenCalledWith({ where: { childId: { in: [CHILD_ID] } }, select: { id: true } });
      expect(prisma.schoolCareRequest.deleteMany).toHaveBeenCalledWith({ where: { studentId: { in: ['student-1'] } } });
      expect(prisma.schoolCareParticipation.deleteMany).toHaveBeenCalledWith({ where: { studentId: { in: ['student-1'] } } });
      expect(prisma.schoolStaffNotification.deleteMany).toHaveBeenCalledWith({
        where: { id: { in: ['care:req-1', 'care-esc:req-1', expect.stringMatching(/^care-esc-dir:[0-9a-f]{32}$/)] } },
      });
      expect(prisma.schoolPsychAssignment.updateMany).toHaveBeenCalledWith({ where: { careRequestId: { in: ['req-1'] } }, data: { careRequestId: null } });
      expect(prisma.schoolCareAnonResponse.deleteMany).not.toHaveBeenCalled();
    });

    it("deletes the child's data-deletion requests and their staff notification (the profile stays, so no cascade)", async () => {
      await service.deleteChildAccount(CHILD_USER);

      expect(prisma.childDataDeletionRequest.findMany).toHaveBeenCalledWith({
        where: { childId: { in: [CHILD_ID] } },
        select: { id: true },
      });
      expect(prisma.schoolStaffNotification.deleteMany).toHaveBeenCalledWith({
        where: { id: { in: ['data-deletion:dr-1'] } },
      });
      expect(prisma.childDataDeletionRequest.deleteMany).toHaveBeenCalledWith({
        where: { childId: { in: [CHILD_ID] } },
      });
    });

    it("removes the student from personal assignments' studentIds and target.studentIds (assignment itself stays)", async () => {
      prisma.schoolPsychAssignment.findMany.mockResolvedValue([
        { id: 'a-1', studentIds: ['student-1', 'student-2'], target: { kind: 'STUDENTS', studentIds: ['student-1', 'student-2'] } },
        { id: 'a-2', studentIds: ['student-1'], target: { kind: 'STUDENTS', studentIds: ['student-1'] } },
      ]);

      await service.deleteChildAccount(CHILD_USER);

      expect(prisma.schoolPsychAssignment.findMany).toHaveBeenCalledWith({
        where: { studentIds: { hasSome: ['student-1'] } },
        select: { id: true, studentIds: true, target: true },
      });
      expect(prisma.schoolPsychAssignment.update).toHaveBeenCalledWith({
        where: { id: 'a-1' },
        data: { studentIds: ['student-2'], target: { kind: 'STUDENTS', studentIds: ['student-2'] } },
      });
      // Bo'shab qolgan tayinlash o'chirilmaydi va shaxsiy (`kind: STUDENTS`) bo'lib qoladi.
      expect(prisma.schoolPsychAssignment.update).toHaveBeenCalledWith({
        where: { id: 'a-2' },
        data: { studentIds: [], target: { kind: 'STUDENTS', studentIds: [] } },
      });
    });

    it('notifies the parent with a push and a notification record', async () => {
      await service.deleteChildAccount(CHILD_USER);

      expect(prisma.notification.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          childId: CHILD_ID,
          type: 'SYSTEM',
          title: 'Ali — device disconnected',
        }),
      });
      expect(fcm.sendPushToUser).toHaveBeenCalledWith(
        PARENT,
        expect.objectContaining({
          data: expect.objectContaining({ type: 'child_disconnected', childId: CHILD_ID }),
        }),
      );
    });

    it('still succeeds when the parent push fails', async () => {
      fcm.sendPushToUser.mockRejectedValue(new Error('fcm down'));

      await expect(service.deleteChildAccount(CHILD_USER)).resolves.toEqual(
        expect.objectContaining({ childId: CHILD_ID }),
      );
    });

    it('deletes an orphan child user without a profile', async () => {
      prisma.child.findUnique.mockResolvedValue(null);

      const result = await service.deleteChildAccount(CHILD_USER);

      expect(prisma.child.update).not.toHaveBeenCalled();
      expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: CHILD_USER } });
      expect(fcm.sendPushToUser).not.toHaveBeenCalled();
      expect(result.childId).toBeNull();
    });
  });

  describe('purgeChildProfile (parent deletes the profile)', () => {
    it('deletes the profile, the child user and media, and unpairs the device', async () => {
      const result = await service.purgeChildProfile({
        id: CHILD_ID,
        parentId: PARENT,
        name: 'Ali',
        childUserId: CHILD_USER,
        photoPath: 'child-avatars/child-1.jpg',
      });

      expect(prisma.child.delete).toHaveBeenCalledWith({ where: { id: CHILD_ID } });
      expect(prisma.user.deleteMany).toHaveBeenCalledWith({
        where: { id: CHILD_USER, role: 'CHILD' },
      });
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        CHILD_USER,
        'child:unpaired',
        expect.objectContaining({ childId: CHILD_ID }),
      );
      expect(storage.delete).toHaveBeenCalledWith(
        BUCKETS.avatars,
        'child-avatars/child-1.jpg',
      );
      expect(result).toEqual({ childUserDeleted: true, mediaObjects: 7 });
    });

    it('deletes school homework submissions BEFORE the profile (student link is SetNull) and their photo objects', async () => {
      prisma.schoolHomeworkPhoto.findMany.mockResolvedValue([{ key: 'homework/s/a/st/1.jpg' }]);
      const order: string[] = [];
      prisma.schoolHomeworkSubmission.deleteMany.mockImplementation(async () => {
        order.push('homework');
        return { count: 1 };
      });
      prisma.child.delete.mockImplementation(async () => {
        order.push('child');
        return {};
      });

      await service.purgeChildProfile({ id: CHILD_ID, parentId: PARENT, name: 'Ali', childUserId: CHILD_USER, photoPath: null });

      expect(order).toEqual(['homework', 'child']);
      expect(storage.delete).toHaveBeenCalledWith(BUCKETS.schoolHomework, 'homework/s/a/st/1.jpg');
    });

    it('deletes care requests and participation BEFORE the profile (student link is SetNull)', async () => {
      const order: string[] = [];
      prisma.schoolCareRequest.deleteMany.mockImplementation(async () => {
        order.push('care-requests');
        return { count: 1 };
      });
      prisma.schoolCareParticipation.deleteMany.mockImplementation(async () => {
        order.push('care-participation');
        return { count: 1 };
      });
      prisma.child.delete.mockImplementation(async () => {
        order.push('child');
        return {};
      });

      await service.purgeChildProfile({ id: CHILD_ID, parentId: PARENT, name: 'Ali', childUserId: CHILD_USER, photoPath: null });

      expect(order).toEqual(['care-requests', 'care-participation', 'child']);
    });

    it('deletes data-deletion requests and their staff notification BEFORE the profile', async () => {
      const order: string[] = [];
      prisma.childDataDeletionRequest.deleteMany.mockImplementation(async () => {
        order.push('deletion-requests');
        return { count: 1 };
      });
      prisma.child.delete.mockImplementation(async () => {
        order.push('child');
        return {};
      });

      await service.purgeChildProfile({ id: CHILD_ID, parentId: PARENT, name: 'Ali', childUserId: CHILD_USER, photoPath: null });

      expect(order).toEqual(['deletion-requests', 'child']);
      expect(prisma.schoolStaffNotification.deleteMany).toHaveBeenCalledWith({
        where: { id: { in: ['data-deletion:dr-1'] } },
      });
    });

    it('works for a profile that was never paired', async () => {
      const result = await service.purgeChildProfile({
        id: CHILD_ID,
        parentId: PARENT,
        name: 'Ali',
        childUserId: null,
        photoPath: null,
      });

      expect(prisma.user.deleteMany).not.toHaveBeenCalled();
      expect(realtime.emitToUser).not.toHaveBeenCalled();
      expect(result).toEqual({ childUserDeleted: false, mediaObjects: 1 });
    });
  });
});

describe('UsersService.deleteAccount for CHILD users (F15)', () => {
  it('delegates to the child purge and does not touch parent data', async () => {
    // Arrange
    const prisma = {
      user: { findUnique: jest.fn().mockResolvedValue({ id: 'cu', role: 'CHILD' }) },
      $transaction: jest.fn(),
    };
    const purge = {
      deleteChildAccount: jest.fn().mockResolvedValue({ childId: 'c', mediaObjects: 0 }),
    };
    const audit = { log: jest.fn().mockResolvedValue(undefined) };
    const users = new UsersService(
      prisma as never,
      {} as never,
      {} as never,
      {} as never,
      audit as never,
      purge as never,
    );

    // Act
    const result = await users.deleteAccount('cu');

    // Assert
    expect(purge.deleteChildAccount).toHaveBeenCalledWith('cu');
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(result.ok).toBe(true);
  });
});

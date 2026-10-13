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

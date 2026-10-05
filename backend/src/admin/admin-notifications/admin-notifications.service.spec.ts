import { AdminNotificationsService } from './admin-notifications.service';
import { BUCKETS } from '../../common/storage/storage.constants';

/**
 * Admin bildirishnomasi rasm bilan yuborilganda rasm ilovada ko'rinishi uchun:
 *  - yuklangan rasm uchun DOIMIY ochiq media-proxy URL qaytadi (presigned emas);
 *  - push (FCM) va ilova ichidagi ro'yxatga shu URL yoziladi;
 *  - eski presigned URL kelib qolsa ham (keshlangan admin bundle) to'g'rilanadi.
 */
const BASE = 'https://farzandimedu.uz';
const OLD = (f: string) =>
  `${BASE}/storage/farzandim-content-thumbnails/notifications/${f}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc`;
const PROXY = (f: string) => `${BASE}/api/content/media/notif/${f}`;
const FILE = '1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed.jpg';

function makeService() {
  const storage = { upload: jest.fn().mockResolvedValue(undefined), getSignedUrl: jest.fn() };
  const fcm = { sendPush: jest.fn().mockResolvedValue({ sent: 2, failed: 0, invalidTokens: [] }) };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const config = { get: jest.fn((k: string) => (k === 'PUBLIC_BASE_URL' ? BASE : undefined)) };
  const now = new Date('2026-10-05T10:00:00Z');
  const prisma = {
    user: { findMany: jest.fn().mockResolvedValue([{ id: 'p1' }]) },
    fcmToken: { findMany: jest.fn().mockResolvedValue([{ token: 't1' }, { token: 't2' }]), deleteMany: jest.fn() },
    child: { findMany: jest.fn().mockResolvedValue([{ id: 'c1' }]) },
    payment: { findMany: jest.fn().mockResolvedValue([]) },
    notification: { createMany: jest.fn().mockResolvedValue({ count: 1 }) },
    adminNotification: {
      create: jest.fn(({ data }) => Promise.resolve({ id: 'n1', ...data, createdAt: now, updatedAt: now })),
      findMany: jest.fn(),
    },
  };
  const service = new AdminNotificationsService(
    prisma as never, fcm as never, audit as never, storage as never, config as never,
  );
  return { service, storage, fcm, prisma };
}

describe('AdminNotificationsService — rasmli bildirishnoma', () => {
  describe('uploadImage', () => {
    it('ochiq media-proxy URL qaytaradi, presigned URL yaratmaydi', async () => {
      const { service, storage } = makeService();
      const res = await service.uploadImage({ buffer: Buffer.from('img'), mimetype: 'image/jpeg', originalname: 'Photo.JPG' });

      expect(res.url).toMatch(/^https:\/\/farzandimedu\.uz\/api\/content\/media\/notif\/[0-9a-f-]{36}\.jpg$/);
      expect(storage.getSignedUrl).not.toHaveBeenCalled();
      expect(storage.upload).toHaveBeenCalledWith(
        BUCKETS.contentThumbnails,
        res.storageKey,
        expect.any(Buffer),
        'image/jpeg',
      );
      expect(res.url.endsWith(res.storageKey.replace('notifications/', ''))).toBe(true);
    });

    it("kengaytma fayl nomidan emas, MIME'dan olinadi", async () => {
      const { service } = makeService();
      const res = await service.uploadImage({ buffer: Buffer.from('img'), mimetype: 'image/png', originalname: 'rasm' });
      expect(res.storageKey).toMatch(/^notifications\/[0-9a-f-]{36}\.png$/);
    });
  });

  describe('create', () => {
    it('push va ilova ichidagi ro\'yxatga proxy URL yoziladi', async () => {
      const { service, fcm, prisma } = makeService();
      await service.create({ title: 'Salom', message: 'Matn', targetType: 'all', imageUrl: PROXY(FILE) } as never, 's1', {});

      expect(fcm.sendPush).toHaveBeenCalledWith(['t1', 't2'], expect.objectContaining({ image: PROXY(FILE) }));
      expect(prisma.adminNotification.create.mock.calls[0][0].data.imageUrl).toBe(PROXY(FILE));
      expect(prisma.notification.createMany.mock.calls[0][0].data[0].data).toEqual({ imageUrl: PROXY(FILE) });
    });

    it("eski presigned URL kelsa ham — to'g'rilanib yuboriladi", async () => {
      const { service, fcm, prisma } = makeService();
      await service.create({ title: 'Salom', message: 'Matn', targetType: 'all', imageUrl: OLD(FILE) } as never, 's1', {});

      expect(fcm.sendPush).toHaveBeenCalledWith(expect.any(Array), expect.objectContaining({ image: PROXY(FILE) }));
      expect(prisma.adminNotification.create.mock.calls[0][0].data.imageUrl).toBe(PROXY(FILE));
    });

    it("rasmsiz bildirishnoma — rasm maydoni yo'q", async () => {
      const { service, fcm } = makeService();
      await service.create({ title: 'Salom', message: 'Matn', targetType: 'all' } as never, 's1', {});
      expect(fcm.sendPush.mock.calls[0][1].image).toBeUndefined();
    });
  });

  describe('list', () => {
    it("tarixdagi eski rasm URL'lari ham proxy ko'rinishida qaytadi", async () => {
      const { service, prisma } = makeService();
      const t = new Date('2026-10-01T00:00:00Z');
      prisma.adminNotification.findMany.mockResolvedValue([
        { id: 'n0', title: 'a', message: 'b', targetType: 'all', imageUrl: OLD(FILE), status: 'sent', createdAt: t, updatedAt: t },
      ]);
      const rows = await service.list({});
      expect(rows[0].imageUrl).toBe(PROXY(FILE));
    });
  });
});

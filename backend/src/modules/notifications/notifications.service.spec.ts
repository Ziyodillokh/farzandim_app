import { NotificationsService } from './notifications.service';

/**
 * Ilova ichidagi bildirishnomalar ro'yxati (`GET /children/:id/notifications`)
 * — ota-ona va bola ilovalari `data.imageUrl` ni ko'rsatadi. Avval saqlangan
 * eski presigned URL'lar (telefonga yetmaydi, 6 kunda eskiradi) javobda
 * ochiq proxy URL'ga almashtiriladi — ilovani o'zgartirmasdan eski
 * bildirishnomalardagi rasm ham ko'rinadi.
 */
const BASE = 'https://farzandimedu.uz';
const FILE = '1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed.jpg';

describe('NotificationsService.listByChild — rasm URL', () => {
  it("data.imageUrl proxy URL'ga to'g'rilanadi, qolgan maydonlar saqlanadi", async () => {
    const rows = [
      {
        id: 'x1', childId: 'c1', type: 'SYSTEM', title: 't', body: 'b', isRead: false, createdAt: new Date(),
        data: { imageUrl: `${BASE}/storage/farzandim-content-thumbnails/notifications/${FILE}?X-Amz-Signature=a`, deepLink: 'farzandim://videos' },
      },
      { id: 'x2', childId: 'c1', type: 'SYSTEM', title: 't2', body: 'b2', isRead: true, createdAt: new Date(), data: null },
    ];
    const prisma = {
      child: { findUnique: jest.fn().mockResolvedValue({ id: 'c1', parentId: 'u1', childUserId: 'u2' }) },
      notification: { findMany: jest.fn().mockResolvedValueOnce(rows).mockResolvedValueOnce([]) },
    };
    const config = { get: jest.fn(() => BASE) };
    const service = new NotificationsService(prisma as never, {} as never, {} as never, config as never);

    const res = await service.listByChild('u1', 'c1', {} as never);

    expect(res.notifications[0].data).toEqual({
      imageUrl: `${BASE}/api/content/media/notif/${FILE}`,
      deepLink: 'farzandim://videos',
    });
    expect(res.notifications[1].data).toBeNull();
    expect(res.count).toBe(2);
  });
});

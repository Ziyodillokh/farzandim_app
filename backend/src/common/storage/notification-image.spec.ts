import {
  newNotificationImageKey,
  normalizeNotificationData,
  normalizeNotificationImageUrl,
  notificationImageUrl,
} from './notification-image';

/**
 * Fon: admin bildirishnomasi rasmi avval 6 kunlik presigned MinIO URL bilan
 * saqlanardi. Prod'da MINIO_PUBLIC_URL=https://farzandimedu.uz/storage —
 * imzo `/storage/...` yo'li bilan hisoblanadi, nginx esa `/storage/` ni kesib
 * MinIO'ga uzatadi → SignatureDoesNotMatch (403). Telefon rasmni ololmasdi.
 * Endi rasm doimiy ochiq media-proxy URL orqali beriladi.
 */
const BASE = 'https://farzandimedu.uz';
const UUID = '1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed';

describe('Bildirishnoma rasmi URL', () => {
  describe('notificationImageUrl', () => {
    it("storageKey → ochiq media-proxy URL", () => {
      expect(notificationImageUrl(BASE, `notifications/${UUID}.jpg`)).toBe(
        `${BASE}/api/content/media/notif/${UUID}.jpg`,
      );
    });

    it("base oxiridagi '/' ikki marta qo'shilmaydi", () => {
      expect(notificationImageUrl(`${BASE}/`, `notifications/${UUID}.png`)).toBe(
        `${BASE}/api/content/media/notif/${UUID}.png`,
      );
    });
  });

  describe('newNotificationImageKey', () => {
    it.each([
      ['image/jpeg', 'jpg'],
      ['image/png', 'png'],
      ['image/webp', 'webp'],
      ['image/gif', 'gif'],
    ])("%s → .%s kengaytma (fayl nomiga emas, MIME'ga tayanadi)", (mime, ext) => {
      expect(newNotificationImageKey(mime)).toMatch(
        new RegExp(`^notifications/[0-9a-f-]{36}\\.${ext}$`),
      );
    });

    it('har chaqiruvda yangi kalit', () => {
      expect(newNotificationImageKey('image/jpeg')).not.toBe(newNotificationImageKey('image/jpeg'));
    });
  });

  describe('normalizeNotificationImageUrl', () => {
    it("prod'dagi eski presigned URL (/storage/...) → proxy URL", () => {
      const old =
        `${BASE}/storage/farzandim-content-thumbnails/notifications/${UUID}.jpg` +
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=518400&X-Amz-Signature=abc';
      expect(normalizeNotificationImageUrl(old, BASE)).toBe(
        `${BASE}/api/content/media/notif/${UUID}.jpg`,
      );
    });

    it('ichki MinIO manzilidagi presigned URL ham → proxy URL', () => {
      const old = `http://127.0.0.1:9100/farzandim-content-thumbnails/notifications/${UUID}.png?X-Amz-Signature=x`;
      expect(normalizeNotificationImageUrl(old, BASE)).toBe(
        `${BASE}/api/content/media/notif/${UUID}.png`,
      );
    });

    it("allaqachon proxy URL — o'zgarmaydi", () => {
      const ok = `${BASE}/api/content/media/notif/${UUID}.jpg`;
      expect(normalizeNotificationImageUrl(ok, BASE)).toBe(ok);
    });

    it("tashqi rasm URL'i — o'zgarmaydi", () => {
      expect(normalizeNotificationImageUrl('https://example.com/a.jpg', BASE)).toBe(
        'https://example.com/a.jpg',
      );
    });

    it("boshqa bucket/papka — o'zgarmaydi", () => {
      const other = `${BASE}/storage/farzandim-content-thumbnails/thumbnails/${UUID}.jpg?X-Amz-Signature=x`;
      expect(normalizeNotificationImageUrl(other, BASE)).toBe(other);
    });

    it("URL ichida (query'da) uchragan bucket yo'li — o'zgarmaydi", () => {
      const tricky = `https://example.com/r?u=/farzandim-content-thumbnails/notifications/${UUID}.jpg`;
      expect(normalizeNotificationImageUrl(tricky, BASE)).toBe(tricky);
    });

    it("yo'l aylanib o'tish urinishi — o'zgarmaydi", () => {
      const bad = `${BASE}/storage/farzandim-content-thumbnails/notifications/../secret.jpg`;
      expect(normalizeNotificationImageUrl(bad, BASE)).toBe(bad);
    });

    it.each([null, undefined, ''])("%p — o'zgarishsiz qaytadi", (v) => {
      expect(normalizeNotificationImageUrl(v, BASE)).toBe(v);
    });
  });

  describe('normalizeNotificationData', () => {
    it("data.imageUrl to'g'rilanadi, qolgan maydonlar saqlanadi", () => {
      const data = {
        imageUrl: `${BASE}/storage/farzandim-content-thumbnails/notifications/${UUID}.jpg?X-Amz-Signature=x`,
        deepLink: 'farzandim://videos',
      };
      expect(normalizeNotificationData(data, BASE)).toEqual({
        imageUrl: `${BASE}/api/content/media/notif/${UUID}.jpg`,
        deepLink: 'farzandim://videos',
      });
    });

    it("asl obyekt o'zgartirilmaydi (yangi obyekt qaytadi)", () => {
      const data = { imageUrl: `${BASE}/storage/farzandim-content-thumbnails/notifications/${UUID}.jpg?s=1` };
      const out = normalizeNotificationData(data, BASE);
      expect(out).not.toBe(data);
      expect(data.imageUrl).toContain('/storage/');
    });

    it.each([null, undefined, 'matn', 5, ['a']])("%p — o'zgarishsiz", (v) => {
      expect(normalizeNotificationData(v, BASE)).toBe(v);
    });

    it("imageUrl'siz obyekt — o'sha obyektning o'zi qaytadi", () => {
      const data = { senderId: 'u1' };
      expect(normalizeNotificationData(data, BASE)).toBe(data);
    });
  });
});

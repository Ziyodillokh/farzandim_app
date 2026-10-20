import { randomUUID } from 'crypto';
import { BUCKETS } from './storage.constants';

/**
 * Admin bildirishnomasi rasmlari — MinIO `farzandim-content-thumbnails`
 * bucket'ida `notifications/<uuid>.<ext>` kaliti bilan saqlanadi va telefonga
 * @Public media-proxy orqali beriladi:
 *
 *   <PUBLIC_BASE_URL>/api/content/media/notif/<uuid>.<ext>
 *
 * Nega presigned URL emas: prod'da MINIO_PUBLIC_URL=https://<domen>/storage,
 * imzo `/storage/...` yo'li bilan hisoblanadi, nginx esa `/storage/` ni kesib
 * MinIO'ga uzatadi → SignatureDoesNotMatch (403). Ustiga presigned URL 6 kunda
 * eskiradi. Kontent, avatar, ovozli xabarlar ham shu sababli proxy orqali.
 */
export const NOTIFICATION_IMAGE_PREFIX = 'notifications/';
export const NOTIFICATION_MEDIA_SEGMENT = 'notif';

const EXT_BY_MIME: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

/**
 * Eski presigned URL: `<scheme>://<host>[/storage]/farzandim-content-thumbnails/notifications/<fayl>`
 * (+ ixtiyoriy query). Boshidan langarlangan — URL ichida (masalan query'da)
 * uchragan shu yo'l qayta yozilmaydi.
 */
const LEGACY_URL = new RegExp(
  `^https?://[^/?#]+(?:/storage)?/${BUCKETS.contentThumbnails}/${NOTIFICATION_IMAGE_PREFIX}([A-Za-z0-9_-]+\\.[A-Za-z0-9]+)(?:[?#]|$)`,
);

/** Yangi storage kaliti; kengaytma ishonchsiz fayl nomidan emas, MIME'dan. */
export function newNotificationImageKey(mimetype: string): string {
  const ext = EXT_BY_MIME[mimetype] ?? 'jpg';
  return `${NOTIFICATION_IMAGE_PREFIX}${randomUUID()}.${ext}`;
}

/** storageKey → doimiy ochiq URL. */
export function notificationImageUrl(baseUrl: string, storageKey: string): string {
  const file = storageKey.split('/').pop() ?? '';
  return `${baseUrl.replace(/\/+$/, '')}/api/content/media/${NOTIFICATION_MEDIA_SEGMENT}/${file}`;
}

/**
 * Eski (presigned) bildirishnoma rasm URL'ini ochiq proxy URL'ga almashtiradi.
 * Boshqa har qanday qiymat (proxy URL, tashqi rasm, bo'sh) o'zgarishsiz qaytadi.
 */
export function normalizeNotificationImageUrl<T extends string | null | undefined>(
  url: T,
  baseUrl: string,
): T | string {
  if (!url) return url;
  const m = LEGACY_URL.exec(url);
  return m ? notificationImageUrl(baseUrl, m[1]) : url;
}

/** Notification.data (JSON) ichidagi `imageUrl` ni to'g'rilaydi — asl obyektni o'zgartirmaydi. */
export function normalizeNotificationData<T>(data: T, baseUrl: string): T {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return data;
  const imageUrl = (data as { imageUrl?: unknown }).imageUrl;
  if (typeof imageUrl !== 'string') return data;
  const fixed = normalizeNotificationImageUrl(imageUrl, baseUrl);
  return fixed === imageUrl ? data : ({ ...data, imageUrl: fixed } as T);
}

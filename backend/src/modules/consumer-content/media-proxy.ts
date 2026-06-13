import { FastifyRequest } from 'fastify';

// Content media (audio/muqova/video/pdf) uchun @Public proxy segment'lari.
export type MediaSegment = 'audio' | 'thumb' | 'cover' | 'video' | 'pdf';

/**
 * So'rov kelgan domendan absolyut origin quradi (https://host).
 * Domen-mustaqil: prod (farzandimedu.uz) ham, test (test.farzandimedu.uz)
 * ham bir xil ishlaydi — proxy URL doim klient ulangan domenda bo'ladi.
 */
export function requestOrigin(req: FastifyRequest): string {
  const proto =
    (req.headers['x-forwarded-proto'] as string | undefined) ?? 'https';
  const host = req.headers.host ?? '';
  return `${proto}://${host}`;
}

/**
 * storageKey ('audio/<uuid>.m4a') dan @Public proxy URL quradi:
 * `<origin>/api/content/media/audio/<uuid>.m4a`.
 *
 * Nega kerak: xom signed MinIO URL telefondan yetib bo'lmaydi (ichki
 * manzil) — voice/video media kabi backend orqali proxy qilamiz.
 * storageKey null bo'lsa (masalan link orqali qo'shilgan YouTube video)
 * `null` qaytadi — chaqiruvchi asl tashqi url'ni ishlatadi.
 */
export function mediaProxyUrl(
  origin: string,
  segment: MediaSegment,
  storageKey: string | null | undefined,
): string | null {
  if (!storageKey) return null;
  const file = storageKey.split('/').pop();
  if (!file) return null;
  return `${origin}/api/content/media/${segment}/${file}`;
}

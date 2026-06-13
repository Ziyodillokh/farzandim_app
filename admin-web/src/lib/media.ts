// Content media (@Public proxy) URL'lari — backend xom signed MinIO URL
// o'rniga `/api/content/media/<segment>/<file>` proxy beradi (telefon va
// brauzer ikkalasiga ham yetadi). Admin shu yerda storageKey'dan URL quradi.
const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api';

export type MediaSegment = 'audio' | 'thumb' | 'video' | 'pdf';

export function contentMediaUrl(
  segment: MediaSegment,
  storageKey?: string | null,
): string | null {
  if (!storageKey) return null;
  const file = storageKey.split('/').pop();
  if (!file) return null;
  return `${API_BASE}/content/media/${segment}/${file}`;
}

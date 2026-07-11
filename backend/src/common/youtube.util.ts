// ─────────────────────────────────────────────────────────────────────
// YouTube util — havoladan video ID + avtomatik thumbnail (banner)
// ─────────────────────────────────────────────────────────────────────
//
// "Link orqali" qo'shilgan videolar (YouTube) uchun banner qo'lda
// yuklanmasa, video ID'sidan YouTube'ning tayyor thumbnail'i olinadi.
// Regex HOST-scoped: ID youtube domeni oldidan kelishi shart — `.mp4?v=...`
// kabi to'g'ridan-to'g'ri havolalar (cache-buster `?v=`) xato YouTube deb
// topilmasligi uchun (bola `video_model.dart` bilan AYNI mantiq).

const YT_RE =
  /(?:youtu\.be\/|youtube\.com\/(?:watch\?(?:[^&\s]*&)*v=|embed\/|shorts\/|live\/|v\/))([\w-]{11})/;

/** YouTube havolasidan 11 belgili video ID. YouTube emas bo'lsa `null`. */
export function youtubeId(url: string | null | undefined): string | null {
  if (!url) return null;
  const m = YT_RE.exec(url.trim());
  return m ? m[1] : null;
}

/**
 * YouTube havolasidan avtomatik thumbnail URL (banner). `hqdefault` — barcha
 * videolarda mavjud (480×360). YouTube emas bo'lsa `null`.
 */
export function youtubeThumbnail(url: string | null | undefined): string | null {
  const id = youtubeId(url);
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : null;
}

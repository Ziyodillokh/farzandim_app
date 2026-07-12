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

/**
 * YouTube videosining DAVOMIYLIGI (soniya) — watch sahifasidan `lengthSeconds`
 * ni o'qib. API kaliti KERAK EMAS. Best-effort: xato/topilmasa `null`
 * (create'ni bloklamaydi). Bola app aniq vaqtni ko'rsatishi uchun.
 */
export async function youtubeDuration(
  url: string | null | undefined,
): Promise<number | null> {
  const id = youtubeId(url);
  if (!id) return null;
  try {
    const res = await fetch(`https://www.youtube.com/watch?v=${id}`, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    });
    if (!res.ok) return null;
    const html = await res.text();
    const m = html.match(/"lengthSeconds":"(\d+)"/);
    if (m) {
      const sec = parseInt(m[1], 10);
      return Number.isFinite(sec) && sec > 0 ? sec : null;
    }
  } catch {
    // Tarmoq/format xatosi — jim (best-effort).
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// geo-ip — Faol sessiyalar uchun IP → shahar/davlat
// ─────────────────────────────────────────────────────────────────────
//
// Backend nginx orqasida ishlaydi, shu sababli real client IP
// `x-forwarded-for` header'ining BIRINCHI hop'ida bo'ladi (`req.ip`
// emas — u proxy IP qaytaradi). Geo aniqlash ip-api.com (bepul, kalitsiz)
// orqali, qisqa timeout + xato bo'lsa null fallback bilan.

export interface ReqMeta {
  ip?: string;
  headers?: Record<string, string | string[] | undefined>;
}

/** Header'lardan real client IP — `x-forwarded-for` birinchi hop. */
export function extractClientIp(reqMeta?: ReqMeta): string | null {
  if (!reqMeta) return null;
  const xff = reqMeta.headers?.['x-forwarded-for'];
  const raw = Array.isArray(xff) ? xff[0] : xff;
  if (raw && typeof raw === 'string') {
    const first = raw.split(',')[0]?.trim();
    if (first) return normalizeIp(first);
  }
  if (reqMeta.ip) return normalizeIp(reqMeta.ip);
  return null;
}

/** IPv6-mapped IPv4 (`::ffff:1.2.3.4`) → `1.2.3.4`. */
function normalizeIp(ip: string): string {
  return ip.startsWith('::ffff:') ? ip.slice(7) : ip;
}

/** Private/loopback IP — geo aniqlashga arzimaydi. */
function isPrivateIp(ip: string): boolean {
  if (ip === '127.0.0.1' || ip === '::1' || ip === 'localhost') return true;
  if (ip.startsWith('10.') || ip.startsWith('192.168.')) return true;
  // 172.16.0.0 – 172.31.255.255
  const m = /^172\.(\d{1,3})\./.exec(ip);
  if (m) {
    const second = Number(m[1]);
    if (second >= 16 && second <= 31) return true;
  }
  return false;
}

export interface GeoResult {
  city: string | null;
  country: string | null;
}

/**
 * IP → { city, country }. Xato/timeout/private bo'lsa null'lar qaytadi.
 * Login'ni sekinlashtirmaslik uchun fire-and-forget chaqiriladi.
 */
export async function resolveGeo(ip: string | null): Promise<GeoResult> {
  const empty: GeoResult = { city: null, country: null };
  if (!ip || isPrivateIp(ip)) return empty;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2500);
  try {
    const res = await fetch(
      `http://ip-api.com/json/${encodeURIComponent(ip)}?fields=status,country,city`,
      { signal: controller.signal },
    );
    if (!res.ok) return empty;
    const data = (await res.json()) as {
      status?: string;
      country?: string;
      city?: string;
    };
    if (data.status !== 'success') return empty;
    return {
      city: data.city?.trim() || null,
      country: data.country?.trim() || null,
    };
  } catch {
    return empty;
  } finally {
    clearTimeout(timeout);
  }
}

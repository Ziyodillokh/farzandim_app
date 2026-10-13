import { createHmac, timingSafeEqual } from 'crypto';

// ─────────────────────────────────────────────────────────────────────
// Bola rasmi proksisi uchun qisqa muddatli IMZOLANGAN havola
// ─────────────────────────────────────────────────────────────────────
//
// `GET /children/:id/avatar/image` endi auth'siz ochiq emas (App Store
// audit F17). Brauzer `<img>` (admin panel) Authorization header yubora
// olmaydi — shuning uchun server o'zi `?exp=&sig=` bilan imzolangan havola
// beradi. Imzo kaliti JWT_ACCESS_SECRET'dan HMAC orqali ajratiladi (yangi
// env shart emas); token o'zi tarqatilmaydi.

const SIGNATURE_LABEL = 'child-avatar-image:v1';

function signingKey(secret: string): Buffer {
  return createHmac('sha256', secret).update(SIGNATURE_LABEL).digest();
}

export function signChildAvatar(
  childId: string,
  expiresAtSec: number,
  secret: string,
): string {
  return createHmac('sha256', signingKey(secret))
    .update(`${childId}.${expiresAtSec}`)
    .digest('base64url');
}

/** Imzo to'g'ri va muddati o'tmagan bo'lsa `true`. */
export function verifyChildAvatarSignature(
  childId: string,
  exp: string | undefined,
  sig: string | undefined,
  secret: string,
  nowSec: number = Math.floor(Date.now() / 1000),
): boolean {
  if (!exp || !sig || !/^\d{1,12}$/.test(exp)) return false;
  const expiresAtSec = Number(exp);
  if (expiresAtSec < nowSec) return false;
  const expected = Buffer.from(signChildAvatar(childId, expiresAtSec, secret));
  const given = Buffer.from(sig);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

/**
 * Muddat soat boshiga yaxlitlanadi — bir soat ichida havola o'zgarmaydi,
 * brauzer keshi ishlaydi (har ro'yxat yuklanishida rasm qayta olinmaydi).
 */
const EXPIRY_BUCKET_SEC = 3600;

/** `<base>/api/children/:id/avatar/image?exp=..&sig=..` havolasi. */
export function buildSignedChildAvatarUrl(
  baseUrl: string,
  childId: string,
  secret: string,
  ttlSec: number,
  nowSec: number = Math.floor(Date.now() / 1000),
): string {
  const exp =
    Math.ceil((nowSec + ttlSec) / EXPIRY_BUCKET_SEC) * EXPIRY_BUCKET_SEC;
  const sig = signChildAvatar(childId, exp, secret);
  return `${baseUrl}/api/children/${childId}/avatar/image?exp=${exp}&sig=${sig}`;
}

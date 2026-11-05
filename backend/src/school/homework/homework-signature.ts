import { createHmac, timingSafeEqual } from 'crypto';

// ─────────────────────────────────────────────────────────────────────
// Yozma vazifa rasmlari proksisi uchun qisqa muddatli IMZOLANGAN havola
// ─────────────────────────────────────────────────────────────────────
//
// MinIO presigned URL prod'da buzuq (nginx `/storage` yo'li imzoni buzadi), shuning uchun rasm
// backend proksi orqali beriladi: `GET /api/school/homework/photos/:photoId?exp=&sig=`.
// Ham xodim paneli (`<img>` Authorization yubora olmaydi), ham bola ilovasi shu havoladan
// foydalanadi. Imzo kaliti JWT_ACCESS_SECRET'dan HMAC bilan ALOHIDA maqsad belgisi bilan
// ajratiladi (bola rasmi / boshqa imzolar bilan almashtirib bo'lmaydi); yangi env shart emas.

const SIGNATURE_LABEL = 'school-homework-photo:v1';

/** Muddat soat boshiga yaxlitlanadi: bir soat ichida havola o'zgarmaydi (brauzer keshi ishlaydi). */
const EXPIRY_BUCKET_SEC = 3600;
export const HOMEWORK_URL_TTL_SEC = 3600;

function signingKey(secret: string): Buffer {
  return createHmac('sha256', secret).update(SIGNATURE_LABEL).digest();
}

export function signHomeworkPhoto(photoId: string, expiresAtSec: number, secret: string): string {
  return createHmac('sha256', signingKey(secret)).update(`${photoId}.${expiresAtSec}`).digest('base64url');
}

/** Imzo to'g'ri va muddati o'tmagan bo'lsa `true`. */
export function verifyHomeworkPhotoSignature(
  photoId: string,
  exp: string | undefined,
  sig: string | undefined,
  secret: string,
  nowSec: number = Math.floor(Date.now() / 1000),
): boolean {
  if (!exp || !sig || !/^\d{1,12}$/.test(exp)) return false;
  const expiresAtSec = Number(exp);
  if (expiresAtSec < nowSec) return false;
  const expected = Buffer.from(signHomeworkPhoto(photoId, expiresAtSec, secret));
  const given = Buffer.from(sig);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

/** `<base>/api/school/homework/photos/:photoId?exp=..&sig=..` */
export function buildSignedHomeworkPhotoUrl(
  baseUrl: string,
  photoId: string,
  secret: string,
  nowSec: number = Math.floor(Date.now() / 1000),
  ttlSec: number = HOMEWORK_URL_TTL_SEC,
): string {
  const exp = Math.ceil((nowSec + ttlSec) / EXPIRY_BUCKET_SEC) * EXPIRY_BUCKET_SEC;
  const sig = signHomeworkPhoto(photoId, exp, secret);
  return `${baseUrl.replace(/\/+$/, '')}/api/school/homework/photos/${photoId}?exp=${exp}&sig=${sig}`;
}

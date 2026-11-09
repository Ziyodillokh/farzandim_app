// To'lov chekining rasmi ("To'laganman" so'rovidagi o'tkazma skrinshoti).
// Saqlash — yozma vazifa rasmlari bilan bir MinIO bucket'ida (`receipts/` prefiksi).
// Ko'rsatish — backend proksi orqali imzolangan havola (MinIO presigned prod'da buzuq):
// `GET /api/school/verifications/receipts/:verificationId?exp=&sig=`. Imzo kaliti
// JWT_ACCESS_SECRET'dan ALOHIDA maqsad belgisi bilan (vazifa rasmi imzosi bilan almashtirib bo'lmaydi).

import { createHmac, timingSafeEqual } from 'crypto';

const SIGNATURE_LABEL = 'school-payment-receipt:v1';

/** Muddat soat boshiga yaxlitlanadi: bir soat ichida havola o'zgarmaydi (brauzer keshi). */
const EXPIRY_BUCKET_SEC = 3600;
export const RECEIPT_URL_TTL_SEC = 3600;

/** Bitta so'rovga bitta rasm. */
export const MAX_RECEIPT_PHOTOS = 1;

/** `receipts/<maktab>/<so'rov>.<ext>` */
export const receiptKey = (p: { schoolId: string; verificationId: string; ext: string }) =>
  `receipts/${p.schoolId}/${p.verificationId}.${p.ext}`;

function signingKey(secret: string): Buffer {
  return createHmac('sha256', secret).update(SIGNATURE_LABEL).digest();
}

export function signReceipt(verificationId: string, expiresAtSec: number, secret: string): string {
  return createHmac('sha256', signingKey(secret)).update(`${verificationId}.${expiresAtSec}`).digest('base64url');
}

export function verifyReceiptSignature(
  verificationId: string,
  exp: string | undefined,
  sig: string | undefined,
  secret: string,
  nowSec: number = Math.floor(Date.now() / 1000),
): boolean {
  if (!exp || !sig || !/^\d{1,12}$/.test(exp)) return false;
  const expiresAtSec = Number(exp);
  if (expiresAtSec < nowSec) return false;
  const expected = Buffer.from(signReceipt(verificationId, expiresAtSec, secret));
  const given = Buffer.from(sig);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

export function buildReceiptUrl(
  baseUrl: string,
  verificationId: string,
  secret: string,
  nowSec: number = Math.floor(Date.now() / 1000),
  ttlSec: number = RECEIPT_URL_TTL_SEC,
): string {
  const exp = Math.ceil((nowSec + ttlSec) / EXPIRY_BUCKET_SEC) * EXPIRY_BUCKET_SEC;
  const sig = signReceipt(verificationId, exp, secret);
  return `${baseUrl.replace(/\/+$/, '')}/api/school/verifications/receipts/${verificationId}?exp=${exp}&sig=${sig}`;
}

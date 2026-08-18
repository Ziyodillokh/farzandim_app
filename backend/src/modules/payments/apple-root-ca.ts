/**
 * Apple Root CA - G3 — App Store imzolagan JWS (StoreKit 2) ni tekshirish
 * uchun ISHONCH LANGARI.
 *
 * NEGA fayl emas, kod ichida base64: sertifikat `.cer` fayl sifatida
 * qo'yilsa, uni NestJS build'i `dist/` ga ko'chirishi uchun `nest-cli.json`
 * assets sozlamasi kerak bo'ladi va deploy'da bitta qadam unutilsa
 * ishlab turgan to'lov tekshiruvi "fayl topilmadi" bilan yiqiladi.
 * Kodga kiritilgan qiymat esa kompilyatsiyadan doim o'tadi.
 *
 * Manba: https://www.apple.com/certificateauthority/AppleRootCA-G3.cer
 * Subject: CN=Apple Root CA - G3, O=Apple Inc., C=US
 * SHA-256: 63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179
 *
 * Bu OMMAVIY sertifikat — maxfiy kalit emas, commit qilish xavfsiz.
 */
const APPLE_ROOT_CA_G3_BASE64 =
  'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUg' +
  'Um9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTET' +
  'MBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkw' +
  'NDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFw' +
  'cGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYD' +
  'VQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHc' +
  'FBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dv' +
  'MVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr' +
  'MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD' +
  '6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK' +
  '1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==';

/** Kutilgan SHA-256 barmoq izi (yuqoridagi izohdagi qiymat). */
const EXPECTED_SHA256 =
  '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179';

import { createHash } from 'node:crypto';

/**
 * Ildiz sertifikatni Buffer sifatida qaytaradi va barmoq izini TEKSHIRADI.
 *
 * Tekshiruv ataylab: agar kimdir yuqoridagi base64 ni tasodifan yoki
 * qasddan almashtirsa, bu funksiya darhol yiqiladi — soxta ildiz bilan
 * soxta "xarid" qabul qilinishidan ko'ra, xizmat ishlamagani yaxshiroq.
 */
export function appleRootCaG3(): Buffer {
  const der = Buffer.from(APPLE_ROOT_CA_G3_BASE64, 'base64');
  const fp = createHash('sha256').update(der).digest('hex');
  if (fp !== EXPECTED_SHA256) {
    throw new Error(
      `Apple Root CA G3 barmoq izi mos kelmadi (kutilgan ${EXPECTED_SHA256}, olindi ${fp})`,
    );
  }
  return der;
}

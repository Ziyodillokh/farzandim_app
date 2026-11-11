// Xodim uchun vaqtinchalik parol (operator / admin beradi, birinchi kirishda
// almashtiriladi). Qo'lda teriladi — o'xshash belgilar (0/O, 1/l/I) yo'q.

import { randomInt } from 'node:crypto';

const ALPHABET = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
/** 12 belgi × log2(56) ≈ 70 bit; panel parol talabi (≥ 10) bajariladi. */
export const TEMP_PASSWORD_LENGTH = 12;

export function generateTempPassword(length = TEMP_PASSWORD_LENGTH): string {
  return Array.from({ length }, () => ALPHABET[randomInt(ALPHABET.length)]).join('');
}

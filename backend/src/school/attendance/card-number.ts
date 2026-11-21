// Karta raqami (kartaga bosiladi): 10 xona — 9 tasodifiy raqam + Verhoeff tekshiruv raqami.
// Birinchi raqam 1–9 (Excel/jadvalda boshidagi nol yo'qolmasin). Raqamda shaxsiy ma'lumot
// (maktab, viloyat, sana) yo'q — karta bola bilan boshqa maktabga ham o'tishi mumkin.
// Bank kartalariga (16 xona, 8600/9860, Luhn) o'xshamaydi. Panel nusxasi: `school-panel/src/lib/card-number.ts`.

import { randomInt } from 'node:crypto';

export const CARD_NUMBER_LENGTH = 10;

const D = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
  [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
  [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
  [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
  [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
  [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
  [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
  [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
  [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
] as const;
const P = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
  [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
  [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
  [9, 4, 5, 3, 1, 2, 7, 6, 8, 0],
  [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
  [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
  [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
] as const;
const INV = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9] as const;

const reversedDigits = (digits: string) => [...digits].reverse().map(Number);

/** Verhoeff tekshiruv raqami (bitta xato raqam va qo'shni raqamlar almashishini ushlaydi). */
export function verhoeffDigit(digits: string): number {
  const c = reversedDigits(digits).reduce<number>((acc, digit, i) => D[acc][P[(i + 1) % 8][digit]], 0);
  return INV[c];
}

/** Raqam to'g'rimi: 10 xona, boshida nol yo'q, oxirgi raqam to'g'ri. */
export function isValidCardNumber(value: string): boolean {
  if (!/^[1-9]\d{9}$/.test(value)) return false;
  return reversedDigits(value).reduce<number>((acc, digit, i) => D[acc][P[i % 8][digit]], 0) === 0;
}

/** Yangi tasodifiy raqam (`rand(min, max)` — max kirmaydi; testda almashtiriladi). */
export function randomCardNumber(rand: (min: number, max: number) => number = randomInt): string {
  const body = `${rand(1, 10)}${String(rand(0, 100_000_000)).padStart(8, '0')}`;
  return `${body}${verhoeffDigit(body)}`;
}

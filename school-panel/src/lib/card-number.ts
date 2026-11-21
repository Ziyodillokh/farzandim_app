/**
 * Karta raqami (kartaga bosiladi): 10 xona — 9 tasodifiy raqam + Verhoeff tekshiruv raqami,
 * boshida nol yo'q. Raqamni har doim tizim beradi. Backend nusxasi:
 * `backend/src/school/attendance/card-number.ts`.
 */

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

/** Verhoeff tekshiruv raqami. */
export function verhoeffDigit(digits: string): number {
  return INV[reversedDigits(digits).reduce<number>((acc, digit, i) => D[acc][P[(i + 1) % 8][digit]], 0)];
}

/** 10 xona, boshida nol yo'q, oxirgi raqam to'g'ri. */
export function isValidCardNumber(value: string): boolean {
  if (!/^[1-9]\d{9}$/.test(value)) return false;
  return reversedDigits(value).reduce<number>((acc, digit, i) => D[acc][P[i % 8][digit]], 0) === 0;
}

/** 9 xonali asos (100000000–999999999) → to'liq 10 xonali raqam. */
export function cardNumberFrom(body: number): string {
  const text = String(body);
  return `${text}${verhoeffDigit(text)}`;
}

/** Tasodifiy raqam (`random` — [0, 1) oralig'ida; demo uchun). */
export function randomCardNumber(random: () => number = Math.random): string {
  return cardNumberFrom(100_000_000 + Math.floor(random() * 900_000_000));
}

/** Ko'rsatish uchun: "4821093753" → "48210 93753"; eski ko'rinishdagi raqamlar o'zgarmaydi. */
export function formatCardNumber(value: string): string {
  return /^\d{10}$/.test(value) ? `${value.slice(0, 5)} ${value.slice(5)}` : value;
}

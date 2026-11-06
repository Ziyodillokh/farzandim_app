// O'quvchi kodi (K2): 6 raqam (bosh nollar mumkin), 24 soat. Kriptografik tasodif; 10^6 maydon kichik, shuning
// uchun bola kodi o'z-o'zidan ishonch bermaydi (UNDER_REVIEW) va xato urinishlar qattiq cheklanadi. Faol kodlar
// orasida yagonalik bazadagi qisman unique indeks bilan.

import { randomInt } from 'node:crypto';

export const STUDENT_CODE_LENGTH = 6;
export const STUDENT_CODE_TTL_MS = 24 * 3_600_000;
const CODE_SPACE = 10 ** STUDENT_CODE_LENGTH;

const STUDENT_CODE_PATTERN = /^\d{6}$/;

export const isStudentCode = (value: string): boolean => STUDENT_CODE_PATTERN.test(value);

/** Bo'shliq va chiziqchalar olib tashlanadi ("048 213", "048-213" ham qabul qilinadi). */
export const stripCodeSeparators = (raw: string): string => raw.replace(/[\s-]/g, '');

/** Tasodifiy 6 raqam (bosh nollar saqlanadi: `"004821"`). */
export function randomStudentCode(): string {
  return String(randomInt(CODE_SPACE)).padStart(STUDENT_CODE_LENGTH, '0');
}

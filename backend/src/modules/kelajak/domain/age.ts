// Bola yoshi va Kelajak yosh guruhi (docs/KELAJAK-REJA.md §3). `?? 8` kabi
// fallback YO'Q: yosh noma'lum bo'lsa — `AGE_REQUIRED`, boshqa guruhning
// savoli hech qachon berilmaydi.

import { DayKey, tashkentDay } from '../../../common/time/tashkent';

export const KELAJAK_AGE_GROUPS = ['7-9', '10-12', '13-15', '16-18'] as const;
export type KelajakAgeGroup = (typeof KELAJAK_AGE_GROUPS)[number];

export type KelajakAgeStatus = 'OK' | 'AGE_REQUIRED' | 'AGE_OUT_OF_RANGE';

export interface KelajakAge {
  status: KelajakAgeStatus;
  age: number | null;
  ageGroup: KelajakAgeGroup | null;
}

/** `children.age` ustuni uchun ruxsat etilgan oraliq (DTO'dagi @Min(1) @Max(25)). */
export const STORED_AGE_MIN = 1;
export const STORED_AGE_MAX = 25;

const GROUP_BOUNDS: ReadonlyArray<{ group: KelajakAgeGroup; min: number; max: number }> = [
  { group: '7-9', min: 7, max: 9 },
  { group: '10-12', min: 10, max: 12 },
  { group: '13-15', min: 13, max: 15 },
  { group: '16-18', min: 16, max: 18 },
];

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

export function isKelajakAgeGroup(value: unknown): value is KelajakAgeGroup {
  return typeof value === 'string' && (KELAJAK_AGE_GROUPS as readonly string[]).includes(value);
}

/** Tug'ilgan sana (`YYYY-MM-DD`) bo'yicha `today` kunidagi to'liq yosh. */
export function fullYears(birthDate: string, today: DayKey): number | null {
  const b = ISO_DATE.exec(birthDate);
  const t = ISO_DATE.exec(today);
  if (!b || !t) return null;
  const [by, bm, bd] = b.slice(1).map(Number);
  const [ty, tm, td] = t.slice(1).map(Number);
  // Tug'ilgan kun shu yil hali kelmagan bo'lsa — bir kam.
  return ty - by - (tm < bm || (tm === bm && td < bd) ? 1 : 0);
}

/** `@db.Date` (UTC yarim tuni) yoki `YYYY-MM-DD` → kalendar sana. */
function birthDay(value: Date | string | null): string | null {
  if (value === null) return null;
  if (typeof value === 'string') return ISO_DATE.test(value) ? value : null;
  return Number.isNaN(value.getTime()) ? null : value.toISOString().slice(0, 10);
}

/**
 * Bola yoshi: `birthDate` bo'lsa Toshkent bugungi kuni bo'yicha hisoblanadi,
 * aks holda `age` ustuni (1..25). Ikkalasi ham yaroqsiz — `null`.
 */
export function childAge(
  child: { birthDate: Date | string | null; age: number | null },
  today: DayKey = tashkentDay(),
): number | null {
  const day = birthDay(child.birthDate);
  const fromBirth = day ? fullYears(day, today) : null;
  // Kelajakdagi sana (manfiy yosh) — yaroqsiz, `age` ustuniga tushamiz.
  if (fromBirth !== null && fromBirth >= 0) return fromBirth;
  const { age } = child;
  if (age !== null && Number.isInteger(age) && age >= STORED_AGE_MIN && age <= STORED_AGE_MAX) {
    return age;
  }
  return null;
}

export function ageGroupOf(age: number | null): KelajakAgeGroup | null {
  if (age === null) return null;
  return GROUP_BOUNDS.find((g) => age >= g.min && age <= g.max)?.group ?? null;
}

export function resolveKelajakAge(
  child: { birthDate: Date | string | null; age: number | null },
  today: DayKey = tashkentDay(),
): KelajakAge {
  const age = childAge(child, today);
  if (age === null) return { status: 'AGE_REQUIRED', age: null, ageGroup: null };
  const ageGroup = ageGroupOf(age);
  return { status: ageGroup ? 'OK' : 'AGE_OUT_OF_RANGE', age, ageGroup };
}

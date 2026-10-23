// IQ test darajalari, norma guruhlari va qayta topshirish (docs/IQ-REJA.md §1).
// Yosh — Kelajak'dagi `childAge` (birthDate → Toshkent kuni, aks holda `age`);
// fallback YO'Q.

import { DayKey, tashkentDay } from '../../../common/time/tashkent';
import { childAge } from '../../kelajak/domain/age';

export const IQ_LEVELS = [1, 2, 3, 4, 5] as const;
export type IqLevel = (typeof IQ_LEVELS)[number];
export const OPTION_KEYS: readonly string[] = ['A', 'B', 'C', 'D', 'E', 'F'];

export const IQ_MIN_AGE = 9;
export const IQ_MAX_AGE = 20;
export const FORM_SIZE = 20;
export const RETAKE_DAYS = 180;
export const SESSION_TTL_HOURS = 24;
const DAY_MS = 24 * 60 * 60 * 1000;

const LEVEL_MAX_AGE: ReadonlyArray<[IqLevel, number]> = [
  [1, 10],
  [2, 12],
  [3, 14],
  [4, 16],
  [5, IQ_MAX_AGE],
];

export type IqAgeStatus = 'OK' | 'AGE_REQUIRED' | 'AGE_OUT_OF_RANGE';
export interface IqAge {
  status: IqAgeStatus;
  age: number | null;
  level: IqLevel | null;
}

export function levelForAge(age: number): IqLevel | null {
  if (age < IQ_MIN_AGE || age > IQ_MAX_AGE) return null;
  return LEVEL_MAX_AGE.find(([, max]) => age <= max)?.[0] ?? null;
}

/** Norma guruhi: to'liq yosh "9".."16", 17–20 bitta guruh. */
export function normGroupForAge(age: number): string | null {
  if (age < IQ_MIN_AGE || age > IQ_MAX_AGE) return null;
  return age >= 17 ? '17-20' : String(age);
}

/**
 * Dastlabki ma'lumotnoma (n < 30): darajaning kichik yoshi −0.25, katta yoshi
 * +0.25 logit (17-20 → 0) — darajaning dizayn markaziga nisbatan.
 */
export function groupOffset(group: string): number {
  if (group === '17-20') return 0;
  const age = Number(group);
  return levelForAge(age) === levelForAge(age - 1) ? 0.25 : -0.25;
}

export function resolveIqAge(
  child: { birthDate: Date | string | null; age: number | null },
  today: DayKey = tashkentDay(),
): IqAge {
  const age = childAge(child, today);
  if (age === null) return { status: 'AGE_REQUIRED', age: null, level: null };
  const level = levelForAge(age);
  return { status: level ? 'OK' : 'AGE_OUT_OF_RANGE', age, level };
}

/** Rasmli formalar (A/B, 2026-10-21) — eski sessiyalar uchun saqlanadi. */
export const CLASSIC_FORMS = ['A', 'B'] as const;
/** Aralash formalar (C/D): 10 rasmli + 4 sonli + 3 so'z + 3 mantiq. */
export const MIXED_FORMS = ['C', 'D'] as const;
export const IQ_FORMS = [...CLASSIC_FORMS, ...MIXED_FORMS] as const;

/** Yangi sessiya formasi: yakunlangan sessiyalar soni juft — C, toq — D. */
export function formFor(level: IqLevel, completedCount: number): string {
  return `L${level}${MIXED_FORMS[completedCount % 2]}`;
}

export const isMixedForm = (form: string): boolean => MIXED_FORMS.some((f) => form.endsWith(f));

/**
 * Normalar jadvali kaliti: aralash formalar normasi alohida yig'iladi (savollar
 * boshqa, dizayn qiyinligi kalibrovkagacha taxminiy) — "mix:12"; rasmli — "12".
 */
export const normKey = (form: string, group: string): string => (isMixedForm(form) ? `mix:${group}` : group);

export function nextAvailableAt(lastCompletedAt: Date | null): Date | null {
  return lastCompletedAt ? new Date(lastCompletedAt.getTime() + RETAKE_DAYS * DAY_MS) : null;
}

/** Ochiq sessiya `SESSION_TTL_HOURS` dan eski — yopiladi. */
export function isExpired(startedAt: Date, now: Date): boolean {
  return now.getTime() - startedAt.getTime() > SESSION_TTL_HOURS * 60 * 60 * 1000;
}

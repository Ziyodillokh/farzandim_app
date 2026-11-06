// Bola bildirishnoma sozlamalari — sof (DB'siz) qismi: standart qiymatlar, kunlik eslatma
// vaqtini tekshirish, tinch soatlar va Toshkent daqiqasi. Servislar shu yerdan foydalanadi.

import { TASHKENT_OFFSET_MS } from '../time/tashkent';

/** Kunlik eslatma vaqti chegaralari (Toshkent, kiritilgan qiymat ham shu chegarada). */
export const REMINDER_TIME_MIN = '06:00';
export const REMINDER_TIME_MAX = '21:00';
export const DEFAULT_REMINDER_TIME = '18:00';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;
const MINUTES_PER_HOUR = 60;

/** Sozlamalar yozuvi bo'lmagan bola uchun standart: hammasi yoqilgan, matn yashirilmagan (`hideText = false`). */
export interface ResolvedPrefs {
  studyNudge: boolean;
  healthNudge: boolean;
  contentReminder: boolean;
  quietFrom: string | null;
  quietTo: string | null;
  homeworkReminder: boolean;
  schoolAnnouncements: boolean;
  familyMessages: boolean;
  dailyReminder: boolean;
  dailyReminderTime: string;
  hideText: boolean;
}

export const DEFAULT_PREFS: Readonly<ResolvedPrefs> = Object.freeze({
  studyNudge: true,
  healthNudge: true,
  contentReminder: true,
  quietFrom: null,
  quietTo: null,
  homeworkReminder: true,
  schoolAnnouncements: true,
  familyMessages: true,
  dailyReminder: true,
  dailyReminderTime: DEFAULT_REMINDER_TIME,
  hideText: false,
});

/** Bazadagi (qisman) yozuv → to'liq sozlamalar; yozuv yo'q bo'lsa — standart. Yangi obyekt qaytaradi. */
export function resolvePrefs(row: Partial<ResolvedPrefs> | null | undefined): ResolvedPrefs {
  const d = DEFAULT_PREFS;
  return {
    studyNudge: row?.studyNudge ?? d.studyNudge,
    healthNudge: row?.healthNudge ?? d.healthNudge,
    contentReminder: row?.contentReminder ?? d.contentReminder,
    quietFrom: row?.quietFrom ?? d.quietFrom,
    quietTo: row?.quietTo ?? d.quietTo,
    homeworkReminder: row?.homeworkReminder ?? d.homeworkReminder,
    schoolAnnouncements: row?.schoolAnnouncements ?? d.schoolAnnouncements,
    familyMessages: row?.familyMessages ?? d.familyMessages,
    dailyReminder: row?.dailyReminder ?? d.dailyReminder,
    dailyReminderTime: row?.dailyReminderTime ?? d.dailyReminderTime,
    hideText: row?.hideText ?? d.hideText,
  };
}

/** "HH:MM" -> daqiqa (0..1439); noto'g'ri qiymat -> null. Bir xonali soatni ham qabul qiladi (eski tinch soatlar). */
export function parseHhMm(value: string | null | undefined): number | null {
  if (!value) return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(value);
  if (!m) return null;
  const hour = Number(m[1]);
  const minute = Number(m[2]);
  if (hour > 23 || minute > 59) return null;
  return hour * MINUTES_PER_HOUR + minute;
}

/** Kunlik eslatma vaqti: aynan "HH:MM" (nol bilan to'ldirilgan) va 06:00..21:00 oralig'ida. */
export function isValidReminderTime(value: unknown): value is string {
  if (typeof value !== 'string' || !HHMM.test(value)) return false;
  const minutes = parseHhMm(value);
  return minutes !== null && minutes >= parseHhMm(REMINDER_TIME_MIN)! && minutes <= parseHhMm(REMINDER_TIME_MAX)!;
}

/** Berilgan lahzaning Toshkent bo'yicha kun ichidagi daqiqasi (0..1439). */
export function tashkentMinutesOfDay(at: Date): number {
  const local = new Date(at.getTime() + TASHKENT_OFFSET_MS);
  return local.getUTCHours() * MINUTES_PER_HOUR + local.getUTCMinutes();
}

/** "HH:MM" ko'rinishida daqiqa (0..1439). */
export function formatHhMm(minutes: number): string {
  const hour = Math.floor(minutes / MINUTES_PER_HOUR);
  const minute = minutes % MINUTES_PER_HOUR;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

/**
 * Tinch soat oynasi ichidami (tun bo'ylab o'tuvchi oyna ham: 22:00–08:00). Chegaralardan biri yo'q /
 * noto'g'ri yoki ikkalasi teng bo'lsa — hech qachon tinch emas.
 */
export function isQuietAt(quietFrom: string | null | undefined, quietTo: string | null | undefined, minutes: number): boolean {
  const from = parseHhMm(quietFrom);
  const to = parseHhMm(quietTo);
  if (from === null || to === null || from === to) return false;
  return from < to ? minutes >= from && minutes < to : minutes >= from || minutes < to;
}

/**
 * Kunlik eslatma "hozir" yuboriladimi: eslatma vaqti oxirgi `catchUpMinutes` daqiqa ichida (shu jumladan hozir).
 * Server qisqa vaqt to'xtab qolsa, o'tkazib yuborilgan eslatma kechikib bo'lsa ham chiqadi.
 */
export function reminderDueNow(reminderTime: string, nowMinutes: number, catchUpMinutes: number): boolean {
  const at = parseHhMm(reminderTime);
  if (at === null) return false;
  const late = nowMinutes - at;
  return late >= 0 && late < catchUpMinutes;
}

/** `[now - catchUp + 1 .. now]` oralig'idagi "HH:MM" qiymatlari (bazadan `in` bilan tanlash uchun). Yarim tunda o'ramaydi. */
export function dueReminderTimes(nowMinutes: number, catchUpMinutes: number): string[] {
  const first = Math.max(0, nowMinutes - catchUpMinutes + 1);
  return Array.from({ length: nowMinutes - first + 1 }, (_, i) => formatHhMm(first + i));
}

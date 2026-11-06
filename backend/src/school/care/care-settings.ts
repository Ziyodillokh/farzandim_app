// Bola ovozi sozlamalari: ma'lumot shakli, standart qiymatlar va bola ilovasi
// uchun "murojaat" kartochkasi (kim javob beradi, hozir ish vaqtimi) — sof funksiyalar.

import { SchoolCareSettings } from '@prisma/client';
import { HolidaySet, isWorkingAt, nextWorkingStart, WorkingHours } from './care-working-time';

export interface CareSettingsData {
  psychologistStaffId: string | null;
  psychologistDisplayName: string | null;
  deputyStaffId: string | null;
  deputyDisplayName: string | null;
  workDays: number[];
  workStart: string;
  workEnd: string;
  urgentSlaMinutes: number;
  normalSlaHours: number;
}

export const DEFAULT_CARE_SETTINGS: Readonly<CareSettingsData> = {
  psychologistStaffId: null,
  psychologistDisplayName: null,
  deputyStaffId: null,
  deputyDisplayName: null,
  workDays: [1, 2, 3, 4, 5],
  workStart: '09:00',
  workEnd: '17:00',
  urgentSlaMinutes: 60,
  normalSlaHours: 24,
};

/** Bazadagi qator (yoki `null` — sozlanmagan) → standart qiymatlar bilan to'ldirilgan ma'lumot. */
export function toSettingsData(row: SchoolCareSettings | null): CareSettingsData {
  if (!row) return { ...DEFAULT_CARE_SETTINGS, workDays: [...DEFAULT_CARE_SETTINGS.workDays] };
  return {
    psychologistStaffId: row.psychologistStaffId,
    psychologistDisplayName: row.psychologistDisplayName,
    deputyStaffId: row.deputyStaffId,
    deputyDisplayName: row.deputyDisplayName,
    workDays: [...row.workDays].sort((a, b) => a - b),
    workStart: row.workStart,
    workEnd: row.workEnd,
    urgentSlaMinutes: row.urgentSlaMinutes,
    normalSlaHours: row.normalSlaHours,
  };
}

export const hoursOf = (s: Pick<CareSettingsData, 'workDays' | 'workStart' | 'workEnd'>): WorkingHours => ({
  days: s.workDays,
  start: s.workStart,
  end: s.workEnd,
});

/** Murojaat javob muddati (ish daqiqalarida): shoshilinch — daqiqa, oddiy — soat. */
export const slaMinutes = (s: Pick<CareSettingsData, 'urgentSlaMinutes' | 'normalSlaHours'>, urgency: string): number =>
  urgency === 'URGENT' ? s.urgentSlaMinutes : s.normalSlaHours * 60;

export interface CarePerson {
  name: string;
}

/**
 * `GET /child/school/care/contact`. Sozlama qatori yo'q — `hours: null`, `openNow: false`,
 * `nextOpenAt: null`. Hozir ochiq bo'lsa `nextOpenAt` ham `null` (kutish kerak emas).
 */
export function buildContact(input: {
  configured: boolean;
  settings: CareSettingsData;
  psychologist: CarePerson | null;
  deputy: CarePerson | null;
  holidays: HolidaySet;
  now: Date;
}) {
  const { configured, settings, psychologist, deputy, holidays, now } = input;
  const base = { psychologist, deputy };
  if (!configured) return { ...base, hours: null, openNow: false, nextOpenAt: null };
  const hours = hoursOf(settings);
  const openNow = isWorkingAt(now, hours, holidays);
  return {
    ...base,
    hours: { days: [...settings.workDays], start: settings.workStart, end: settings.workEnd },
    openNow,
    nextOpenAt: openNow ? null : (nextWorkingStart(now, hours, holidays)?.toISOString() ?? null),
  };
}

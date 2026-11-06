import type { CareSettings, CareSettingsView, CareStaffOption } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import type { CareSettingsInput } from '@/data/schemas/care';

/**
 * Bola ovozi: backend (kontrakt) javoblarini panel turlariga keltiruvchi ADAPTERLAR.
 * Har biri aniq funksiya va unit-test bilan qoplangan (`__tests__/care.test.ts`): http qatlami
 * "taxminiy" shaklga tayanmasin. Majburiy maydon yo'q yoki turi noto'g'ri bo'lsa — jim standart qiymat
 * EMAS, aniq xato (aks holda forma standart qiymatni backend ustiga yozib yuborishi mumkin).
 */

export type Wire = Record<string, unknown>;

export function isRecord(value: unknown): value is Wire {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function malformed(what: string): ServiceError {
  return new ServiceError('UNKNOWN', `${what}: kutilmagan javob shakli`);
}

/** Bo'sh bo'lmagan satr yoki null (aks holda — shakl xatosi). */
export function nullableString(value: unknown, what: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value === 'string') return value === '' ? null : value;
  throw malformed(what);
}

export function requiredString(value: unknown, what: string): string {
  if (typeof value === 'string' && value !== '') return value;
  throw malformed(what);
}

export function requiredInt(value: unknown, what: string): number {
  if (typeof value === 'number' && Number.isInteger(value)) return value;
  throw malformed(what);
}

export function nullableDateTime(value: unknown, what: string): string | null {
  return nullableString(value, what);
}

const HH_MM = /^(\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?$/;

/** "09:00" yoki "09:00:00" → "09:00". */
function clockTime(value: unknown, what: string): string {
  const match = typeof value === 'string' ? HH_MM.exec(value) : null;
  if (!match?.[1]) throw malformed(what);
  return match[1];
}

function workDays(value: unknown): number[] {
  if (!Array.isArray(value)) throw malformed('workDays');
  const days = value.map((d) => (typeof d === 'number' && Number.isInteger(d) && d >= 1 && d <= 7 ? d : null));
  if (days.includes(null)) throw malformed('workDays');
  return [...new Set(days as number[])].sort((a, b) => a - b);
}

function staffOptions(value: unknown): CareStaffOption[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw malformed('staffOptions');
  return value.map((item) => {
    if (!isRecord(item)) throw malformed('staffOptions');
    return { id: requiredString(item.id, 'staffOptions.id'), fullName: requiredString(item.fullName, 'staffOptions.fullName') };
  });
}

/**
 * `GET /school/care/settings` (kontrakt C): tekis obyekt — sozlama maydonlari + `staffOptions`.
 * Sozlamalar `settings` ichida joylashgan shakl ham qabul qilinadi (`{ settings, staffOptions }`).
 */
export function toCareSettingsView(raw: unknown): CareSettingsView {
  if (!isRecord(raw)) throw malformed('settings');
  const source = isRecord(raw.settings) ? raw.settings : raw;
  const settings: CareSettings = {
    psychologistStaffId: nullableString(source.psychologistStaffId, 'psychologistStaffId'),
    psychologistDisplayName: nullableString(source.psychologistDisplayName, 'psychologistDisplayName'),
    deputyStaffId: nullableString(source.deputyStaffId, 'deputyStaffId'),
    deputyDisplayName: nullableString(source.deputyDisplayName, 'deputyDisplayName'),
    workDays: workDays(source.workDays),
    workStart: clockTime(source.workStart, 'workStart'),
    workEnd: clockTime(source.workEnd, 'workEnd'),
    urgentSlaMinutes: requiredInt(source.urgentSlaMinutes, 'urgentSlaMinutes'),
    normalSlaHours: requiredInt(source.normalSlaHours, 'normalSlaHours'),
    updatedAt: nullableDateTime(source.updatedAt, 'updatedAt'),
  };
  return { ...settings, staffOptions: staffOptions(raw.staffOptions ?? source.staffOptions) };
}

const cleanName = (value: string | null): string | null => value?.trim() || null;

/** `PUT /school/care/settings` tanasi: to'liq almashtirish, tozalangan maydonlar `null`. */
export function toCareSettingsBody(input: CareSettingsInput): Record<string, unknown> {
  return {
    psychologistStaffId: input.psychologistStaffId,
    psychologistDisplayName: cleanName(input.psychologistDisplayName),
    deputyStaffId: input.deputyStaffId,
    deputyDisplayName: cleanName(input.deputyDisplayName),
    workDays: [...input.workDays].sort((a, b) => a - b),
    workStart: input.workStart,
    workEnd: input.workEnd,
    urgentSlaMinutes: input.urgentSlaMinutes,
    normalSlaHours: input.normalSlaHours,
  };
}

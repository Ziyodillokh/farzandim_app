import type { CareSettings, CareSettingsView, CareStaffOption, IsoWeekday } from '@/data/contracts';
import { CARE_SETTINGS_LIMITS, type CareSettingsInput } from '@/data/schemas/care';
import type { useI18n } from '@/i18n';

type T = ReturnType<typeof useI18n>['t'];

export const ISO_WEEKDAYS: readonly IsoWeekday[] = [1, 2, 3, 4, 5, 6, 7];
/** Ketma-ket shuncha kun va undan ko'pi «Du–Ju» ko'rinishida yoziladi. */
const MIN_RANGE_DAYS = 3;
/** Select'da «tanlanmagan» (Radix `SelectItem` bo'sh qiymat qabul qilmaydi). */
export const NO_STAFF = '__none__';

function isIsoWeekday(day: number): day is IsoWeekday {
  return day >= 1 && day <= 7 && Number.isInteger(day);
}

/** Kunlar guruhlari: [1,2,3,4,5] → [[1..5]]; [1,3,4,5,6] → [[1],[3..6]]. */
function runs(days: readonly IsoWeekday[]): IsoWeekday[][] {
  const out: IsoWeekday[][] = [];
  for (const day of days) {
    const last = out.at(-1);
    if (last && day === (last.at(-1) ?? 0) + 1) last.push(day);
    else out.push([day]);
  }
  return out;
}

/** «Du–Ju», «Du, Ch, Ju», «Har kuni». */
export function formatWorkDays(t: T, workDays: readonly number[]): string {
  const days = [...new Set(workDays.filter(isIsoWeekday))].sort((a, b) => a - b);
  if (days.length === 0) return '—';
  if (days.length === ISO_WEEKDAYS.length) return t('care.settings.everyDay');
  const short = (d: IsoWeekday) => t(`enums.weekdayShort.${d}`);
  return runs(days)
    .map((run) => {
      const first = run[0];
      const last = run.at(-1);
      if (first === undefined || last === undefined) return '';
      return run.length >= MIN_RANGE_DAYS ? `${short(first)}–${short(last)}` : run.map(short).join(', ');
    })
    .join(', ');
}

/** «Du–Ju, 08:30–16:30». */
export function formatWorkHours(t: T, settings: Pick<CareSettings, 'workDays' | 'workStart' | 'workEnd'>): string {
  return `${formatWorkDays(t, settings.workDays)}, ${settings.workStart}–${settings.workEnd}`;
}

/** Sozlama saqlanganmi (standart qiymatlar — `updatedAt: null`). */
export function isSettingsConfigured(settings: Pick<CareSettings, 'updatedAt'> | undefined): boolean {
  return Boolean(settings?.updatedAt);
}

/** Bola ko'radigan ism: ko'rsatiladigan ism, bo'lmasa xodimning to'liq ismi, bo'lmasa null. */
export function childFacingName(displayName: string | null, staffId: string | null, options: readonly CareStaffOption[]): string | null {
  const custom = displayName?.trim();
  if (custom) return custom;
  return options.find((o) => o.id === staffId)?.fullName ?? null;
}

/** Forma holati: sonlar matn (bo'sh qoldirish mumkin), xodim tanlovi `NO_STAFF` bilan. */
export type SettingsDraft = {
  psychologistStaffId: string;
  psychologistDisplayName: string;
  deputyStaffId: string;
  deputyDisplayName: string;
  workDays: number[];
  workStart: string;
  workEnd: string;
  urgentSlaMinutes: string;
  normalSlaHours: string;
};

export function toDraft(settings: CareSettingsView): SettingsDraft {
  return {
    psychologistStaffId: settings.psychologistStaffId ?? NO_STAFF,
    psychologistDisplayName: settings.psychologistDisplayName ?? '',
    deputyStaffId: settings.deputyStaffId ?? NO_STAFF,
    deputyDisplayName: settings.deputyDisplayName ?? '',
    workDays: [...settings.workDays],
    workStart: settings.workStart,
    workEnd: settings.workEnd,
    urgentSlaMinutes: String(settings.urgentSlaMinutes),
    normalSlaHours: String(settings.normalSlaHours),
  };
}

const staffOrNull = (value: string): string | null => (value === NO_STAFF ? null : value);
/** Bo'sh/noto'g'ri son — NaN (sxema «son kerak» xatosini beradi). */
const toNumber = (value: string): number => (value.trim() === '' ? Number.NaN : Number(value));

export function toInput(draft: SettingsDraft): CareSettingsInput {
  return {
    psychologistStaffId: staffOrNull(draft.psychologistStaffId),
    psychologistDisplayName: draft.psychologistDisplayName,
    deputyStaffId: staffOrNull(draft.deputyStaffId),
    deputyDisplayName: draft.deputyDisplayName,
    workDays: [...draft.workDays].sort((a, b) => a - b),
    workStart: draft.workStart,
    workEnd: draft.workEnd,
    urgentSlaMinutes: toNumber(draft.urgentSlaMinutes),
    normalSlaHours: toNumber(draft.normalSlaHours),
  };
}

/** Forma o'zgarganmi (saqlash tugmasi va "o'zgarmagan" holat uchun). */
export function isDraftDirty(a: SettingsDraft, b: SettingsDraft): boolean {
  return JSON.stringify({ ...a, workDays: [...a.workDays].sort() }) !== JSON.stringify({ ...b, workDays: [...b.workDays].sort() });
}

export const SLA_MINUTES_RANGE = CARE_SETTINGS_LIMITS.urgentSlaMinutes;
export const SLA_HOURS_RANGE = CARE_SETTINGS_LIMITS.normalSlaHours;

/**
 * Backend umumiy kalit yuboradi (`duplicate`, `outOfRange`, `invalidStaff`) — maydonga qarab
 * aniqroq panel xabariga aylantiriladi.
 */
const FIELD_KEY_ALIASES: Record<string, string> = {
  'deputyStaffId:errors.form.duplicate': 'errors.form.deputySame',
  'workDays:errors.form.duplicate': 'errors.form.duplicateDay',
  'urgentSlaMinutes:errors.form.outOfRange': 'errors.form.slaMinutesRange',
  'normalSlaHours:errors.form.outOfRange': 'errors.form.slaHoursRange',
};

/** Backend/servis xatosi `maydon: errors.form.kalit` ko'rinishida bo'lsa — maydon va kalit. */
export function parseFieldError(message: string): { field: string; key: string } | null {
  const [rawField, key] = message.split(': ');
  if (!rawField || !key?.startsWith('errors.form.')) return null;
  // `workDays.2` → `workDays` (massiv elementi xatosi butun maydonda ko'rsatiladi).
  const field = rawField.split('.')[0];
  const alias = FIELD_KEY_ALIASES[`${field}:${key}`] ?? (key === 'errors.form.invalidStaff' ? 'errors.form.staffInvalid' : key);
  return { field, key: alias };
}

import type { IsoDate, SchoolClass } from '@/data/contracts';
import { hhmmToMinutes } from '@/lib/utils';
import { isSchoolDay } from './calendar';
import type { Tables } from './tables';

/**
 * Sinf uchun School Mode holati (hozirgi daqiqa bo'yicha).
 * Xavfsizlik qoidasi: jadval tugashi bilan cheklov avtomatik tugaydi.
 */
export type ClassModeState =
  | { kind: 'LESSON'; periodNo: number; endsAt: string; restricted: boolean }
  | { kind: 'BREAK'; periodNo: number; endsAt: string; restricted: boolean }
  | { kind: 'BEFORE'; startsAt: string; restricted: false }
  | { kind: 'AFTER'; restricted: false }
  | { kind: 'DAY_OFF'; restricted: false }
  | { kind: 'EMERGENCY_OFF'; restricted: false }
  | { kind: 'DISABLED'; restricted: false };

export function classModeState(tables: Tables, cls: SchoolClass, date: IsoDate, minute: number): ClassModeState {
  const shift = tables.shifts.find((s) => s.id === cls.shiftId);
  if (!shift || !isSchoolDay(date, shift, tables.holidays)) return { kind: 'DAY_OFF', restricted: false };
  const policy = tables.policies.find((p) => p.enabled && p.shiftIds.includes(shift.id));
  if (!policy) return { kind: 'DISABLED', restricted: false };
  const emergency = tables.emergency;
  if (emergency.active && (emergency.scope === 'SCHOOL' || emergency.classIds.includes(cls.id))) {
    return { kind: 'EMERGENCY_OFF', restricted: false };
  }
  const start = hhmmToMinutes(shift.start);
  const end = hhmmToMinutes(shift.end);
  if (minute < start) return { kind: 'BEFORE', startsAt: shift.start, restricted: false };
  if (minute >= end) return { kind: 'AFTER', restricted: false };
  for (const period of shift.periods) {
    const ps = hhmmToMinutes(period.start);
    const pe = hhmmToMinutes(period.end);
    if (minute >= ps && minute < pe) {
      const restricted = period.kind === 'LESSON' || !policy.relaxDuringBreaks;
      return { kind: period.kind, periodNo: period.no, endsAt: period.end, restricted };
    }
  }
  return { kind: 'AFTER', restricted: false };
}

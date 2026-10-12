import type {
  AttendanceRecord,
  AttendanceSource,
  AttendanceStatus,
  Holiday,
  IsoDate,
  SchoolClass,
  Shift,
  Student,
} from '@/data/contracts';
import { unitHash } from '@/lib/rng';
import { hhmmToMinutes, minutesToHhmm } from '@/lib/utils';
import { isSchoolDay, weekStart } from './calendar';

/**
 * O'quvchining kun rejasi — `hash(o'quvchi, sana)` dan barqaror. O'tgan kunlar
 * tarixi saqlanmaydi, shu funksiyadan hisoblanadi; bugungi kun esa simulyator
 * shu rejaga ko'ra jonli "o'ynaydi" (soat yetganda kirish hodisasi).
 */
export type DayPlan = {
  status: AttendanceStatus;
  inMinute: number | null;
  outMinute: number | null;
  source: AttendanceSource;
};

export function planDay(
  student: Pick<Student, 'id' | 'device'>,
  cls: Pick<SchoolClass, 'id'>,
  shift: Pick<Shift, 'start' | 'end' | 'weekdays'>,
  date: IsoDate,
  holidays: readonly Holiday[],
  lateAfterMinutes: number,
): DayPlan | null {
  if (!isSchoolDay(date, shift, holidays)) return null;
  const start = hhmmToMinutes(shift.start);
  const end = hhmmToMinutes(shift.end);
  const classFactor = unitHash(cls.id, weekStart(date), 'cf') * 0.05;
  const r = unitHash(student.id, date, 'st');
  const t = unitHash(student.id, date, 'tm');
  const sourceRoll = unitHash(student.id, date, 'src');
  const source: AttendanceSource =
    student.device === 'NONE' ? (sourceRoll < 0.8 ? 'KIOSK' : 'MANUAL') : sourceRoll < 0.9 ? 'QR' : 'KIOSK';

  const absentP = 0.03 + classFactor * 0.6;
  const excusedP = absentP + 0.012;
  const lateP = excusedP + 0.05 + classFactor;
  const earlyP = lateP + 0.012;

  if (r < absentP) return { status: 'ABSENT', inMinute: null, outMinute: null, source: 'SYSTEM' };
  if (r < excusedP) return { status: 'EXCUSED', inMinute: null, outMinute: null, source: 'MANUAL' };

  const out = end + Math.floor(unitHash(student.id, date, 'out') * 20);
  if (r < lateP) {
    const inMinute = start + lateAfterMinutes + 1 + Math.floor(t * 24);
    return { status: 'LATE', inMinute, outMinute: out, source };
  }
  const inMinute = start - 30 + Math.floor(t * 34);
  if (r < earlyP) {
    const leave = start + 110 + Math.floor(unitHash(student.id, date, 'lv') * 90);
    return { status: 'LEFT_EARLY', inMinute, outMinute: leave, source };
  }
  return { status: 'PRESENT', inMinute, outMinute: out, source };
}

/** Rejadan (yoki saqlangan tuzatishdan) to'liq kun yozuvi. */
export function recordFromPlan(
  student: Pick<Student, 'id' | 'classId'>,
  date: IsoDate,
  plan: DayPlan,
  parentNotified: boolean,
): AttendanceRecord {
  return {
    id: `${date}:${student.id}`,
    date,
    studentId: student.id,
    classId: student.classId,
    status: plan.status,
    inAt: plan.inMinute === null ? null : minutesToHhmm(plan.inMinute),
    outAt: plan.outMinute === null ? null : minutesToHhmm(plan.outMinute),
    source: plan.source,
    corrections: [],
    parentNotified,
  };
}

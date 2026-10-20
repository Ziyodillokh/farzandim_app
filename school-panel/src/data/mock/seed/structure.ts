import type { BellPeriod, Holiday, School, SchoolClass, Shift } from '@/data/contracts';
import { minutesToHhmm } from '@/lib/utils';
import { addDays, dateRange, isoWeekday, toIsoDate } from '../calendar';

export const SHIFT_1 = 'shf-1';
export const SHIFT_2 = 'shf-2';

/** Darslar va tanaffuslar: [dars daqiqasi, keyingi tanaffus daqiqasi]. */
function buildPeriods(startMinute: number, lessons: number, breaks: readonly number[]): BellPeriod[] {
  const periods: BellPeriod[] = [];
  let cursor = startMinute;
  for (let i = 0; i < lessons; i++) {
    periods.push({ no: i + 1, start: minutesToHhmm(cursor), end: minutesToHhmm(cursor + 45), kind: 'LESSON' });
    cursor += 45;
    const pause = breaks[i];
    if (pause && i < lessons - 1) {
      periods.push({ no: i + 1, start: minutesToHhmm(cursor), end: minutesToHhmm(cursor + pause), kind: 'BREAK' });
      cursor += pause;
    }
  }
  return periods;
}

export function buildShifts(): Shift[] {
  const first = buildPeriods(8 * 60, 6, [5, 10, 20, 5, 5]);
  const second = buildPeriods(13 * 60 + 30, 5, [5, 15, 5, 5]);
  return [
    {
      id: SHIFT_1,
      name: '1-smena',
      start: first[0]!.start,
      end: first[first.length - 1]!.end,
      weekdays: [1, 2, 3, 4, 5, 6],
      periods: first,
    },
    {
      id: SHIFT_2,
      name: '2-smena',
      start: second[0]!.start,
      end: second[second.length - 1]!.end,
      weekdays: [1, 2, 3, 4, 5],
      periods: second,
    },
  ];
}

export function academicYearStart(now: Date): number {
  return now.getMonth() >= 8 ? now.getFullYear() : now.getFullYear() - 1;
}

export function buildSchool(now: Date): School {
  const y = academicYearStart(now);
  return {
    id: 'sch-1',
    name: 'Parvoz namunaviy maktabi',
    shortName: 'PNM',
    city: 'Toshkent',
    address: 'Yunusobod tumani (demo manzil)',
    phone: '+998 71 200 00 00',
    logo: null,
    academicYear: `${y}–${y + 1}`,
    lateAfterMinutes: 10,
    quarters: [
      { no: 1, start: `${y}-09-02`, end: `${y}-11-01` },
      { no: 2, start: `${y}-11-10`, end: `${y}-12-27` },
      { no: 3, start: `${y + 1}-01-12`, end: `${y + 1}-03-20` },
      { no: 4, start: `${y + 1}-03-30`, end: `${y + 1}-05-25` },
    ],
  };
}

/** O'zbekiston bayramlari + ta'til kunlari (o'quv yili bo'yicha). */
export function buildHolidays(now: Date): Holiday[] {
  const y = academicYearStart(now);
  const fixed: Array<[string, string]> = [
    [`${y}-10-01`, 'O\'qituvchi va murabbiylar kuni'],
    [`${y}-12-08`, 'Konstitutsiya kuni'],
    [`${y + 1}-01-01`, 'Yangi yil'],
    [`${y + 1}-03-08`, 'Xalqaro xotin-qizlar kuni'],
    [`${y + 1}-03-21`, 'Navro\'z bayrami'],
    [`${y + 1}-05-09`, 'Xotira va qadrlash kuni'],
  ];
  const breaks: Array<[string, string, string]> = [
    [`${y}-11-02`, `${y}-11-09`, 'Kuzgi ta\'til'],
    [`${y}-12-28`, `${y + 1}-01-11`, 'Qishki ta\'til'],
    [`${y + 1}-03-21`, `${y + 1}-03-29`, 'Bahorgi ta\'til'],
  ];
  const items: Holiday[] = fixed.map(([date, name]) => ({ id: `hol-${date}`, date, name }));
  for (const [from, to, name] of breaks) {
    for (const date of dateRange(from, to)) {
      if (isoWeekday(date) === 7 || items.some((h) => h.date === date)) continue;
      items.push({ id: `hol-${date}`, date, name });
    }
  }
  return items.sort((a, b) => a.date.localeCompare(b.date));
}

/** 1–11-sinflar, har birida A va B; 1–4 — 2-smena, 5–11 — 1-smena. */
export function buildClasses(): SchoolClass[] {
  const classes: SchoolClass[] = [];
  for (let grade = 1; grade <= 11; grade++) {
    for (const letter of ['A', 'B']) {
      classes.push({
        id: `cls-${grade}${letter.toLowerCase()}`,
        grade,
        letter,
        name: `${grade}-${letter}`,
        shiftId: grade <= 4 ? SHIFT_2 : SHIFT_1,
        homeroomStaffId: null,
        room: `${grade <= 4 ? 1 : grade <= 8 ? 2 : 3}${String(grade).padStart(2, '0')}${letter === 'A' ? '' : 'b'}`,
      });
    }
  }
  return classes;
}

export { addDays, toIsoDate };

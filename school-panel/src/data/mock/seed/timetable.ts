import type { SchoolClass, Shift, TimetableLesson, TimetableRecord, TimetableWeekday } from '@/data/contracts';
import { hashString } from '@/lib/rng';

/**
 * Demo dars jadvali: har sinf uchun, o'z smenasining DARS davrlari bo'yicha, deterministik.
 * Fanlar haftalik soatlar bo'yicha yig'iladi va "qadam" almashtirish bilan kunlarga yoyiladi —
 * bir kunda ketma-ket bir xil fan kamdan-kam uchraydi.
 */

type Plan = ReadonlyArray<readonly [subject: string, hours: number]>;

const PE = 'Jismoniy tarbiya';
const ART = 'Tasviriy san\'at';
const TECH = 'Texnologiya';
const LIT = 'Adabiyot';

const PRIMARY: Plan = [['native', 5], ['math', 5], ['Oʻqish savodxonligi', 2], ['english', 2], ['russian', 2], ['Atrofimizdagi olam', 2], [PE, 2], [ART, 1], ['Musiqa', 1], [TECH, 1]];
const MIDDLE: Plan = [['math', 5], ['native', 3], [LIT, 2], ['english', 3], ['russian', 2], ['history', 2], ['biology', 2], ['geography', 2], [PE, 2], ['informatics', 1], [TECH, 1], [ART, 1]];
const UPPER: Plan = [['math', 5], ['english', 3], ['history', 3], ['physics', 3], ['native', 2], [LIT, 2], ['russian', 2], ['biology', 2], ['chemistry', 2], ['informatics', 2], [PE, 2], ['geography', 1], ['Chaqiriqqacha boshlangʻich tayyorgarlik', 1]];

/** 7-sinfdan boshlab fizika va kimyo; 5–6-sinfda ular o'rniga tabiatshunoslik/sinf soati. */
function planFor(grade: number): Plan {
  if (grade <= 4) return PRIMARY;
  if (grade <= 8) return grade >= 7 ? [...MIDDLE.filter(([s]) => s !== TECH), ['physics', 2], ['chemistry', 2]] : MIDDLE;
  return UPPER;
}

const TEACHERS: Record<string, readonly string[]> = {
  math: ['Rasulova M.H.', 'Karimov B.T.', 'Abdullayeva N.S.'],
  native: ['Qodirova D.A.', 'Hamidova S.R.'],
  english: ['Ismoilova L.K.', 'Tursunov A.B.'],
  russian: ['Petrova O.V.', 'Sobirova G.M.'],
  history: ['Nazarov J.E.', 'Yoʻldoshev R.S.'],
  biology: ['Ergasheva Z.N.'],
  chemistry: ['Mirzayev T.A.', 'Ergasheva Z.N.'],
  physics: ['Xudoyberdiyev S.M.'],
  geography: ['Oripova F.I.'],
  informatics: ['Aliyev U.R.'],
};
const FALLBACK_TEACHERS = ['Karimova Sh.B.', 'Olimov D.T.', 'Saidova N.A.'] as const;

const SPECIAL_ROOMS: Record<string, string> = {
  informatics: 'Informatika xonasi',
  [PE]: 'Sport zali',
  physics: 'Fizika xonasi',
  chemistry: 'Kimyo xonasi',
  biology: 'Biologiya xonasi',
  Musiqa: 'Musiqa xonasi',
};

const SATURDAY_LESSONS = 4;
const SATURDAY: TimetableWeekday = 6;

function gcd(a: number, b: number): number {
  return b === 0 ? a : gcd(b, a % b);
}

/**
 * `slots` ga ko'ra fan ro'yxati: soatlar aylanma tartibda (har fan navbat bilan) terilib, kam bo'lsa
 * reja bo'yicha davom ettiriladi — bir fan ro'yxatda ketma-ket to'planib qolmaydi.
 */
function expandPlan(plan: Plan, slots: number): string[] {
  const remaining = plan.map(([, hours]) => hours);
  const base: string[] = [];
  while (remaining.some((h) => h > 0)) {
    plan.forEach(([subject], i) => {
      if ((remaining[i] ?? 0) > 0) {
        base.push(subject);
        remaining[i] = (remaining[i] ?? 0) - 1;
      }
    });
  }
  return Array.from({ length: slots }, (_, i) => base[i % base.length] ?? plan[0]![0]);
}

type Slot = { weekday: TimetableWeekday; periodNo: number };

/** Shu kunda qo'shni darsda ayni fan bormi. */
function clashesAt(subjects: readonly string[], slots: readonly Slot[], i: number): boolean {
  const same = (j: number) => slots[j]?.weekday === slots[i]?.weekday && subjects[j] === subjects[i];
  return (i > 0 && same(i - 1)) || (i < subjects.length - 1 && same(i + 1));
}

/** Bir kunda ketma-ket bir xil fan chiqsa — boshqa o'rindagi dars bilan almashtiriladi. */
function separateRepeats(subjects: readonly string[], slots: readonly Slot[]): string[] {
  const out = [...subjects];
  const swap = (a: number, b: number) => ([out[a], out[b]] = [out[b]!, out[a]!]);
  for (let i = 0; i < out.length; i++) {
    if (!clashesAt(out, slots, i)) continue;
    for (let hop = 1; hop < out.length; hop++) {
      const j = (i + hop * 5) % out.length;
      swap(i, j);
      if (!clashesAt(out, slots, i) && !clashesAt(out, slots, j)) break;
      swap(i, j);
    }
  }
  return out;
}

function teacherFor(classId: string, subject: string): string {
  const pool = TEACHERS[subject] ?? FALLBACK_TEACHERS;
  return pool[hashString(`${classId}|${subject}`) % pool.length] ?? FALLBACK_TEACHERS[0];
}

function buildClassLessons(cls: SchoolClass, shift: Shift): TimetableLesson[] {
  const lessonNos = shift.periods.filter((p) => p.kind === 'LESSON').map((p) => p.no);
  const days = shift.weekdays.filter((d): d is TimetableWeekday => d >= 1 && d <= 6);
  const slots: Slot[] = days.flatMap((weekday) =>
    lessonNos.slice(0, weekday === SATURDAY ? SATURDAY_LESSONS : lessonNos.length).map((periodNo) => ({ weekday, periodNo })),
  );
  if (slots.length === 0) return [];
  const planned = expandPlan(planFor(cls.grade), slots.length);
  // Qadam slots bilan o'zaro tub bo'lsa — almashtirish har bir fanni aynan bir marta ishlatadi.
  let stride = 7;
  while (gcd(stride, slots.length) !== 1) stride += 1;
  const offset = hashString(cls.id) % slots.length;
  const subjects = separateRepeats(
    slots.map((_, k) => planned[(k * stride + offset) % slots.length]!),
    slots,
  );
  return slots.map((slot, k) => {
    const subject = subjects[k]!;
    return {
      ...slot,
      subject,
      room: SPECIAL_ROOMS[subject] ?? cls.room,
      teacherName: teacherFor(cls.id, subject),
    };
  });
}

export function buildTimetables(classes: readonly SchoolClass[], shifts: readonly Shift[]): TimetableRecord[] {
  const shiftById = new Map(shifts.map((s) => [s.id, s]));
  return classes.map((cls) => {
    const shift = shiftById.get(cls.shiftId);
    return { classId: cls.id, lessons: shift ? buildClassLessons(cls, shift) : [] };
  });
}

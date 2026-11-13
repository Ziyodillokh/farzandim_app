import { hhmmToMinutes } from '@/lib/utils';
import { isSchoolDay } from './calendar';
import { clockMinute, clockToday } from './clock';
import { getTables } from './db';

/** Kirish smena boshidan shuncha oldin ochiladi va tugaganidan shuncha keyin yopiladi (backend bilan bir xil). */
const OPEN_BEFORE_MINUTES = 120;
const CLOSE_AFTER_MINUTES = 180;

/**
 * Demo kiosk uchun «tegiziladigan» karta: smenasi hozir ochiq va bugun hali kelmagan o'quvchining
 * faol kartasi (bo'lmasa — istalgan faol karta). Faqat demo (brauzer bazasi).
 */
export function pickDemoCardUid(): string | null {
  const t = getTables();
  const today = clockToday();
  const minute = clockMinute();
  const arrived = new Set(t.attendance.filter((r) => r.date === today && r.inAt).map((r) => r.studentId));
  const open = new Set(
    t.classes
      .filter((c) => {
        const shift = t.shifts.find((s) => s.id === c.shiftId);
        return (
          shift &&
          isSchoolDay(today, shift, t.holidays) &&
          minute >= hhmmToMinutes(shift.start) - OPEN_BEFORE_MINUTES &&
          minute <= hhmmToMinutes(shift.end) + CLOSE_AFTER_MINUTES
        );
      })
      .map((c) => c.id),
  );
  const classOf = new Map(t.students.map((s) => [s.id, s.classId]));
  const active = t.cards.filter((c) => c.status === 'ACTIVE');
  const ready = active.filter((c) => !arrived.has(c.studentId) && open.has(classOf.get(c.studentId) ?? ''));
  const pool = ready.length > 0 ? ready : active;
  return pool.length > 0 ? pool[Math.floor(Math.random() * pool.length)]!.uid : null;
}

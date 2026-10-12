'use client';

import { useEffect, useRef } from 'react';
import { toast } from 'sonner';

import { useSession } from '@/auth/use-session';
import { clockMinute, clockToday, getClockState } from '@/data/mock/clock';
import { getTables, transact } from '@/data/mock/db';
import { studentName } from '@/data/mock/lookups';
import { simulate } from '@/data/mock/simulator';
import { useI18n } from '@/i18n';

const TICK_MS = 1000;
const MAX_TOASTS_PER_TICK = 2;

/**
 * Jonli simulyator: har soniyada demo vaqtini tekshiradi, yangi daqiqa bo'lsa
 * rejadagi kirish/chiqishlarni bazaga yozadi. Birinchi "yetib olish"da
 * (masalan, sahifa 10:00 da ochilsa) toast ko'rsatilmaydi.
 */
export function DemoEngine() {
  const session = useSession();
  const { t, formatDate } = useI18n();
  const lastKey = useRef<string>('');
  const warmedUp = useRef(false);

  useEffect(() => {
    if (!session) return;
    const tick = () => {
      const date = clockToday();
      const minute = Math.floor(clockMinute());
      const epoch = getClockState().epoch;
      const key = `${date}#${epoch}#${minute}`;
      if (key === lastKey.current) return;
      lastKey.current = key;
      const sim = getTables().sim;
      if (sim.date === `${date}#${epoch}` && sim.processedUntilMinute >= minute) return;
      const events = transact((tables) => simulate(tables, date, minute, epoch));
      if (!warmedUp.current) {
        warmedUp.current = true;
        return;
      }
      const tables = getTables();
      for (const event of events.slice(0, MAX_TOASTS_PER_TICK)) {
        const student = tables.students.find((s) => s.id === event.studentId);
        const cls = tables.classes.find((c) => c.id === event.classId);
        if (!student) continue;
        const label = `${studentName(student)} · ${cls?.name ?? ''}`;
        const time = formatDate(event.at, 'HH:mm');
        if (event.kind === 'IN' && event.late) toast.warning(`${label} — ${t('enums.attendanceStatus.LATE')}`, { description: time });
        else if (event.kind === 'IN') toast.success(`${label} — ${t('enums.attendanceStatus.PRESENT')}`, { description: time, duration: 2500 });
      }
    };
    tick();
    const id = setInterval(tick, TICK_MS);
    return () => clearInterval(id);
  }, [session, t, formatDate]);

  return null;
}

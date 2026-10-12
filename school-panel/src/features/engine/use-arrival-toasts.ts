'use client';

import { useCallback, useEffect, useRef } from 'react';
import { toast } from 'sonner';

import type { AttendanceEvent } from '@/data/contracts';
import { getTables } from '@/data/mock/db';
import { studentName } from '@/data/mock/lookups';
import { useI18n } from '@/i18n';
import { type ArrivalViewer, summarizeArrivals, visibleEvents } from './arrivals';

/** Kelish toast'lari ko'pi bilan ~5 soniyada bir marta. */
const THROTTLE_MS = 5000;
const BATCH_TOAST_ID = 'arrivals';
const SINGLE_DURATION_MS = 2500;
const BATCH_DURATION_MS = 4000;

/**
 * Kelishlarni rol/doira bo'yicha filtrlaydi va yig'adi: 1–2 ta — ismli toast,
 * ko'p — bitta yangilanadigan "N nafar o'quvchi keldi" toast'i.
 */
export function useArrivalToasts(viewer: ArrivalViewer | null): (events: readonly AttendanceEvent[]) => void {
  const i18n = useI18n();
  const i18nRef = useRef(i18n);
  useEffect(() => {
    i18nRef.current = i18n;
  }, [i18n]);
  const buffer = useRef<AttendanceEvent[]>([]);
  const lastFlush = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const flush = useCallback(() => {
    timer.current = null;
    lastFlush.current = Date.now();
    const events = buffer.current;
    buffer.current = [];
    const { t, tc, formatDate } = i18nRef.current;
    const summary = summarizeArrivals(events);
    if (summary.kind === 'BATCH') {
      toast.success(tc('demo.arrivals.batch', summary.count), {
        id: BATCH_TOAST_ID,
        description: summary.late > 0 ? t('demo.arrivals.late', { late: summary.late }) : t('demo.arrivals.onTime'),
        duration: BATCH_DURATION_MS,
      });
      return;
    }
    if (summary.kind !== 'SINGLE') return;
    const tables = getTables();
    for (const event of summary.events) {
      const student = tables.students.find((s) => s.id === event.studentId);
      if (!student) continue;
      const cls = tables.classes.find((c) => c.id === event.classId);
      const label = `${studentName(student)} · ${cls?.name ?? ''}`;
      const time = formatDate(event.at, 'HH:mm');
      if (event.late) toast.warning(`${label} — ${t('enums.attendanceStatus.LATE')}`, { description: time });
      else toast.success(`${label} — ${t('enums.attendanceStatus.PRESENT')}`, { description: time, duration: SINGLE_DURATION_MS });
    }
  }, []);

  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );

  return useCallback(
    (events: readonly AttendanceEvent[]) => {
      if (!viewer) return;
      const visible = visibleEvents(events, viewer);
      if (visible.length === 0) return;
      buffer.current = [...buffer.current, ...visible];
      if (timer.current) return;
      const wait = lastFlush.current + THROTTLE_MS - Date.now();
      if (wait <= 0) flush();
      else timer.current = setTimeout(flush, wait);
    },
    [viewer, flush],
  );
}

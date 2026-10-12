import { roleHas, ROLES } from '@/auth/permissions';
import type { AttendanceEvent, RoleKey } from '@/data/contracts';

/** Kim toast ko'radi: rol va (sinf rahbari uchun) biriktirilgan sinflar. */
export type ArrivalViewer = { role: RoleKey; classIds: readonly string[] };

export type ArrivalSummary =
  | { kind: 'NONE' }
  | { kind: 'SINGLE'; events: AttendanceEvent[] }
  | { kind: 'BATCH'; count: number; late: number };

/** Shu sondan ko'p kelish — bitta umumlashgan toast. */
export const SINGLE_MAX = 2;

/**
 * Faqat kelishlar (IN); `attendance.view` bo'lmasa (psixolog) — hech narsa;
 * sinf doirasidagi rol faqat o'z sinflarini ko'radi.
 */
export function visibleEvents(events: readonly AttendanceEvent[], viewer: ArrivalViewer): AttendanceEvent[] {
  if (!roleHas(viewer.role, 'attendance.view')) return [];
  const arrivals = events.filter((e) => e.kind === 'IN');
  if (ROLES[viewer.role].scope === 'SCHOOL') return arrivals;
  return arrivals.filter((e) => viewer.classIds.includes(e.classId));
}

export function summarizeArrivals(events: readonly AttendanceEvent[]): ArrivalSummary {
  if (events.length === 0) return { kind: 'NONE' };
  if (events.length <= SINGLE_MAX) return { kind: 'SINGLE', events: [...events] };
  return { kind: 'BATCH', count: events.length, late: events.filter((e) => e.late).length };
}

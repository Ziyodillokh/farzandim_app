/**
 * Routines: Tashkent (UTC+5, no DST) time and window checks.
 * Pure functions for easy testing.
 */

export interface RoutineWindow {
  startHour: number;
  startMinute: number;
  endHour: number;
  endMinute: number;
}

/**
 * Get current Tashkent time + ISO 8601 weekday (1=Mon, 7=Sun).
 * `now` parameter can be injected for testing.
 */
export function tashkentNow(now: Date = new Date()): {
  isoWeekday: number;
  hour: number;
  minute: number;
  totalMinutes: number;
} {
  const tashkent = new Date(now.getTime() + 5 * 60 * 60 * 1000);
  const utcDay = tashkent.getUTCDay(); // 0=Sun..6=Sat
  const isoWeekday = utcDay === 0 ? 7 : utcDay;
  const hour = tashkent.getUTCHours();
  const minute = tashkent.getUTCMinutes();
  return { isoWeekday, hour, minute, totalMinutes: hour * 60 + minute };
}

/**
 * Check whether the current time falls within a routine window.
 * Supports wrap-around (e.g. 22:00 -> 06:00 sleep window).
 */
export function isActiveNow(r: RoutineWindow, nowMin: number): boolean {
  const startMin = r.startHour * 60 + r.startMinute;
  const endMin = r.endHour * 60 + r.endMinute;
  if (startMin < endMin) {
    return nowMin >= startMin && nowMin < endMin;
  }
  // wrap-around
  return nowMin >= startMin || nowMin < endMin;
}

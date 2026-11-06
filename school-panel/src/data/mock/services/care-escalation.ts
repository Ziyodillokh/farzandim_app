import type { CareRequest, CareSettings, IsoDate } from '@/data/contracts';
import { hhmmToMinutes } from '@/lib/utils';
import { isoWeekday, toIsoDate, toLocalIso } from '../calendar';
import type { Tables } from '../tables';
import { readCareSettings } from './care-settings';

/**
 * O'rinbosarga o'tkazish (kontrakt C, cron har 5 daqiqada): ochilmagan (`openedAt = null`), hali o'tkazilmagan,
 * holati NEW murojaat muddatdan o'tsa va o'rinbosar belgilangan bo'lsa — murojaat o'rinbosarga biriktiriladi.
 * Muddat — ish vaqti hisobida: shoshilinch — `urgentSlaMinutes`, oddiy — `normalSlaHours`.
 */

const MINUTE_MS = 60_000;
/** Cheksiz aylanishdan himoya: shuncha kundan eski murojaat ham hisoblanadi (~13 oy). */
const MAX_DAYS = 400;

export type WorkSchedule = Pick<CareSettings, 'workDays' | 'workStart' | 'workEnd'>;

/** `from`…`to` oralig'idagi ish vaqti daqiqalari (ish kunlari, ish soatlari, bayramsiz). */
export function workingMinutesBetween(fromMs: number, toMs: number, schedule: WorkSchedule, holidays: ReadonlySet<IsoDate>): number {
  const open = hhmmToMinutes(schedule.workStart);
  const close = hhmmToMinutes(schedule.workEnd);
  if (!(toMs > fromMs) || !(close > open) || schedule.workDays.length === 0) return 0;
  const last = toIsoDate(new Date(toMs));
  let total = 0;
  let day = new Date(fromMs);
  day = new Date(day.getFullYear(), day.getMonth(), day.getDate());
  for (let i = 0; i < MAX_DAYS; i++) {
    const iso = toIsoDate(day);
    if (iso > last) break;
    if (schedule.workDays.includes(isoWeekday(iso)) && !holidays.has(iso)) {
      const startMs = day.getTime() + open * MINUTE_MS;
      const endMs = day.getTime() + close * MINUTE_MS;
      total += Math.max(0, Math.min(endMs, toMs) - Math.max(startMs, fromMs)) / MINUTE_MS;
    }
    day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
  }
  return Math.floor(total);
}

/** Murojaat uchun ruxsat etilgan muddat (ish vaqti daqiqalarida). */
export function slaMinutes(urgency: CareRequest['urgency'], settings: Pick<CareSettings, 'urgentSlaMinutes' | 'normalSlaHours'>): number {
  return urgency === 'URGENT' ? settings.urgentSlaMinutes : settings.normalSlaHours * 60;
}

function isOverdue(request: CareRequest, settings: CareSettings, holidays: ReadonlySet<IsoDate>, nowMs: number): boolean {
  return workingMinutesBetween(Date.parse(request.createdAt), nowMs, settings, holidays) >= slaMinutes(request.urgency, settings);
}

/** Muddatdan o'tgan ochilmagan murojaatlarni o'rinbosarga o'tkazadi (`tables` — tranzaksiya nusxasi). Soni qaytadi. */
export function escalateOverdueRequests(tables: Tables, nowMs: number): number {
  const settings = readCareSettings(tables);
  const deputy = settings.deputyStaffId;
  if (!deputy) return 0;
  const holidays = new Set(tables.holidays.map((h) => h.date));
  const stamp = toLocalIso(new Date(nowMs));
  let count = 0;
  tables.careRequests = tables.careRequests.map((r) => {
    if (r.openedAt !== null || r.escalatedAt !== null || r.status !== 'NEW' || !isOverdue(r, settings, holidays, nowMs)) return r;
    count += 1;
    return { ...r, assignedStaffId: deputy, escalatedAt: stamp };
  });
  return count;
}

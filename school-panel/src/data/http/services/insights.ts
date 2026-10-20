import type { NotificationItem } from '@/data/contracts';
import type { dashboardService } from '@/data/mock/services/dashboard';
import type { notificationsService } from '@/data/mock/services/notifications';
import type { reportsService } from '@/data/mock/services/reports';
import type { searchService } from '@/data/mock/services/search';
import { http } from '../client';

type Dashboard = typeof dashboardService;
type Reports = typeof reportsService;
type Search = typeof searchService;

/** O'quv yili sentyabrda boshlanadi — oylar ro'yxati (yangisi birinchi) server so'rovisiz. */
const ACADEMIC_YEAR_START_MONTH = 9;
const TASHKENT_OFFSET_MS = 5 * 3_600_000;

export function academicMonths(now = new Date()): string[] {
  const local = new Date(now.getTime() + TASHKENT_OFFSET_MS);
  const year = local.getUTCFullYear();
  const month = local.getUTCMonth() + 1;
  let y = month >= ACADEMIC_YEAR_START_MONTH ? year : year - 1;
  let m = ACADEMIC_YEAR_START_MONTH;
  const end = `${year}-${String(month).padStart(2, '0')}`;
  const out: string[] = [];
  for (;;) {
    const key = `${y}-${String(m).padStart(2, '0')}`;
    if (key > end) return out;
    out.unshift(key);
    m += 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
  }
}

export const dashboardHttp: Dashboard = {
  overview: () => http<Awaited<ReturnType<Dashboard['overview']>>>('GET', '/school/dashboard/overview'),
};

export const notificationsHttp: typeof notificationsService = {
  feed: () => http<NotificationItem[]>('GET', '/school/notifications/feed'),
};

export const reportsHttp: Reports = {
  months: () => academicMonths(),
  monthly: (month) => http<Awaited<ReturnType<Reports['monthly']>>>('GET', '/school/reports/monthly', { query: { month } }),
};

export const searchHttp: Search = {
  query: (q, limit = 6) => http<Awaited<ReturnType<Search['query']>>>('GET', '/school/search', { query: { q, limit } }),
};

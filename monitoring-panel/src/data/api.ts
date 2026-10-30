/**
 * Ma'lumotlar fasadi — sahifalar faqat shu orqali so'raydi. Hozir demo
 * (deterministik model); haqiqiy API tayyor bo'lganda shu shakllar bilan
 * http adapter qo'shiladi (`NEXT_PUBLIC_DATA_SOURCE=http`).
 */
import type { Filters, MetricKey, Scope } from '@/data/contracts';
import { getInsights } from '@/data/mock/services/insights';
import { getInterests, getIq, getMastery } from '@/data/mock/services/learning';
import { getAttendance, getDigital, getWellbeing } from '@/data/mock/services/life';
import { getAreaMatrix, getAreaMetric, getOverview, getRegionsTable } from '@/data/mock/services/overview';
import { getSchools } from '@/data/mock/services/schools';

/** Og'ir hisob UI'ni bloklamasin: keyingi tikda bajariladi. */
function defer<T>(fn: () => T): Promise<T> {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      try {
        resolve(fn());
      } catch (error) {
        reject(error);
      }
    }, 0);
  });
}

export const api = {
  overview: (scope: Scope, f: Filters) => defer(() => getOverview(scope, f)),
  areaMetric: (metric: MetricKey, scope: Scope, f: Filters) => defer(() => getAreaMetric(metric, scope, f)),
  regionsTable: (f: Filters) => defer(() => getRegionsTable(f)),
  areaMatrix: (metrics: readonly MetricKey[], scope: Scope, f: Filters) => defer(() => getAreaMatrix(metrics, scope, f)),
  mastery: (scope: Scope, f: Filters) => defer(() => getMastery(scope, f)),
  iq: (scope: Scope, f: Filters) => defer(() => getIq(scope, f)),
  interests: (scope: Scope, f: Filters) => defer(() => getInterests(scope, f)),
  wellbeing: (scope: Scope, f: Filters) => defer(() => getWellbeing(scope, f)),
  attendance: (scope: Scope, f: Filters) => defer(() => getAttendance(scope, f)),
  digital: (scope: Scope, f: Filters) => defer(() => getDigital(scope, f)),
  schools: (scope: Scope, f: Filters) => defer(() => getSchools(scope, f)),
  insights: (scope: Scope, f: Filters) => defer(() => getInsights(scope, f)),
};

export type Api = typeof api;

/** Demo ma'lumotlarmi (hamma joyda "Demo" belgisi ko'rsatiladi). */
export const IS_DEMO_DATA = true;

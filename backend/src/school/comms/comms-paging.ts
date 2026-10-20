// Xotiradagi ro'yxatni sahifalash (panel `paginate` bilan bir xil: sahifa
// raqami chegaradan chiqsa — oxirgi sahifa).

import { paginate } from '../common/school-zod';

export function pageOf<T>(items: readonly T[], page: number, limit: number) {
  const totalPages = Math.max(1, Math.ceil(items.length / limit));
  const safePage = Math.min(Math.max(1, page), totalPages);
  const start = (safePage - 1) * limit;
  return paginate(items.slice(start, start + limit), items.length, { page: safePage, limit });
}

/** Holatlar bo'yicha sonlar (o'zgarmas yig'ish). */
export function countBy<T, K extends string>(items: readonly T[], keys: readonly K[], keyOf: (item: T) => K): Record<K | 'ALL', number> {
  const zero = Object.fromEntries(keys.map((k) => [k, 0])) as Record<K, number>;
  const counts = items.reduce<Record<K, number>>((acc, item) => ({ ...acc, [keyOf(item)]: acc[keyOf(item)] + 1 }), zero);
  return { ALL: items.length, ...counts } as Record<K | 'ALL', number>;
}

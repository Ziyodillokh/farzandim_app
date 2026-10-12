import type { ListQuery, Paginated, SortDir } from '@/data/contracts';
import { matchesSearch } from '@/lib/normalize-search';

export const DEFAULT_LIMIT = 20;

export function paginate<T>(items: readonly T[], page = 1, limit = DEFAULT_LIMIT): Paginated<T> {
  const safeLimit = Math.max(1, Math.min(500, limit));
  const total = items.length;
  const totalPages = Math.max(1, Math.ceil(total / safeLimit));
  const safePage = Math.min(Math.max(1, page), totalPages);
  const start = (safePage - 1) * safeLimit;
  return {
    items: items.slice(start, start + safeLimit),
    pagination: { page: safePage, limit: safeLimit, total, totalPages },
  };
}

type Sortable = string | number | boolean | null | undefined;

const collator = new Intl.Collator('uz', { sensitivity: 'base', numeric: true });

export function sortItems<T>(items: readonly T[], key: (item: T) => Sortable, dir: SortDir = 'asc'): T[] {
  const sign = dir === 'asc' ? 1 : -1;
  return [...items].sort((a, b) => {
    const va = key(a);
    const vb = key(b);
    if (va === vb) return 0;
    if (va === null || va === undefined) return 1;
    if (vb === null || vb === undefined) return -1;
    if (typeof va === 'string' && typeof vb === 'string') return collator.compare(va, vb) * sign;
    return (va < vb ? -1 : 1) * sign;
  });
}

/**
 * Ro'yxat so'rovi: qidiruv → saralash → sahifalash.
 * `sorters` — ruxsat etilgan saralash maydonlari (noma'lumi e'tiborsiz).
 */
export function runListQuery<T>(
  items: readonly T[],
  query: ListQuery,
  options: { searchText: (item: T) => string; sorters: Record<string, (item: T) => Sortable>; defaultSort?: string },
): Paginated<T> {
  const searched = query.search ? items.filter((i) => matchesSearch(options.searchText(i), query.search ?? '')) : items;
  const sortKey = query.sortBy && options.sorters[query.sortBy] ? query.sortBy : options.defaultSort;
  const sorted = sortKey ? sortItems(searched, options.sorters[sortKey]!, query.sortDir ?? 'asc') : [...searched];
  return paginate(sorted, query.page, query.limit);
}

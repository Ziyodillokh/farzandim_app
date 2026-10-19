// Ro'yxat so'rovi (panel `runListQuery` bilan bir xil): qidiruv → saralash
// → sahifalash. Kichik jadvallar (xodimlar, o'quvchilar) xotirada.

import { ListQuery, paginate } from './school-zod';

/** Kichik harf, o'zbek apostroflari bitta belgiga, ortiqcha bo'shliq — bitta. */
const APOSTROPHES = /[ʻʼ’‘`´']/g;

export function normalizeSearch(value: string): string {
  return value.toLowerCase().replace(APOSTROPHES, "'").replace(/\s+/g, ' ').trim();
}

export function matchesSearch(haystack: string, query: string): boolean {
  const q = normalizeSearch(query);
  if (!q) return true;
  return normalizeSearch(haystack).includes(q);
}

type Sortable = string | number | boolean | null | undefined;

const collator = new Intl.Collator('uz', { sensitivity: 'base', numeric: true });

export const compareUz = (a: string, b: string) => collator.compare(a, b);

export function sortItems<T>(items: readonly T[], key: (item: T) => Sortable, dir: 'asc' | 'desc' = 'asc'): T[] {
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

export function runListQuery<T>(
  items: readonly T[],
  query: ListQuery,
  options: {
    searchText: (item: T) => string;
    sorters: Record<string, (item: T) => Sortable>;
    defaultSort?: string;
  },
) {
  const searched = query.search
    ? items.filter((i) => matchesSearch(options.searchText(i), query.search ?? ''))
    : [...items];
  const sortKey = query.sortBy && options.sorters[query.sortBy] ? query.sortBy : options.defaultSort;
  const sorted = sortKey
    ? sortItems(searched, options.sorters[sortKey]!, query.sortDir ?? 'asc')
    : searched;
  const totalPages = Math.max(1, Math.ceil(sorted.length / query.limit));
  const page = Math.min(query.page, totalPages);
  const start = (page - 1) * query.limit;
  return paginate(sorted.slice(start, start + query.limit), sorted.length, { ...query, page });
}

/** Sinflar tartibi: sinf raqami, keyin harf. */
export function compareClasses(
  a: { grade: number; letter: string },
  b: { grade: number; letter: string },
): number {
  return a.grade - b.grade || a.letter.localeCompare(b.letter);
}

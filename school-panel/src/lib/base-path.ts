/** basePath (`/school`) — raw `<a>`, window.location va public fayllar uchun. */
export const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

export function withBase(path: string): string {
  if (!path.startsWith('/')) return path;
  return `${BASE_PATH}${path}`;
}

/** usePathname natijasini taqqoslash uchun: oxirgi `/` olib tashlanadi. */
export function normalizePath(path: string): string {
  if (path.length > 1 && path.endsWith('/')) return path.slice(0, -1);
  return path;
}

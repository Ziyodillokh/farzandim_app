import type { Permission } from '@/auth/permissions';
import { NAV_GROUP_ORDER, type NavGroup, type RouteDef, ROUTES } from '@/auth/route-manifest';

export type NavNode = RouteDef & { children: RouteDef[] };
export type NavSection = { group: NavGroup; items: NavNode[] };

/** Rol ruxsatlariga ko'ra menyu bo'limlari. */
export function buildNav(can: (p: Permission) => boolean): NavSection[] {
  return NAV_GROUP_ORDER.map((group) => ({
    group,
    items: ROUTES.filter((r) => r.group === group && !r.hidden && can(r.perm)).map((r) => ({
      ...r,
      children: ROUTES.filter((c) => c.parent === r.path && can(c.perm)),
    })),
  })).filter((s) => s.items.length > 0);
}

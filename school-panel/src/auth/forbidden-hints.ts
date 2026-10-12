import type { RoleKey } from '@/data/contracts';
import type { TKey } from '@/i18n/translate';
import { type Permission, roleHas, ROLES } from './permissions';
import { findRoute, type RouteDef, ROUTES } from './route-manifest';

/** "Ruxsat yo'q" sahifasidagi muqobil havolalar soni. */
const MAX_LINKS = 3;
const HOME = '/dashboard';

export type ForbiddenLink = { path: string; titleKey: TKey };

export type ForbiddenHint = {
  /** Yopiq bo'lim nomi (manifestda bo'lsa). */
  sectionKey: TKey | null;
  /** Shu bo'limga kirish huquqi bor rollar. */
  allowedRoles: RoleKey[];
  /** Rolga mos maslahat (direktorga "direktorga murojaat qiling" demaydi). */
  adviceKey: TKey;
  /** Shu rolga ochiq, mavzuga yaqin bo'limlar (ko'pi bilan 3 ta, bosh sahifasiz). */
  links: ForbiddenLink[];
};

const ROLE_ORDER: readonly RoleKey[] = ['DIRECTOR', 'ADMIN', 'HOMEROOM', 'PSYCHOLOGIST', 'DUTY', 'TEACHER'];

const ADVICE: Record<RoleKey, TKey> = {
  DIRECTOR: 'auth.forbiddenAdvice.DIRECTOR',
  ADMIN: 'auth.forbiddenAdvice.ADMIN',
  HOMEROOM: 'auth.forbiddenAdvice.STAFF',
  PSYCHOLOGIST: 'auth.forbiddenAdvice.STAFF',
  DUTY: 'auth.forbiddenAdvice.STAFF',
  TEACHER: 'auth.forbiddenAdvice.STAFF',
};

function rolesWith(permission: Permission): RoleKey[] {
  return ROLE_ORDER.filter((role) => ROLES[role].permissions.includes(permission));
}

/** Yopiq marshrutning ota bo'limi yoki menyu guruhi (yaqin muqobillarni topish uchun). */
function familyOf(route: RouteDef | undefined): { parent: string | null; group: string | null } {
  if (!route) return { parent: null, group: null };
  const parentPath = route.parent ?? route.path.split('/').slice(0, 2).join('/');
  const top = ROUTES.find((r) => r.path === parentPath && r.group);
  return { parent: parentPath, group: route.group ?? top?.group ?? null };
}

/** 0 — shu bo'lim ichida, 1 — shu menyu guruhida, 2 — boshqa asosiy bo'lim, 3 — boshqa ichki sahifa. */
function relevance(route: RouteDef, family: ReturnType<typeof familyOf>): number {
  if (family.parent && (route.parent === family.parent || route.path === family.parent)) return 0;
  const group = route.group ?? ROUTES.find((r) => r.path === route.parent && r.group)?.group;
  if (family.group && group === family.group) return 1;
  return route.group ? 2 : 3;
}

/** Rolga ochiq muqobil sahifalar: avval shu bo'lim/guruh ichidan, keyin menyu tartibida. */
function alternatives(role: RoleKey, route: RouteDef | undefined, path: string): ForbiddenLink[] {
  const family = familyOf(route);
  const seen = new Set<string>([HOME, path]);
  const candidates = ROUTES.filter((r) => !r.hidden && !r.external && roleHas(role, r.perm)).filter((r) => {
    if (seen.has(r.path)) return false;
    seen.add(r.path);
    return true;
  });
  return candidates
    .map((r, order) => ({ r, order, score: relevance(r, family) }))
    .sort((a, b) => a.score - b.score || a.order - b.order)
    .slice(0, MAX_LINKS)
    .map(({ r }) => ({ path: r.path, titleKey: r.titleKey }));
}

/** Rol va yo'l bo'yicha "Ruxsat yo'q" izohi va muqobil havolalar. */
export function forbiddenHints(role: RoleKey, path: string): ForbiddenHint {
  const route = findRoute(path);
  return {
    sectionKey: route?.titleKey ?? null,
    allowedRoles: route ? rolesWith(route.perm) : [],
    adviceKey: ADVICE[role],
    links: alternatives(role, route, route?.path ?? path),
  };
}

/**
 * Rollar va ruxsatlar — YAGONA manba (menyu, sahifa himoyasi, tugmalar).
 *
 * NATIONAL — respublika tahlil markazi: barcha hududlar, solishtirish, eksport.
 * REGIONAL — viloyat ta'lim boshqarmasi: o'z hududi (tumanlar bilan) va
 *            respublika o'rtachasi bilan solishtirish; boshqa hududlar profili yopiq.
 */
export const PERMISSIONS = [
  'dashboard.view',
  'regions.view',
  'regions.compare',
  'region.view',
  'domains.view',
  'schools.view',
  'reports.view',
  'reports.export',
  'present.view',
  'settings.view',
] as const;

export type Permission = (typeof PERMISSIONS)[number];

export const ROLE_KEYS = ['NATIONAL', 'REGIONAL'] as const;
export type RoleKey = (typeof ROLE_KEYS)[number];

export type RoleDef = { permissions: readonly Permission[] };

export const ROLES: Record<RoleKey, RoleDef> = {
  NATIONAL: { permissions: PERMISSIONS },
  REGIONAL: {
    permissions: PERMISSIONS.filter((p) => p !== 'regions.view' && p !== 'regions.compare'),
  },
};

export function roleHas(role: RoleKey, permission: Permission): boolean {
  return ROLES[role]?.permissions.includes(permission) ?? false;
}

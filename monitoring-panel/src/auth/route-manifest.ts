import {
  BookMarked,
  BookOpenCheck,
  Brain,
  CalendarCheck2,
  Compass,
  FileBarChart2,
  HeartHandshake,
  LayoutDashboard,
  type LucideIcon,
  Map,
  MonitorPlay,
  School,
  Settings,
  Smartphone,
} from 'lucide-react';

import type { TKey } from '@/i18n';
import type { Permission } from './permissions';

/**
 * Marshrutlar manifesti — YAGONA manba: menyu, sahifa himoyasi (RouteGuard),
 * global qidiruv va e2e. `path` — basePath'siz, oxirida `/` siz.
 * DIQQAT: e2e va shots skriptlari `{ path: '…', perm: '…'` ni regex bilan o'qiydi —
 * har yozuv bitta qatorda, `path` birinchi, `perm` ikkinchi.
 */
export type NavGroup = 'overview' | 'domains' | 'tools';

export type RouteDef = {
  path: string;
  perm: Permission;
  titleKey: TKey;
  icon: LucideIcon;
  group?: NavGroup;
  /** Menyuda ko'rsatilmaydi (tafsilot va chop etish sahifalari). */
  hidden?: boolean;
};

export const ROUTES: readonly RouteDef[] = [
  { path: '/dashboard', perm: 'dashboard.view', titleKey: 'nav.dashboard', icon: LayoutDashboard, group: 'overview' },
  { path: '/regions', perm: 'regions.view', titleKey: 'nav.regions', icon: Map, group: 'overview' },
  { path: '/regions/view', perm: 'region.view', titleKey: 'nav.region', icon: Map, hidden: true },
  { path: '/schools', perm: 'schools.view', titleKey: 'nav.schools', icon: School, group: 'overview' },
  { path: '/mastery', perm: 'domains.view', titleKey: 'nav.mastery', icon: BookOpenCheck, group: 'domains' },
  { path: '/iq', perm: 'domains.view', titleKey: 'nav.iq', icon: Brain, group: 'domains' },
  { path: '/interests', perm: 'domains.view', titleKey: 'nav.interests', icon: Compass, group: 'domains' },
  { path: '/wellbeing', perm: 'domains.view', titleKey: 'nav.wellbeing', icon: HeartHandshake, group: 'domains' },
  { path: '/attendance', perm: 'domains.view', titleKey: 'nav.attendance', icon: CalendarCheck2, group: 'domains' },
  { path: '/digital', perm: 'domains.view', titleKey: 'nav.digital', icon: Smartphone, group: 'domains' },
  { path: '/reports', perm: 'reports.view', titleKey: 'nav.reports', icon: FileBarChart2, group: 'tools' },
  { path: '/reports/print', perm: 'reports.view', titleKey: 'nav.reports', icon: FileBarChart2, hidden: true },
  { path: '/methodology', perm: 'reports.view', titleKey: 'nav.methodology', icon: BookMarked, group: 'tools' },
  { path: '/present', perm: 'present.view', titleKey: 'nav.present', icon: MonitorPlay, group: 'tools' },
  { path: '/settings', perm: 'settings.view', titleKey: 'nav.settings', icon: Settings, group: 'tools' },
];

export const NAV_GROUP_ORDER: readonly NavGroup[] = ['overview', 'domains', 'tools'];

/** Joriy yo'l uchun eng aniq mos keladigan marshrut (ruxsat tekshiruvi uchun). */
export function findRoute(path: string): RouteDef | undefined {
  const normalized = path.length > 1 && path.endsWith('/') ? path.slice(0, -1) : path;
  // Eng uzun mos yo'l: ichki sahifa (masalan /regions/view) o'z ruxsati bilan tekshiriladi.
  return ROUTES.filter((r) => normalized === r.path || normalized.startsWith(`${r.path}/`)).sort(
    (a, b) => b.path.length - a.path.length,
  )[0];
}

export const ROUTE_PATHS = ROUTES.map((r) => r.path);

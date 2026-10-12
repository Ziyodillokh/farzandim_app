import {
  Activity,
  BarChart3,
  Bell,
  BookOpen,
  CalendarClock,
  CalendarOff,
  ClipboardCheck,
  ClipboardList,
  FileCheck2,
  HeartHandshake,
  History,
  LayoutDashboard,
  LogOut,
  MessageSquareHeart,
  MessagesSquare,
  type LucideIcon,
  QrCode,
  Receipt,
  ScrollText,
  Settings,
  ShieldCheck,
  ShieldOff,
  Smartphone,
  UserCog,
  Users,
  UsersRound,
  Wallet,
  GraduationCap,
  Radio,
  ListChecks,
} from 'lucide-react';

import type { TKey } from '@/i18n';
import type { Permission } from './permissions';

/**
 * Marshrutlar manifesti — YAGONA manba: menyu, sahifa himoyasi (RouteGuard),
 * global qidiruvdagi "Sahifalar" va rol bo'yicha bosh sahifa shundan olinadi.
 * `path` — basePath'siz, oxirida `/` siz.
 */
export type NavGroup = 'main' | 'school' | 'communication' | 'wellbeing' | 'admin';

export type RouteDef = {
  path: string;
  perm: Permission;
  titleKey: TKey;
  icon: LucideIcon;
  group?: NavGroup;
  /** Menyuda ota bo'lim ostida ko'rsatiladi. */
  parent?: string;
  /** Menyuda ko'rsatilmaydi (tafsilot sahifalari). */
  hidden?: boolean;
  /** Yangi tabda ochiladi (kiosk). */
  external?: boolean;
};

export const ROUTES: readonly RouteDef[] = [
  { path: '/dashboard', perm: 'dashboard.view', titleKey: 'nav.dashboard', icon: LayoutDashboard, group: 'main' },

  { path: '/attendance', perm: 'attendance.view', titleKey: 'nav.attendance', icon: ClipboardCheck, group: 'school' },
  { path: '/attendance', perm: 'attendance.view', titleKey: 'nav.attendanceBoard', icon: ClipboardCheck, parent: '/attendance' },
  { path: '/attendance/feed', perm: 'attendance.view', titleKey: 'nav.attendanceFeed', icon: Radio, parent: '/attendance' },
  { path: '/attendance/early-exit', perm: 'attendance.view', titleKey: 'nav.attendanceEarlyExit', icon: LogOut, parent: '/attendance' },
  { path: '/attendance/corrections', perm: 'attendance.correct', titleKey: 'nav.attendanceCorrections', icon: History, parent: '/attendance' },
  { path: '/attendance/reports', perm: 'attendance.history', titleKey: 'nav.attendanceReports', icon: BarChart3, parent: '/attendance' },
  { path: '/attendance/class', perm: 'attendance.view', titleKey: 'nav.attendanceBoard', icon: ClipboardCheck, hidden: true },
  { path: '/kiosk', perm: 'attendance.kiosk', titleKey: 'nav.kiosk', icon: QrCode, group: 'school', external: true },

  { path: '/school-mode', perm: 'schoolMode.view', titleKey: 'nav.schoolMode', icon: Smartphone, group: 'school' },
  { path: '/school-mode', perm: 'schoolMode.view', titleKey: 'nav.schoolModeLive', icon: Activity, parent: '/school-mode' },
  { path: '/school-mode/schedule', perm: 'schoolMode.view', titleKey: 'nav.schoolModeSchedule', icon: CalendarClock, parent: '/school-mode' },
  { path: '/school-mode/policies', perm: 'schoolMode.view', titleKey: 'nav.schoolModePolicies', icon: ShieldCheck, parent: '/school-mode' },
  { path: '/school-mode/exceptions', perm: 'schoolMode.view', titleKey: 'nav.schoolModeExceptions', icon: ShieldOff, parent: '/school-mode' },
  { path: '/school-mode/holidays', perm: 'schoolMode.view', titleKey: 'nav.schoolModeHolidays', icon: CalendarOff, parent: '/school-mode' },

  { path: '/classes', perm: 'classes.view', titleKey: 'nav.classes', icon: GraduationCap, group: 'school' },
  { path: '/classes/view', perm: 'classes.view', titleKey: 'nav.classes', icon: GraduationCap, hidden: true },
  { path: '/students', perm: 'students.view', titleKey: 'nav.students', icon: Users, group: 'school' },
  { path: '/students/view', perm: 'students.view', titleKey: 'nav.students', icon: Users, hidden: true },
  { path: '/parents', perm: 'guardians.link', titleKey: 'nav.parents', icon: UsersRound, group: 'school' },

  { path: '/messages', perm: 'messages.view', titleKey: 'nav.messages', icon: MessagesSquare, group: 'communication' },
  { path: '/messages/new', perm: 'messages.view', titleKey: 'nav.messages', icon: MessagesSquare, hidden: true },
  { path: '/reminders', perm: 'reminders.manage', titleKey: 'nav.reminders', icon: Bell, group: 'communication' },
  { path: '/reminders', perm: 'reminders.manage', titleKey: 'nav.reminders', icon: Bell, parent: '/reminders' },
  { path: '/reminders/payments', perm: 'payments.manage', titleKey: 'nav.payments', icon: Wallet, parent: '/reminders' },
  { path: '/reminders/verifications', perm: 'payments.manage', titleKey: 'nav.verifications', icon: Receipt, parent: '/reminders' },

  { path: '/care', perm: 'care.aggregate', titleKey: 'nav.care', icon: HeartHandshake, group: 'wellbeing' },
  { path: '/care', perm: 'care.aggregate', titleKey: 'nav.careOverview', icon: BarChart3, parent: '/care' },
  { path: '/care/requests', perm: 'care.individual', titleKey: 'nav.careRequests', icon: MessageSquareHeart, parent: '/care' },
  { path: '/care/requests/view', perm: 'care.individual', titleKey: 'nav.careRequests', icon: MessageSquareHeart, hidden: true },
  { path: '/care/surveys', perm: 'care.surveys', titleKey: 'nav.careSurveys', icon: ListChecks, parent: '/care' },
  { path: '/learning', perm: 'learning.view', titleKey: 'nav.learning', icon: BookOpen, group: 'wellbeing' },

  { path: '/reports', perm: 'reports.view', titleKey: 'nav.reports', icon: FileCheck2, group: 'admin' },
  { path: '/reports/print', perm: 'reports.view', titleKey: 'nav.reports', icon: ClipboardList, hidden: true },
  { path: '/staff', perm: 'staff.view', titleKey: 'nav.staff', icon: UserCog, group: 'admin' },
  { path: '/audit', perm: 'audit.view', titleKey: 'nav.audit', icon: ScrollText, group: 'admin' },
  { path: '/settings', perm: 'settings.manage', titleKey: 'nav.settings', icon: Settings, group: 'admin' },
];

export const NAV_GROUP_ORDER: readonly NavGroup[] = ['main', 'school', 'communication', 'wellbeing', 'admin'];

/** Joriy yo'l uchun eng aniq mos keladigan marshrut (ruxsat tekshiruvi uchun). */
export function findRoute(path: string): RouteDef | undefined {
  const normalized = path.length > 1 && path.endsWith('/') ? path.slice(0, -1) : path;
  return ROUTES.filter((r) => !r.parent)
    .filter((r) => normalized === r.path || normalized.startsWith(`${r.path}/`))
    .sort((a, b) => b.path.length - a.path.length)[0];
}

/** Ikonkasiz qisqa nusxa (testlar uchun). */
export const ROUTE_PATHS = ROUTES.map((r) => r.path);

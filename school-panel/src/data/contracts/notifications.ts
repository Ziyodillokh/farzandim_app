import type { Localized } from './assessments';
import type { Id, IsoDateTime } from './common';
import type { RoleKey } from './people';

/** Saqlanadigan xodim bildirishnomalari (qolganlari jadvallardan hisoblanadi). */
export type StaffNotificationKind = 'SAFETY_SIGNAL' | 'TEST_COMPLETED';
export type StaffNotification = {
  id: Id;
  kind: StaffNotificationKind;
  at: IsoDateTime;
  roles: RoleKey[];
  /** null — butun maktab; aks holda shu sinflar doirasidagilarga. */
  classIds: Id[] | null;
  /** SAFETY_SIGNAL — bo'sh: ism, sinf yoki matn YO'Q. */
  params: Record<string, string | number>;
  subject: Localized | null;
  href: string | null;
};
export type NotificationKind =
  | StaffNotificationKind
  | 'EARLY_EXIT_PENDING'
  | 'VERIFICATION_OPEN'
  | 'CARE_NEW'
  | 'CARE_URGENT'
  | 'MESSAGE_SENT'
  | 'EMERGENCY';
export type NotificationTone = 'destructive' | 'warning' | 'info' | 'success';
export type NotificationItem = {
  id: string;
  kind: NotificationKind;
  at: IsoDateTime;
  tone: NotificationTone;
  params: Record<string, string | number>;
  subject: Localized | null;
  href: string | null;
};
export type OpenRequests = { earlyExits: number; verifications: number | null; total: number; href: string };

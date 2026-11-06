import type { Localized } from './assessments';
import type { Id, IsoDateTime } from './common';
import type { RoleKey } from './people';

/** Saqlanadigan xodim bildirishnomalari (qolganlari jadvallardan hisoblanadi). */
/**
 * DATA_DELETION_REQUEST — bola ma'lumotlarini o'chirishni so'radi (faqat direktor/admin).
 * Kirish (5-bosqich): CHILD_RECOVERY_REQUEST — bola parol tiklashni so'radi; LINK_REVIEW — bola maktab kodini kiritdi,
 * ulanishni tekshirish kerak; LINK_CORRECTION — bola maktab/sinf noto'g'ri deb bildirdi (sinf rahbari + admin).
 * Hammasida params: studentName, className.
 */
export type StaffNotificationKind =
  | 'SAFETY_SIGNAL'
  | 'TEST_COMPLETED'
  | 'DATA_DELETION_REQUEST'
  | 'CHILD_RECOVERY_REQUEST'
  | 'LINK_REVIEW'
  | 'LINK_CORRECTION';
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

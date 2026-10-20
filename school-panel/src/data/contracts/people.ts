import type { DeviceOs, Gender, Id, IsoDate, IsoDateTime } from './common';

export type ParentLinkStatus = 'NOT_INVITED' | 'INVITED' | 'LINKED';
export type GuardianRelation = 'MOTHER' | 'FATHER' | 'GRANDPARENT' | 'OTHER';

export type Guardian = {
  id: Id;
  fullName: string;
  phone: string; // "+998 90 123 45 67"
  relation: GuardianRelation;
  linkStatus: ParentLinkStatus;
  inviteCode: string | null;
  inviteExpiresAt: IsoDateTime | null;
  linkedAt: IsoDateTime | null;
};

export type Student = {
  id: Id;
  lastName: string;
  firstName: string;
  middleName: string; // "Akmal o'g'li"
  gender: Gender;
  birthDate: IsoDate;
  classId: Id;
  device: DeviceOs;
  guardianIds: Id[];
  /** Kiosk/QR uchun qisqa shaxsiy kod (masalan "P-4821"). */
  studentCode: string;
  enrolledAt: IsoDate;
  archived: boolean;
};

export type RoleKey = 'DIRECTOR' | 'ADMIN' | 'HOMEROOM' | 'PSYCHOLOGIST' | 'DUTY' | 'TEACHER';

export type Staff = {
  id: Id;
  fullName: string;
  position: string; // "Matematika o'qituvchisi"
  role: RoleKey;
  phone: string;
  email: string;
  classIds: Id[];
  username: string | null; // demo hisob bo'lsa
  active: boolean;
  /** Yuklangan rasm (data URL; haqiqiy backend'da — URL). Bo'lmasa portret ko'rsatiladi. */
  photo?: string | null;
  /** Chizilgan portret kaliti (`f-07`, `m-03`) — `public/avatars/`. */
  portrait?: string;
};

/** O'quvchi kartasidagi xodim eslatmasi (auditga matn yozilmaydi). */
export type StudentNote = { id: Id; studentId: Id; classId: Id; at: IsoDateTime; byStaffId: Id; text: string };

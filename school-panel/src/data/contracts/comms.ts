import type { Id, IsoDate, IsoDateTime } from './common';

export type AudienceKind = 'SCHOOL' | 'CLASSES' | 'GUARDIANS';
export type Audience = { kind: AudienceKind; classIds: Id[]; guardianIds: Id[] };
export type MessagePriority = 'NORMAL' | 'IMPORTANT';
export type MessageStatus = 'DRAFT' | 'SCHEDULED' | 'SENT';

export type Announcement = {
  id: Id;
  title: string;
  body: string;
  audience: Audience;
  priority: MessagePriority;
  status: MessageStatus;
  scheduledAt: IsoDateTime | null;
  sentAt: IsoDateTime | null;
  byStaffId: Id;
  stats: { recipients: number; delivered: number; read: number };
};

export type ReminderKind = 'MEETING' | 'EXAM' | 'EVENT' | 'HOLIDAY' | 'ANNOUNCEMENT' | 'SCHEDULE_CHANGE';
export type ReminderRepeat = 'NONE' | 'WEEKLY' | 'MONTHLY';

export type Reminder = {
  id: Id;
  kind: ReminderKind;
  title: string;
  body: string;
  audience: Audience;
  sendAt: IsoDateTime;
  repeat: ReminderRepeat;
  active: boolean;
  byStaffId: Id;
};

export type PaymentReminderEntry = {
  at: IsoDateTime;
  byStaffId: Id;
  action: 'CREATED' | 'SHIFTED' | 'PAUSED' | 'RESUMED' | 'BULK_SHIFT' | 'VERIFIED';
  note: string;
};

/** Platforma qarz hisoblamaydi — faqat maktab tasdiqlagan keyingi eslatma sanasi. */
export type PaymentReminder = {
  id: Id;
  guardianId: Id;
  studentIds: Id[];
  nextDate: IsoDate;
  /** Necha oy oldindan to'langan (maktab tizimi tasdiqlagan). */
  prepaidMonths: number;
  paused: boolean;
  history: PaymentReminderEntry[];
};

export type VerificationStatus = 'OPEN' | 'ANSWERED' | 'CLOSED';
export type VerificationRequest = {
  id: Id;
  guardianId: Id;
  paymentReminderId: Id;
  message: string;
  createdAt: IsoDateTime;
  status: VerificationStatus;
  answer: string | null;
  answeredByStaffId: Id | null;
  answeredAt: IsoDateTime | null;
};

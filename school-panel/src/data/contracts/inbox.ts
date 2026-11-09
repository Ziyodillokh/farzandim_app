import type { Id, IsoDateTime, Paginated } from './common';
import type { GuardianRelation } from './people';

/**
 * Ota-onalar xabarlari (Parvoz Parents → "Maktab bilan bog'lanish"). Xodim FAQAT o'ziga yozilgan
 * yozishmalarni ko'radi — direktor ham boshqalarnikini ko'rmaydi (backend `staff-threads.service.ts`).
 */
export const PARENT_TOPICS = [
  'ABSENCE',
  'EARLY_PICKUP',
  'HOMEWORK',
  'PROGRESS',
  'MEETING',
  'BEHAVIOR',
  'WELLBEING',
  'BULLYING',
  'ADVICE',
  'PAYMENT',
  'DOCUMENT',
  'SUGGESTION',
  'PROBLEM',
  'THANKS',
  'EXTRA_LESSON',
  'OTHER',
] as const;
export type ParentTopic = (typeof PARENT_TOPICS)[number];

export type ParentThreadStatus = 'OPEN' | 'RESOLVED';
export type ParentAuthor = 'PARENT' | 'STAFF';

export type ParentMessage = {
  id: Id;
  author: ParentAuthor;
  topic: ParentTopic | null;
  body: string;
  createdAt: IsoDateTime;
  /** Qarshi tomon o'qiganmi. */
  seen: boolean;
};

export type ParentThreadBase = {
  id: Id;
  status: ParentThreadStatus;
  guardian: { id: Id; fullName: string; relation: GuardianRelation };
  student: { id: Id; name: string; className: string };
  lastAuthor: ParentAuthor;
  lastMessageAt: IsoDateTime;
  /** Xodim o'qimagan ota-ona xabarlari. */
  unread: number;
  createdAt: IsoDateTime;
};

export type ParentThreadRow = ParentThreadBase & {
  preview: { author: ParentAuthor; text: string; at: IsoDateTime } | null;
};

export type ParentThreadDetail = ParentThreadBase & {
  parentReadAt: IsoDateTime | null;
  messages: ParentMessage[];
};

export type InboxCounts = { unread: number; open: number };
export type InboxStatusFilter = ParentThreadStatus | 'ALL';
export type InboxFilter = { status: InboxStatusFilter; search?: string };
export type InboxPage = Paginated<ParentThreadRow> & { counts: InboxCounts };

/** Javob uzunligi (backend `STAFF_REPLY_MAX`). */
export const PARENT_REPLY_MAX = 2000;

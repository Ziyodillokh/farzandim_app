import type { Announcement, Paginated, PaymentReminder, Reminder, VerificationRequest } from '@/data/contracts';
import type {
  AnnouncementDetail,
  AnnouncementList,
  AudienceReach,
  CommsOverview,
  commsService,
  MessageTemplate,
  PaymentHistoryEntry,
  PaymentRow,
  PaymentStats,
  ReminderList,
  VerificationList,
} from '@/data/mock/services/comms';
import { http } from '../client';

/**
 * Xabarlar (`/school/comms/*`): e'lonlar, Smart Reminder, to'lov eslatmalari,
 * tekshiruv so'rovlari. Yetkazildi / o'qildi — haqiqiy push natijalari;
 * rejalashtirilganlarni backend cron'i yuboradi.
 */
type Comms = typeof commsService;
const id = (v: string) => encodeURIComponent(v);
const BASE = '/school/comms';

const announcements: Comms['announcements'] = {
  list: (filter = {}) => http<AnnouncementList>('GET', `${BASE}/announcements`, { query: filter }),
  get: (announcementId) => http<AnnouncementDetail>('GET', `${BASE}/announcements/${id(announcementId)}`),
  saveDraft: (input, announcementId) =>
    announcementId
      ? http<Announcement>('PUT', `${BASE}/announcements/${id(announcementId)}/draft`, { body: input })
      : http<Announcement>('POST', `${BASE}/announcements/drafts`, { body: input }),
  send: (input, options = {}) =>
    http<Announcement>('POST', options.id ? `${BASE}/announcements/${id(options.id)}/send` : `${BASE}/announcements/send`, {
      body: { ...input, scheduledAt: options.scheduledAt ?? null },
    }),
  sendNow: (announcementId) => http<Announcement>('POST', `${BASE}/announcements/${id(announcementId)}/send-now`),
  remove: (announcementId) => http<void>('DELETE', `${BASE}/announcements/${id(announcementId)}`),
  duplicate: (announcementId) => http<Announcement>('POST', `${BASE}/announcements/${id(announcementId)}/duplicate`),
};

const reminders: Comms['reminders'] = {
  list: (filter = {}) => http<ReminderList>('GET', `${BASE}/reminders`, { query: filter }),
  create: (input) => http<Reminder>('POST', `${BASE}/reminders`, { body: input }),
  update: (reminderId, input) => http<Reminder>('PUT', `${BASE}/reminders/${id(reminderId)}`, { body: input }),
  remove: (reminderId) => http<void>('DELETE', `${BASE}/reminders/${id(reminderId)}`),
  setActive: (reminderId, active) => http<Reminder>('PATCH', `${BASE}/reminders/${id(reminderId)}/active`, { body: { active } }),
};

const payments: Comms['payments'] = {
  list: (filter = {}) => http<Paginated<PaymentRow>>('GET', `${BASE}/payments`, { query: filter }),
  stats: () => http<PaymentStats>('GET', `${BASE}/payments/stats`),
  exportRows: (filter = {}) => http<PaymentRow[]>('GET', `${BASE}/payments/export`, { query: filter }),
  shift: (paymentId, input) => http<PaymentReminder>('POST', `${BASE}/payments/${id(paymentId)}/shift`, { body: input }),
  pause: (paymentId, input) => http<PaymentReminder>('POST', `${BASE}/payments/${id(paymentId)}/pause`, { body: input }),
  resume: (paymentId, input) => http<PaymentReminder>('POST', `${BASE}/payments/${id(paymentId)}/resume`, { body: input }),
  bulkShift: (input) => http<{ updated: number }>('POST', `${BASE}/payments/bulk-shift`, { body: input }),
  history: (paymentId) => http<PaymentHistoryEntry[]>('GET', `${BASE}/payments/${id(paymentId)}/history`),
};

const verifications: Comms['verifications'] = {
  list: (filter = {}) => http<VerificationList>('GET', `${BASE}/verifications`, { query: filter }),
  answer: (verificationId, input) =>
    http<VerificationRequest>('POST', `${BASE}/verifications/${id(verificationId)}/answer`, { body: input }),
  close: (verificationId) => http<VerificationRequest>('POST', `${BASE}/verifications/${id(verificationId)}/close`),
};

export const commsHttp: Comms = {
  announcements,
  reminders,
  payments,
  verifications,
  audienceSize: (input) => http<AudienceReach>('POST', `${BASE}/audience-size`, { body: input }),
  templates: () => http<readonly MessageTemplate[]>('GET', `${BASE}/templates`),
  overview: (limit = 3) => http<CommsOverview>('GET', `${BASE}/overview`, { query: { limit } }),
};

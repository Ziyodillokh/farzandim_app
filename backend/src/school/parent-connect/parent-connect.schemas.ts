// Ota-ona ↔ xodim yozishmasi: kiruvchi ma'lumot sxemalari va chegaralar.
// Shablon matnlari ilovada (uz / ru / en); server faqat mavzu kalitini tekshiradi.

import { z } from 'zod';
import { msg } from '../common/school-zod';

/** Ota-ona shablon mavzulari (ilova `ContactTopic` bilan bir xil). */
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

export const THREAD_STATUSES = ['OPEN', 'RESOLVED'] as const;
export type ThreadStatus = (typeof THREAD_STATUSES)[number];

/** Ota-ona xabari va xodim javobi uzunligi. */
export const PARENT_MESSAGE_MAX = 1000;
export const STAFF_REPLY_MAX = 2000;

/** Bir kunda (so'nggi 24 soat) ota-onaning yangi yozishmalari va xabarlari chegarasi. */
export const PARENT_NEW_THREADS_PER_DAY = 5;
export const PARENT_MESSAGES_PER_DAY = 30;

/** Yozishmada qaytariladigan eng ko'p xabar (eng yangilari). */
export const THREAD_MESSAGES_LIMIT = 200;

const idSchema = z.string({ error: msg.required }).trim().min(1, msg.required).max(64, msg.tooLong);

const bodySchema = (max: number) =>
  z
    .string({ error: msg.required })
    .transform((v) => v.replace(/\r\n/g, '\n').trim())
    .pipe(z.string().min(1, msg.required).max(max, msg.tooLong));

const clientMessageIdSchema = z.string().trim().min(8).max(64).optional();

export const contactsQuerySchema = z.object({ studentId: idSchema });

export const parentStartSchema = z.object({
  staffId: idSchema,
  studentId: idSchema,
  topic: z.enum(PARENT_TOPICS).default('OTHER'),
  body: bodySchema(PARENT_MESSAGE_MAX),
  clientMessageId: clientMessageIdSchema,
});

export const parentMessageSchema = z.object({
  topic: z.enum(PARENT_TOPICS).optional(),
  body: bodySchema(PARENT_MESSAGE_MAX),
  clientMessageId: clientMessageIdSchema,
});

export const staffReplySchema = z.object({
  body: bodySchema(STAFF_REPLY_MAX),
  clientMessageId: clientMessageIdSchema,
});

export const staffStatusSchema = z.object({ status: z.enum(THREAD_STATUSES) });

export const staffListQuerySchema = z.object({
  status: z.enum(['OPEN', 'RESOLVED', 'ALL']).default('OPEN'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(30),
  search: z.string().trim().max(100).optional(),
});

export type StaffListQuery = z.output<typeof staffListQuerySchema>;

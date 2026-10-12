import { z } from 'zod';
import { isoDateSchema, msg, requiredText } from './common';

export const schoolProfileSchema = z.object({
  name: requiredText(100),
  shortName: requiredText(12),
  city: requiredText(40),
  address: z.string().trim().max(120, msg.tooLong).default(''),
  phone: z.string().trim().max(24, msg.tooLong).default(''),
  academicYear: requiredText(12),
  lateAfterMinutes: z.coerce.number().int().min(0).max(60),
});

export const holidayInputSchema = z.object({ date: isoDateSchema, name: requiredText(60) });

export type SchoolProfileInput = z.input<typeof schoolProfileSchema>;
export type HolidayInput = z.input<typeof holidayInputSchema>;

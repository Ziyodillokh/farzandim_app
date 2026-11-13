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

/** Maktab hududi radiusi (m): GPS bino ichida 20–50 m adashadi — kichikroq hudud ishonchsiz. */
export const ZONE_RADIUS_MIN_M = 50;
export const ZONE_RADIUS_MAX_M = 1000;
export const ZONE_RADIUS_DEFAULT_M = 100;

/** Maktab hududi (backend bilan bir xil). */
export const schoolZoneSchema = z.object({
  latitude: z.coerce.number({ invalid_type_error: msg.coordinates }).min(-90, msg.coordinates).max(90, msg.coordinates),
  longitude: z.coerce.number({ invalid_type_error: msg.coordinates }).min(-180, msg.coordinates).max(180, msg.coordinates),
  radiusM: z.coerce
    .number({ invalid_type_error: msg.radius })
    .int(msg.radius)
    .min(ZONE_RADIUS_MIN_M, msg.radius)
    .max(ZONE_RADIUS_MAX_M, msg.radius),
});

export type SchoolProfileInput = z.input<typeof schoolProfileSchema>;
export type HolidayInput = z.input<typeof holidayInputSchema>;
export type SchoolZoneInput = z.input<typeof schoolZoneSchema>;

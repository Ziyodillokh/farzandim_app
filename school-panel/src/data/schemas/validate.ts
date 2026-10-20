import type { z } from 'zod';
import { ServiceError } from '@/data/contracts';

/** Servisda kiruvchi ma'lumotni tekshirish — xato bo'lsa VALIDATION. */
export function parseOrThrow<S extends z.ZodTypeAny>(schema: S, input: unknown): z.output<S> {
  const result = schema.safeParse(input);
  if (!result.success) {
    const first = result.error.issues[0];
    throw new ServiceError('VALIDATION', first ? `${first.path.join('.')}: ${first.message}` : 'invalid');
  }
  return result.data;
}

import { z } from 'zod';

export const PLAN_REQUIRED = ['free', 'basic', 'standard', 'premium'] as const;
export const CONTENT_STATUSES = ['pending', 'approved', 'rejected', 'hidden'] as const;
export const VIDEO_LEVELS = ['beginner', 'intermediate', 'advanced'] as const;
export const CONTENT_KINDS = ['video', 'audiobook', 'book'] as const;

export const PaginationQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(10),
});

export const BulkActionBody = z.object({
  ids: z.array(z.string().uuid()).min(1).max(500),
  action: z.enum(['approve', 'reject', 'delete', 'hide', 'feature', 'unfeature']),
});

export function paginated<T>(items: T[], page: number, limit: number, total: number) {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  return {
    items,
    pagination: { page, totalPages, total, limit },
  };
}

import type { KelajakListParams } from '@/lib/api/admin.api';

/** TanStack Query kalitlari — `all` bilan hammasini birga yangilash mumkin. */
export const kelajakKeys = {
  all: ['kelajak'] as const,
  lists: ['kelajak', 'questions'] as const,
  list: (params: KelajakListParams) => ['kelajak', 'questions', params] as const,
  detail: (id: string) => ['kelajak', 'question', id] as const,
  stats: ['kelajak', 'stats'] as const,
};

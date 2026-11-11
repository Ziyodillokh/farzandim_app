import type { SchoolListParams } from '@/lib/api/admin.api';

export const schoolsKeys = {
  all: ['admin-schools'] as const,
  list: (params: SchoolListParams) => ['admin-schools', 'list', params] as const,
  detail: (id: string) => ['admin-schools', 'detail', id] as const,
};

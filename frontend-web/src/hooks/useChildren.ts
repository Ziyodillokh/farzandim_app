'use client';

import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api/client';
import type { Child } from '@/types/api.types';

/**
 * Hook: parent'ning bolalari ro'yxati.
 * Backend: GET /api/children
 */
export function useChildren() {
  return useQuery({
    queryKey: ['children'],
    queryFn: async () => {
      try {
        const r = await api.get<{ children: Child[] }>('/children');
        return r.children;
      } catch {
        // Auth bo'lmasa yoki backend yo'q bo'lsa — bo'sh ro'yxat (empty state ko'rsatamiz)
        return [] as Child[];
      }
    },
    retry: false,
  });
}

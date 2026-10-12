'use client';

import { useQuery } from '@tanstack/react-query';

import { api } from '@/data/api';

export const schoolKeys = { all: ['school'] as const };

/** Maktab profili, smenalar va bayramlar (sarlavha, logo, jadval). */
export function useSchool() {
  return useQuery({ queryKey: schoolKeys.all, queryFn: () => api.school.get(), staleTime: 60_000 });
}

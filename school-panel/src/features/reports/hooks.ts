'use client';

import { useQuery } from '@tanstack/react-query';

import { api } from '@/data/api';

export function useMonthlyReport(month: string | null) {
  return useQuery({
    queryKey: ['reports', 'monthly', month],
    queryFn: () => api.reports.monthly(month ?? ''),
    enabled: Boolean(month),
  });
}

'use client';

import { useQuery } from '@tanstack/react-query';

import { useCan } from '@/auth/use-session';
import { api } from '@/data/api';

export const dashboardKeys = {
  overview: ['dashboard', 'overview'] as const,
  trend: ['dashboard', 'trend'] as const,
  feed: ['dashboard', 'feed'] as const,
};

export function useOverview() {
  return useQuery({ queryKey: dashboardKeys.overview, queryFn: () => api.dashboard.overview() });
}

export function useAttendanceTrend() {
  const can = useCan();
  return useQuery({ queryKey: dashboardKeys.trend, queryFn: () => api.attendance.trend(14), enabled: can('attendance.history') });
}

export function useLiveFeed() {
  const can = useCan();
  return useQuery({ queryKey: dashboardKeys.feed, queryFn: () => api.attendance.feed({ limit: 8 }), enabled: can('attendance.view') });
}

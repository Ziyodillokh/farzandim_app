'use client';

import { keepPreviousData, useQuery } from '@tanstack/react-query';

import { useSession } from '@/auth/use-session';
import { api } from '@/data/api';
import type { MetricKey, Scope } from '@/data/contracts';
import { useFilters } from './store';

/** Foydalanuvchi doirasi: viloyat roli — o'z hududi, respublika — butun mamlakat. */
export function useUserScope(): Scope {
  const session = useSession();
  if (session?.role === 'REGIONAL' && session.regionId) return { kind: 'REGION', regionId: session.regionId };
  return { kind: 'NATIONAL' };
}

const scopeKey = (scope: Scope) => (scope.kind === 'NATIONAL' ? 'UZ' : scope.regionId);

export function useOverview(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['overview', scopeKey(scope), f], queryFn: () => api.overview(scope, f), placeholderData: keepPreviousData });
}

export function useAreaMetric(metric: MetricKey, scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['area-metric', metric, scopeKey(scope), f], queryFn: () => api.areaMetric(metric, scope, f), placeholderData: keepPreviousData });
}

export function useRegionsTable() {
  const [f] = useFilters();
  return useQuery({ queryKey: ['regions-table', f], queryFn: () => api.regionsTable(f), placeholderData: keepPreviousData });
}

/** Bo'linmalar × ko'rsatkichlar (hududlar yoki tumanlar jadvali). */
export function useAreaMatrix(metrics: readonly MetricKey[], scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['area-matrix', metrics.join(','), scopeKey(scope), f], queryFn: () => api.areaMatrix(metrics, scope, f), placeholderData: keepPreviousData });
}

export function useMastery(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['mastery', scopeKey(scope), f], queryFn: () => api.mastery(scope, f), placeholderData: keepPreviousData });
}

export function useIq(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['iq', scopeKey(scope), f], queryFn: () => api.iq(scope, f), placeholderData: keepPreviousData });
}

export function useInterests(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['interests', scopeKey(scope), f], queryFn: () => api.interests(scope, f), placeholderData: keepPreviousData });
}

export function useWellbeing(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['wellbeing', scopeKey(scope), f], queryFn: () => api.wellbeing(scope, f), placeholderData: keepPreviousData });
}

export function useAttendance(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['attendance', scopeKey(scope), f], queryFn: () => api.attendance(scope, f), placeholderData: keepPreviousData });
}

export function useDigital(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['digital', scopeKey(scope), f], queryFn: () => api.digital(scope, f), placeholderData: keepPreviousData });
}

export function useSchools(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['schools', scopeKey(scope), f], queryFn: () => api.schools(scope, f), placeholderData: keepPreviousData });
}

export function useInsights(scope: Scope) {
  const [f] = useFilters();
  return useQuery({ queryKey: ['insights', scopeKey(scope), f], queryFn: () => api.insights(scope, f), placeholderData: keepPreviousData });
}

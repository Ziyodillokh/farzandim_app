'use client';

import { keepPreviousData, useQuery } from '@tanstack/react-query';

import { api } from '@/data/api';
import type { AuditFilter } from '@/data/mock/services/staff';

export const auditKeys = {
  list: (filter: AuditFilter) => ['audit', 'list', filter] as const,
  actors: ['audit', 'actors'] as const,
};

export function useAuditLog(filter: AuditFilter) {
  return useQuery({ queryKey: auditKeys.list(filter), queryFn: () => api.audit.list(filter), placeholderData: keepPreviousData });
}

export function useAuditActors() {
  return useQuery({ queryKey: auditKeys.actors, queryFn: () => api.audit.actors(), staleTime: 60_000 });
}

'use client';

import { useCallback } from 'react';

import type { MetricKey, RegionRow, Scope, Stat } from '@/data/contracts';
import { REGION_TABLE_METRICS } from '@/data/mock/services/overview';
import { useAreaMatrix, useRegionsTable } from '@/features/filters/use-monitoring';

export const NATIONAL_SCOPE: Scope = { kind: 'NATIONAL' };

export type NationalStats = Partial<Record<MetricKey, Stat>>;

/**
 * 14 hudud × asosiy ko'rsatkichlar (jadval) va respublika qiymatlari
 * (o'sha ko'rsatkichlar, taqqoslash markazi). Ikkala so'rov react-query keshida.
 */
export function useRegionsData(): {
  rows: RegionRow[] | undefined;
  national: NationalStats | undefined;
  error: unknown;
  retry: () => void;
} {
  const table = useRegionsTable();
  const matrix = useAreaMatrix(REGION_TABLE_METRICS, NATIONAL_SCOPE);
  const { refetch: refetchTable } = table;
  const { refetch: refetchMatrix } = matrix;
  const retry = useCallback(() => {
    void refetchTable();
    void refetchMatrix();
  }, [refetchTable, refetchMatrix]);
  return { rows: table.data, national: matrix.data?.scope, error: table.error ?? matrix.error, retry };
}

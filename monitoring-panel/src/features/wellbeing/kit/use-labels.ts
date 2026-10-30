'use client';

import { useCallback } from 'react';

import type { MetricKey, Scope } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';
import type { GradeExtreme } from './analysis';

/** Sinf oralig'i matni: "7-sinf" yoki "6–8-sinflar". */
export function useGradeLabel() {
  const { t } = useI18n();
  return useCallback(
    (g: Pick<GradeExtreme, 'from' | 'to'>) => (g.from === g.to ? t('common.grade', { grade: g.from }) : t('wellbeing.kit.gradeRange', { from: g.from, to: g.to })),
    [t],
  );
}

/** Doira nomi legenda uchun: respublika yoki hudud qisqa nomi. */
export function useScopeLabel(scope: Scope): string {
  const { t } = useI18n();
  const areaName = useAreaName();
  return scope.kind === 'NATIONAL' ? t('common.national') : areaName(scope.regionId, { short: true });
}

/** Ikki guruh orasidagi farq (ishorasiz): ulushlarda — "2,5 p.p.", boshqalarda — ko'rsatkich birligida. */
export function useGapFormat() {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return useCallback(
    (metric: MetricKey | 'share', diff: number) => {
      const abs = Math.abs(diff);
      if (metric === 'share' || METRICS[metric].unit === '%') return `${fmt.num(abs, 1)} ${t('common.units.pp')}`;
      return fmt.value(metric, abs);
    },
    [fmt, t],
  );
}

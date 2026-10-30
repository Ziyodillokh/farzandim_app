'use client';

import type { MetricKey, Scope, SeriesPoint } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { metricScale } from './analysis';
import { ChartLegend } from './chart-block';
import { trimZeroDecimals } from './mini-columns';
import { type TrendLine, TrendArea } from './trend-area';
import { useScopeLabel } from './use-labels';

const SCOPE_COLOR = 'hsl(var(--chart-1))';
const NATIONAL_COLOR = 'hsl(220 20% 65%)';

/**
 * Oylik trend: hudud doirasida respublika qatori (shtrix) bilan taqqoslanadi.
 * Ikki qator bo'lsa — legenda (rang yagona belgi emas). O'qda qisqa belgilar
 * (daqiqa birligi — o'q ustida), foiz o'qi 100% dan oshmaydi; tooltipda — to'liq qiymat.
 */
export function ComparedTrend({
  scope,
  metric,
  points,
  nationalPoints,
  height = 220,
  minSpan = 0,
}: {
  scope: Scope;
  metric: MetricKey;
  points: SeriesPoint[];
  nationalPoints?: SeriesPoint[];
  height?: number;
  /** Y o'qining eng kichik oralig'i (kichik o'zgarish bo'rttirilmasin). */
  minSpan?: number;
}) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const scopeLabel = useScopeLabel(scope);
  const def = METRICS[metric];
  const national = scope.kind === 'REGION' && nationalPoints && nationalPoints.length === points.length ? nationalPoints : null;
  const lines: TrendLine[] = [
    { key: 'scope', label: scopeLabel, points, color: SCOPE_COLOR },
    ...(national ? [{ key: 'national', label: t('common.national'), points: national, color: NATIONAL_COLOR, dashed: true }] : []),
  ];
  const scale = metricScale(metric, [...points, ...(national ?? [])].map((p) => p.value), { minSpan });
  const minutes = def.unit === 'min';
  const axisFormat = (v: number) => (minutes ? fmt.num(v, 0) : trimZeroDecimals(fmt.value(metric, v)));
  return (
    <div className="min-w-0">
      {national && (
        <ChartLegend
          className="mb-2"
          items={[
            { key: 'scope', label: scopeLabel, color: SCOPE_COLOR, shape: 'line' },
            { key: 'national', label: t('common.national'), color: NATIONAL_COLOR, shape: 'dash' },
          ]}
        />
      )}
      <TrendArea
        lines={lines}
        format={(v) => fmt.value(metric, v)}
        axisFormat={axisFormat}
        scale={scale}
        unit={minutes ? t('common.units.min') : undefined}
        height={height}
      />
    </div>
  );
}

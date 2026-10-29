'use client';

import { Table2 } from 'lucide-react';

import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import type { MetricKey, Scope } from '@/data/contracts';
import { useAreaMatrix } from '@/features/filters/use-monitoring';
import { useI18n } from '@/i18n';
import { AreaTable, useAreaCsv } from './area-table';

/**
 * Hududlar (yoki tumanlar) jadvali bo'limi: saralanadigan jadval va CSV eksport.
 * Davomat va raqamli odatlar sahifalari foydalanadi.
 */
export function AreaTableSection({
  id,
  scope,
  metrics,
  title,
  csvFile,
}: {
  id: string;
  scope: Scope;
  metrics: readonly MetricKey[];
  title: string;
  csvFile: string;
}) {
  const { t } = useI18n();
  const matrix = useAreaMatrix(metrics, scope);
  const downloadCsv = useAreaCsv(scope, metrics);
  const data = matrix.data;
  return (
    <Section
      id={id}
      className="scroll-mt-32"
      icon={<Table2 />}
      title={title}
      subtitle={t('wellbeing.kit.tableHint')}
      actions={<ExportMenu disabled={!data} onCsv={data ? () => downloadCsv(csvFile, data.rows) : undefined} />}
      bodyClassName="p-0 sm:p-5"
    >
      {matrix.isError ? <ErrorState error={matrix.error} onRetry={() => void matrix.refetch()} /> : <AreaTable scope={scope} metrics={metrics} data={data} loading={matrix.isLoading} />}
    </Section>
  );
}

'use client';

import { PageHeader } from '@/components/common/page-header';
import { ScopeSelect } from '@/features/filters/scope-select';
import { ReportsView } from '@/features/reports/reports-view';
import { useI18n } from '@/i18n';

export default function ReportsPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t('reports.title')} subtitle={t('reports.subtitle')} actions={<ScopeSelect />} />
      <ReportsView />
    </>
  );
}

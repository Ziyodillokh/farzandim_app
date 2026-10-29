'use client';

import { PageHeader } from '@/components/common/page-header';
import { useI18n } from '@/i18n';

/** Vaqtinchalik karkas — sahifa tayyorlanmoqda. */
export default function ReportsPrintPage() {
  const { t } = useI18n();
  return <PageHeader title={t('reports.title')} subtitle={t('reports.subtitle')} />;
}

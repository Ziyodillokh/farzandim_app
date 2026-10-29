'use client';

import { PageHeader } from '@/components/common/page-header';
import { useI18n } from '@/i18n';

/** Vaqtinchalik karkas — sahifa tayyorlanmoqda. */
export default function MethodologyPage() {
  const { t } = useI18n();
  return <PageHeader title={t('methodology.title')} subtitle={t('methodology.subtitle')} />;
}

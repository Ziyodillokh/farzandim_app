'use client';

import { PageHeader } from '@/components/common/page-header';
import { useI18n } from '@/i18n';

/** Vaqtinchalik karkas — sahifa tayyorlanmoqda. */
export default function DigitalPage() {
  const { t } = useI18n();
  return <PageHeader title={t('digital.title')} subtitle={t('digital.subtitle')} />;
}

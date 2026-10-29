'use client';

import { PageHeader } from '@/components/common/page-header';
import { MethodologyView } from '@/features/methodology/methodology-view';
import { useI18n } from '@/i18n';

export default function MethodologyPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t('methodology.title')} subtitle={t('methodology.subtitle')} />
      <MethodologyView />
    </>
  );
}

'use client';

import { PageHeader } from '@/components/common/page-header';
import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import { useI18n } from '@/i18n';

export default function Page() {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t('assessments.title')} subtitle={t('assessments.subtitle')} />
      <ScreeningDisclaimer variant="banner" withIq />
    </>
  );
}

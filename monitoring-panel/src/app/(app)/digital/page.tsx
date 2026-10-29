'use client';

import { PageHeader } from '@/components/common/page-header';
import { DigitalView } from '@/features/digital/digital-view';
import { ScopeSelect, usePageScope } from '@/features/filters/scope-select';
import { useI18n } from '@/i18n';

/** Raqamli odatlar: faqat ota-ona roziligi bilan ulangan qurilmalardan, faqat umumlashgan. */
export default function DigitalPage() {
  const { t } = useI18n();
  const scope = usePageScope();
  return (
    <>
      <PageHeader title={t('digital.title')} subtitle={t('digital.subtitle')} actions={<ScopeSelect />} />
      <DigitalView scope={scope} />
    </>
  );
}

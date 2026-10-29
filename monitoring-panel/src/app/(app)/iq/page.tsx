'use client';

import { PageHeader } from '@/components/common/page-header';
import { ScopeSelect, usePageScope } from '@/features/filters/scope-select';
import { IqView } from '@/features/iq/iq-view';
import { useI18n } from '@/i18n';

/** IQ va tafakkur: Parvoz IQ skriningi — darajalar, yo'nalishlar va qamrov (faqat umumlashgan). */
export default function IqPage() {
  const { t } = useI18n();
  const scope = usePageScope();
  return (
    <>
      <PageHeader title={t('iq.title')} subtitle={t('iq.subtitle')} actions={<ScopeSelect />} />
      <IqView scope={scope} />
    </>
  );
}

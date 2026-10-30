'use client';

import { PageHeader } from '@/components/common/page-header';
import { ScopeSelect, usePageScope } from '@/features/filters/scope-select';
import { InterestsView } from '@/features/interests/interests-view';
import { useI18n } from '@/i18n';

/** Qiziqishlar: tanlangan fanlar, umumiy va kasbiy qiziqishlar, kasbga tayyorgarlik. */
export default function InterestsPage() {
  const { t } = useI18n();
  const scope = usePageScope();
  return (
    <>
      <PageHeader title={t('interests.title')} subtitle={t('interests.subtitle')} actions={<ScopeSelect />} />
      <InterestsView scope={scope} />
    </>
  );
}

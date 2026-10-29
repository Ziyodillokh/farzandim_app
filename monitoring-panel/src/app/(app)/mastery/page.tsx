'use client';

import { PageHeader } from '@/components/common/page-header';
import { ScopeSelect, usePageScope } from '@/features/filters/scope-select';
import { MasteryView } from '@/features/mastery/mastery-view';
import { useI18n } from '@/i18n';

/** O'zlashtirish: fanlar, sinflar va hududlar (yoki tumanlar) kesimida natijalar. */
export default function MasteryPage() {
  const { t } = useI18n();
  const scope = usePageScope();
  return (
    <>
      <PageHeader title={t('mastery.title')} subtitle={t('mastery.subtitle')} actions={<ScopeSelect />} />
      <MasteryView scope={scope} />
    </>
  );
}

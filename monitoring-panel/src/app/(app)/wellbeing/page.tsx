'use client';

import { PageHeader } from '@/components/common/page-header';
import { ScopeSelect, usePageScope } from '@/features/filters/scope-select';
import { WellbeingView } from '@/features/wellbeing/wellbeing-view';
import { useI18n } from '@/i18n';

/** Farovonlik va muammolar: bolalar o'rtasidagi signallar hududlar kesimida (skrining, tashxis emas). */
export default function WellbeingPage() {
  const { t } = useI18n();
  const scope = usePageScope();
  return (
    <>
      <PageHeader title={t('wellbeing.title')} subtitle={t('wellbeing.subtitle')} actions={<ScopeSelect />} />
      <WellbeingView scope={scope} />
    </>
  );
}

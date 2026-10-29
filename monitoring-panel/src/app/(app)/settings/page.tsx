'use client';

import { PageHeader } from '@/components/common/page-header';
import { SettingsView } from '@/features/settings/settings-view';
import { useI18n } from '@/i18n';

export default function SettingsPage() {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t('settings.title')} subtitle={t('settings.subtitle')} badge={null} />
      <SettingsView />
    </>
  );
}

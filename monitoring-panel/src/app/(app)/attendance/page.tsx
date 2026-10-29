'use client';

import { PageHeader } from '@/components/common/page-header';
import { useI18n } from '@/i18n';

/** Vaqtinchalik karkas — sahifa tayyorlanmoqda. */
export default function AttendancePage() {
  const { t } = useI18n();
  return <PageHeader title={t('attendance.title')} subtitle={t('attendance.subtitle')} />;
}

'use client';

import { PageHeader } from '@/components/common/page-header';
import { AttendanceView } from '@/features/attendance/attendance-view';
import { ScopeSelect, usePageScope } from '@/features/filters/scope-select';
import { useI18n } from '@/i18n';

/** Davomat: kelish, kechikish, surunkali kelmaslik — hududlar yoki tumanlar kesimida. */
export default function AttendancePage() {
  const { t } = useI18n();
  const scope = usePageScope();
  return (
    <>
      <PageHeader title={t('attendance.title')} subtitle={t('attendance.subtitle')} actions={<ScopeSelect />} />
      <AttendanceView scope={scope} />
    </>
  );
}

'use client';

import { Info } from 'lucide-react';

import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Skeleton } from '@/components/ui/skeleton';
import { useCan } from '@/auth/use-session';
import type { SchoolModePolicy } from '@/data/contracts';
import { AllowedApps } from '@/features/school-mode/components/allowed-apps';
import { PlatformExplainer } from '@/features/school-mode/components/platform-explainer';
import { CategorySettings, GeneralSettings } from '@/features/school-mode/components/policy-settings';
import { SafetyCallout } from '@/features/school-mode/components/safety-callout';
import { useSmPolicy, useSmShifts, useUpdatePolicy } from '@/features/school-mode/hooks';
import { useI18n } from '@/i18n';

export default function SchoolModePoliciesPage() {
  const { t } = useI18n();
  const can = useCan();
  const canManage = can('schoolMode.manage');
  const policy = useSmPolicy();
  const shifts = useSmShifts();
  const update = useUpdatePolicy();

  const header = <PageHeader title={t('schoolMode.policies.title')} subtitle={t('schoolMode.policies.subtitle')} />;

  if (policy.isError) {
    return (
      <>
        {header}
        <ErrorState error={policy.error} onRetry={() => void policy.refetch()} />
      </>
    );
  }

  if (policy.isLoading || !policy.data) {
    return (
      <>
        {header}
        <div className="grid gap-6 xl:grid-cols-2">
          <Skeleton className="h-64 rounded-xl" />
          <Skeleton className="h-64 rounded-xl" />
        </div>
      </>
    );
  }

  // O'zgarish yuborilayotganda — yangi qiymat darhol ko'rinadi.
  const pending = update.isPending ? update.variables : undefined;
  const view: SchoolModePolicy = {
    ...policy.data,
    enabled: pending?.enabled ?? policy.data.enabled,
    relaxDuringBreaks: pending?.relaxDuringBreaks ?? policy.data.relaxDuringBreaks,
    blockedCategories: pending?.blockedCategories ?? policy.data.blockedCategories,
    shiftIds: pending?.shiftIds ?? policy.data.shiftIds,
  };
  const onChange = (patch: Parameters<typeof update.mutate>[0]) => update.mutate(patch);

  return (
    <>
      {header}
      {!canManage && (
        <div className="mb-4 flex items-center gap-2 rounded-xl border bg-muted/40 px-4 py-3 text-sm text-muted-foreground">
          <Info className="h-4 w-4 shrink-0" aria-hidden />
          {t('schoolMode.policies.readOnly')}
        </div>
      )}
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.4fr)]">
        <div className="space-y-6">
          <GeneralSettings policy={view} shifts={shifts.data ?? []} canManage={canManage} onChange={onChange} />
          <PlatformExplainer />
        </div>
        <div className="space-y-6">
          <CategorySettings policy={view} canManage={canManage} onChange={onChange} />
          <AllowedApps apps={view.allowedApps} canManage={canManage} />
        </div>
      </div>
      <SafetyCallout className="mt-6" />
    </>
  );
}

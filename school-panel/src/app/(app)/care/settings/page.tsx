'use client';

import { useCan } from '@/auth/use-session';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Skeleton } from '@/components/ui/skeleton';
import { CareSettingsForm } from '@/features/care/components/settings-form';
import { useCareSettings } from '@/features/care/hooks';
import { useI18n } from '@/i18n';

/** Bola ovozi sozlamalari: tahrirlash — psixolog yoki `staff.manage` (direktor); qolganlar faqat ko'radi. */
export default function CareSettingsPage() {
  const { t, formatDate } = useI18n();
  const can = useCan();
  const query = useCareSettings();
  const settings = query.data;
  const canEdit = can('care.individual') || can('staff.manage');

  return (
    <>
      <PageHeader title={t('care.settings.title')} subtitle={t('care.settings.subtitle')} backHref="/care" backLabel={t('care.title')} />
      {query.isError ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : !settings ? (
        <div className="grid gap-6 xl:grid-cols-3">
          <Skeleton className="h-72 rounded-2xl xl:col-span-2" />
          <Skeleton className="h-48 rounded-2xl" />
        </div>
      ) : (
        <div className="animate-fade-in space-y-4">
          {!canEdit && (
            <p role="note" className="rounded-xl bg-info/10 px-4 py-2.5 text-sm text-info ring-1 ring-inset ring-info/20">
              {t('care.settings.readOnly')}
            </p>
          )}
          <p className="text-xs text-muted-foreground">
            {settings.updatedAt
              ? t('care.settings.lastUpdated', { date: formatDate(settings.updatedAt, 'd MMMM yyyy, HH:mm') })
              : t('care.settings.notConfigured')}
          </p>
          <CareSettingsForm settings={settings} canEdit={canEdit} />
        </div>
      )}
    </>
  );
}

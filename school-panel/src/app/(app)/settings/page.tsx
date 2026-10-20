'use client';

import { Can } from '@/auth/can';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { useSchool } from '@/features/school/hooks';
import { AcademicCard } from '@/features/settings/components/academic-card';
import { BrandLinkCard } from '@/features/settings/components/brand-link-card';
import { DemoCard } from '@/features/settings/components/demo-card';
import { LogoCard } from '@/features/settings/components/logo-card';
import { PreferencesCard } from '@/features/settings/components/preferences-card';
import { ProfileCard } from '@/features/settings/components/profile-card';
import { useI18n } from '@/i18n';

export default function SettingsPage() {
  const { t } = useI18n();
  const school = useSchool();
  const data = school.data;

  return (
    <>
      <PageHeader title={t('settings.title')} subtitle={t('settings.subtitle')} />
      {school.isError ? (
        <Card>
          <ErrorState error={school.error} onRetry={() => void school.refetch()} />
        </Card>
      ) : !data ? (
        <div className="grid gap-6 xl:grid-cols-3">
          <Skeleton className="h-[420px] rounded-2xl xl:col-span-2" />
          <Skeleton className="h-[420px] rounded-2xl" />
        </div>
      ) : (
        <div className="grid items-start gap-6 xl:grid-cols-3 animate-fade-in">
          <div className="min-w-0 space-y-6 xl:col-span-2">
            <ProfileCard school={data.school} />
            <BrandLinkCard school={data.school} />
            <AcademicCard school={data.school} shifts={data.shifts} />
          </div>
          <div className="space-y-6">
            <LogoCard school={data.school} />
            <PreferencesCard />
            <Can perm="demo.reset">
              <DemoCard />
            </Can>
          </div>
        </div>
      )}
    </>
  );
}

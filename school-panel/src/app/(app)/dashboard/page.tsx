'use client';

import { useCan } from '@/auth/use-session';
import { ErrorState } from '@/components/common/error-state';
import { AlertsCard } from '@/features/dashboard/components/alerts-card';
import { CareCard } from '@/features/dashboard/components/care-card';
import { CareInboxCard } from '@/features/dashboard/components/care-inbox-card';
import { ClassesChart } from '@/features/dashboard/components/classes-chart';
import { DevicesCard } from '@/features/dashboard/components/devices-card';
import { DashboardHero } from '@/features/dashboard/components/hero';
import { KpiRow } from '@/features/dashboard/components/kpi-row';
import { LearningCard } from '@/features/dashboard/components/learning-card';
import { LiveFeed } from '@/features/dashboard/components/live-feed';
import { MyClassCard } from '@/features/dashboard/components/my-class-card';
import { TrendChart } from '@/features/dashboard/components/trend-chart';
import { UpcomingCard } from '@/features/dashboard/components/upcoming-card';
import { useOverview } from '@/features/dashboard/hooks';

export default function DashboardPage() {
  const can = useCan();
  const overview = useOverview();
  const data = overview.data;
  const loading = overview.isLoading;

  if (overview.isError) return <ErrorState error={overview.error} onRetry={() => void overview.refetch()} />;

  const singleClass = data?.classes?.length === 1 ? data.classes[0] : null;
  const bottom = [
    data?.schoolMode && <DevicesCard key="dev" schoolMode={data.schoolMode} />,
    data?.upcoming && <UpcomingCard key="up" items={data.upcoming} />,
    data?.care && !data.careInbox && <CareCard key="care" care={data.care} />,
    data?.learning && <LearningCard key="learn" learning={data.learning} />,
  ].filter(Boolean);

  return (
    <>
      <DashboardHero data={data} />
      <KpiRow data={data} loading={loading} />

      <div className="mb-6 grid gap-6 lg:grid-cols-3">
        <div className="min-w-0 space-y-6 lg:col-span-2">
          {data?.careInbox && <CareInboxCard inbox={data.careInbox} />}
          {can('attendance.history') && <TrendChart />}
          {singleClass ? (
            <MyClassCard classId={singleClass.classId} />
          ) : (
            (loading || data?.classes) && <ClassesChart rows={data?.classes} loading={loading} />
          )}
        </div>
        <div className="min-w-0 space-y-6">
          <AlertsCard alerts={data?.alerts} loading={loading} />
          {data?.careInbox && data.care && <CareCard care={data.care} />}
          {can('attendance.view') && <LiveFeed />}
        </div>
      </div>

      {bottom.length > 0 && <div className="grid gap-6 md:grid-cols-2 2xl:grid-cols-4">{bottom}</div>}
    </>
  );
}

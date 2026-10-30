'use client';

import { Activity, BookOpenCheck, Brain, CalendarCheck2, HeartHandshake, ShieldAlert, Smartphone, Users } from 'lucide-react';
import type { ReactNode } from 'react';

import { KpiCard, KpiCardSkeleton } from '@/components/charts/kpi-card';
import type { MetricKey, Overview } from '@/data/contracts';

export const KPI_ICONS: Partial<Record<MetricKey, ReactNode>> = {
  coverage: <Users />,
  active: <Activity />,
  mastery: <BookOpenCheck />,
  iqMean: <Brain />,
  wellbeing: <HeartHandshake />,
  attendance: <CalendarCheck2 />,
  screenTime: <Smartphone />,
  bullying: <ShieldAlert />,
};

export const KPI_HREF: Partial<Record<MetricKey, string>> = {
  mastery: '/mastery',
  iqMean: '/iq',
  wellbeing: '/wellbeing',
  bullying: '/wellbeing',
  attendance: '/attendance',
  screenTime: '/digital',
};

export function KpiGrid({ overview, loading }: { overview: Overview | undefined; loading: boolean }) {
  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-4 2xl:grid-cols-8">
      {loading || !overview
        ? Array.from({ length: 8 }, (_, i) => <KpiCardSkeleton key={i} />)
        : overview.kpis.map((k) => <KpiCard key={k.key} kpi={k} icon={KPI_ICONS[k.key]} href={KPI_HREF[k.key]} />)}
    </div>
  );
}

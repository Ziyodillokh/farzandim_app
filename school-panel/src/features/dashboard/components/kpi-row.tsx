'use client';

import {
  ArrowRight,
  CalendarClock,
  Clock,
  HeartHandshake,
  Inbox,
  MessageCircleWarning,
  ShieldCheck,
  TriangleAlert,
  UserCheck,
  Users,
} from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { StatCard } from '@/components/common/stat-card';
import { Progress } from '@/components/ui/progress';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';

type Overview = DashboardOverview;
type T = ReturnType<typeof useI18n>['t'];
type FormatNumber = ReturnType<typeof useI18n>['formatNumber'];

/** Kartalar soniga qarab setka: bo'sh katak qolmasligi uchun 5 ta — 2 keng + 3 tor. */
const GRID: Record<number, string> = {
  1: 'sm:grid-cols-2 xl:grid-cols-4',
  2: 'sm:grid-cols-2',
  3: 'sm:grid-cols-2 xl:grid-cols-3',
  4: 'sm:grid-cols-2 xl:grid-cols-4',
  5: 'sm:grid-cols-2 lg:grid-cols-6',
  6: 'sm:grid-cols-2 lg:grid-cols-3',
};

function spanClass(count: number, index: number): string {
  if (count !== 5) return '';
  if (index < 2) return 'lg:col-span-3';
  return index === 4 ? 'sm:col-span-2 lg:col-span-2' : 'lg:col-span-2';
}

function attendanceCards(att: Overview['attendance'], loading: boolean, t: T, formatNumber: FormatNumber): ReactNode[] {
  const rate = att?.rate ?? null;
  return [
    <StatCard
      key="att"
      icon={<UserCheck />}
      tone="success"
      loading={loading}
      label={t('dashboard.kpi.attendance')}
      value={rate === null ? '—' : `${formatNumber(rate, { maximumFractionDigits: 1 })}%`}
      hint={att && t('dashboard.kpi.attendanceHint', { arrived: att.arrived, decided: att.decided, pending: att.counts.pending })}
      footer={att && <Progress value={rate ?? 0} indicatorClassName="bg-success" aria-label={t('dashboard.kpi.attendance')} />}
    />,
    <StatCard
      key="late"
      icon={<Clock />}
      tone="warning"
      loading={loading}
      label={t('dashboard.kpi.late')}
      value={att?.counts.late ?? '—'}
      hint={att && t('dashboard.kpi.lateHint', { absent: att.counts.absent, excused: att.counts.excused })}
    />,
  ];
}

function SchoolModeCard({ sm }: { sm: NonNullable<Overview['schoolMode']> }) {
  const { t } = useI18n();
  const withPhone = sm.devices.APPLIED + sm.devices.NO_PERMISSION + sm.devices.OFFLINE;
  const state = sm.restrictedClasses > 0 ? t('dashboard.kpi.schoolModeHint', { count: sm.restrictedClasses }) : t('dashboard.kpi.schoolModeNone');
  return (
    <StatCard
      icon={sm.emergency ? <TriangleAlert /> : <ShieldCheck />}
      tone={sm.emergency ? 'destructive' : 'primary'}
      label={t('dashboard.kpi.schoolMode')}
      value={sm.emergency ? t('dashboard.kpi.emergencyOn') : t('dashboard.kpi.schoolModeValue', { count: sm.restrictedClasses })}
      hint={sm.emergency ? undefined : state}
      footer={
        <div className="space-y-1.5">
          <p className="text-xs text-muted-foreground">{t('dashboard.kpi.schoolModeDevices', { applied: sm.devices.APPLIED, withPhone })}</p>
          <Progress value={percent(sm.devices.APPLIED, withPhone)} indicatorClassName="bg-primary" aria-label={t('dashboard.kpi.schoolMode')} />
        </div>
      }
    />
  );
}

function OpenRequestsCard({ open }: { open: NonNullable<Overview['openRequests']> }) {
  const { t } = useI18n();
  const hint =
    open.verifications === null
      ? t('dashboard.kpi.openRequestsHint', { earlyExits: open.earlyExits })
      : t('dashboard.kpi.openRequestsHintFull', { earlyExits: open.earlyExits, verifications: open.verifications });
  return (
    <StatCard
      icon={<Inbox />}
      tone="info"
      label={t('dashboard.kpi.openRequests')}
      value={open.total}
      hint={hint}
      footer={
        open.total > 0 && (
          <Link href={open.href} className="group inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline">
            {t('dashboard.kpi.openRequestsReview')}
            <ArrowRight className="h-3 w-3 transition-transform group-hover:translate-x-0.5" />
          </Link>
        )
      }
    />
  );
}

function careInboxCards(inbox: NonNullable<Overview['careInbox']>, t: T): ReactNode[] {
  return [
    <StatCard key="cn" icon={<MessageCircleWarning />} tone="destructive" label={t('dashboard.kpi.careNew')} value={inbox.newCount} />,
    <StatCard key="cu" icon={<TriangleAlert />} tone="warning" label={t('dashboard.kpi.careUrgent')} value={inbox.urgentOpen} />,
    <StatCard key="cp" icon={<HeartHandshake />} tone="info" label={t('dashboard.kpi.careInProgress')} value={inbox.inProgress} />,
    <StatCard key="cm" icon={<CalendarClock />} tone="primary" label={t('dashboard.kpi.careMeetings')} value={inbox.meetingsToday} />,
  ];
}

export function KpiRow({ data, loading }: { data: Overview | undefined; loading: boolean }) {
  const { t, formatNumber } = useI18n();
  const cards: ReactNode[] = [];
  const att = data?.attendance;

  if (loading || att) cards.push(...attendanceCards(att ?? null, loading, t, formatNumber));
  if (data?.schoolMode) cards.push(<SchoolModeCard key="sm" sm={data.schoolMode} />);
  if (data?.parents) {
    const s = data.parents.students;
    cards.push(
      <StatCard
        key="parents"
        icon={<Users />}
        tone="info"
        label={t('dashboard.kpi.parents')}
        value={`${s.rate}%`}
        hint={t('dashboard.kpi.parentsHint', { linked: s.linked, total: s.total })}
        footer={<Progress value={s.rate} indicatorClassName="bg-info" aria-label={t('dashboard.kpi.parents')} />}
      />,
    );
  }
  if (data?.openRequests) cards.push(<OpenRequestsCard key="open" open={data.openRequests} />);
  if (data?.careInbox) cards.push(...careInboxCards(data.careInbox, t));
  if (cards.length === 0) return null;

  return (
    <div className={cn('mb-6 grid gap-4', GRID[cards.length] ?? GRID[4])}>
      {cards.map((card, i) => (
        <div key={i} className={cn('min-w-0 [&>*]:h-full', spanClass(cards.length, i))}>
          {card}
        </div>
      ))}
    </div>
  );
}

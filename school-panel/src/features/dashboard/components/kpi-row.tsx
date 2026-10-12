'use client';

import { CalendarClock, Clock, HeartHandshake, MessageCircleWarning, ShieldCheck, TriangleAlert, UserCheck, Users } from 'lucide-react';

import { StatCard } from '@/components/common/stat-card';
import { Progress } from '@/components/ui/progress';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';

export function KpiRow({ data, loading }: { data: DashboardOverview | undefined; loading: boolean }) {
  const { t, formatNumber } = useI18n();
  const cards: React.ReactNode[] = [];
  const att = data?.attendance;
  const inbox = data?.careInbox;

  if (loading || att) {
    cards.push(
      <StatCard
        key="att"
        icon={<UserCheck />}
        tone="success"
        loading={loading}
        label={t('dashboard.kpi.attendance')}
        value={att ? `${formatNumber(att.rate, { maximumFractionDigits: 1 })}%` : '—'}
        hint={att && t('dashboard.kpi.attendanceHint', { arrived: att.arrived, total: att.counts.total })}
        footer={att && <Progress value={att.counts.total ? (att.arrived / att.counts.total) * 100 : 0} indicatorClassName="bg-success" />}
      />,
      <StatCard
        key="late"
        icon={<Clock />}
        tone="warning"
        loading={loading}
        label={t('dashboard.kpi.late')}
        value={att?.counts.late ?? '—'}
        hint={att && t('dashboard.kpi.lateHint', { absent: att.counts.absent, excused: att.counts.excused })}
        footer={att && att.counts.pending > 0 && <p className="text-xs text-muted-foreground">{t('dashboard.kpi.pending', { count: att.counts.pending })}</p>}
      />,
    );
  }
  if (data?.schoolMode) {
    const sm = data.schoolMode;
    cards.push(
      <StatCard
        key="sm"
        icon={sm.emergency ? <TriangleAlert /> : <ShieldCheck />}
        tone={sm.emergency ? 'destructive' : 'primary'}
        label={t('dashboard.kpi.schoolMode')}
        value={sm.emergency ? t('dashboard.kpi.emergencyOn') : t('dashboard.kpi.schoolModeValue', { count: sm.restrictedClasses })}
        hint={t('dashboard.kpi.schoolModeHint', { devices: sm.devices.APPLIED })}
      />,
    );
  }
  if (data?.parents) {
    const p = data.parents;
    cards.push(
      <StatCard
        key="parents"
        icon={<Users />}
        tone="info"
        label={t('dashboard.kpi.parents')}
        value={`${p.rate}%`}
        hint={t('dashboard.kpi.parentsHint', { linked: p.linkedStudents, total: p.totalStudents })}
        footer={<Progress value={p.rate} indicatorClassName="bg-info" />}
      />,
    );
  }
  if (inbox) {
    cards.push(
      <StatCard key="cn" icon={<MessageCircleWarning />} tone="destructive" label={t('dashboard.kpi.careNew')} value={inbox.newCount} />,
      <StatCard key="cu" icon={<TriangleAlert />} tone="warning" label={t('dashboard.kpi.careUrgent')} value={inbox.urgentOpen} />,
      <StatCard key="cp" icon={<HeartHandshake />} tone="info" label={t('dashboard.kpi.careInProgress')} value={inbox.inProgress} />,
      <StatCard key="cm" icon={<CalendarClock />} tone="primary" label={t('dashboard.kpi.careMeetings')} value={inbox.meetingsToday} />,
    );
  }
  if (cards.length === 0) return null;
  return <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{cards}</div>;
}
